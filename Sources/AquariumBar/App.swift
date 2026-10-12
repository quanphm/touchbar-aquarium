import AppKit
import CoreGraphics
import IOKit.pwr_mgt
import AquariumCore

/// Optional preview window. Also provides a frontmost-only Touch Bar as a
/// fallback when the private system-modal API isn't available.
final class PreviewWindowController: NSWindowController {
    let controller: AquariumController
    private let host: TouchBarHost

    init(controller: AquariumController) {
        self.controller = controller
        self.host = TouchBarHost(controller: controller)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 30),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Touch Bar Aquarium — preview"
        window.isReleasedWhenClosed = false
        super.init(window: window)

        let tank = TankView(controller: controller, tag: "preview")
        tank.frame = window.contentView!.bounds
        tank.autoresizingMask = [.width, .height]
        window.contentView = tank
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func makeTouchBar() -> NSTouchBar? { host.makeBar() }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// macOS minimizes a system-modal Touch Bar after a spell with no HID
    /// input. Re-claiming it while the user is actively working would fight
    /// the system and flicker the bar, so the watchdog only fires once things
    /// have gone quiet for `idleThreshold` seconds.
    private static let watchdogInterval: Double = 4
    private static let idleThreshold: Double = 15
    /// Re-assert at most this often while idle, so a bar that the system
    /// minimizes repeatedly doesn't stay dark between attempts.
    private static let reassertInterval: Double = 10

    private let controller = AquariumController()
    private lazy var presenter = SystemModalPresenter(controller: controller)
    private var preview: PreviewWindowController?
    private var statusItem: NSStatusItem?
    private var alwaysOn = false
    private var followClock = false
    private var watchdog: Timer?
    private var lastReassert = 0.0
    private var activity: NSObjectProtocol?
    private var reassertCount = 0
    private var barIsPresented = false
    private var displayAssertion: IOPMAssertionID = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        // This is a 30fps animation that has to keep running with no user
        // input at all. Without an activity assertion the process gets App
        // Napped when idle and the tank freezes on screen.
        //
        // `.userInitiatedAllowingIdleSystemSleep` keeps the timers out of App
        // Nap but still lets the Mac sleep when you walk away. The
        // `.idleSystemSleepDisabled` option would also do the job, but it
        // would keep the whole machine awake for as long as the app runs.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Keeping the aquarium running on the Touch Bar"
        )

        controller.start()
        setupStatusItem()
        LayoutLog.note("legendary", controller.sim.legendaryNames.joined(separator: ", "))

        alwaysOn = presenter.enable()
        LayoutLog.note("boot",
                       "alwaysOn=\(alwaysOn) verbose=\(ProcessInfo.processInfo.environment["AQUARIUM_WATCHDOG_LOG"] ?? "0")")
        if !alwaysOn {
            // Private API unavailable: at least show it while we're frontmost.
            showPreview()
        }
        rebuildMenu()
        setDisplayAwake(alwaysOn)
        startWatchdog()

        // Re-assert the bar whenever another app comes forward (some apps
        // replace the bar; this keeps the tank on top).
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        watchdog?.invalidate()
        watchdog = nil
        setDisplayAwake(false)
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        presenter.disable()
    }

    @objc private func activeAppChanged() {
        lastReassert = 0
        if alwaysOn { presenter.present() }
    }

    // MARK: - Idle watchdog

    /// Hold the display awake while the tank owns the Touch Bar.
    ///
    /// macOS puts the Touch Bar to sleep when the machine goes idle, and it
    /// takes the Control Strip with it — the whole bar goes dark, not just
    /// our panel. That is the system sleeping the bar, not it dropping our
    /// modal, so re-presenting cannot bring it back; the screen has to be
    /// kept awake in the first place.
    ///
    /// `PreventUserIdleDisplaySleep` is the narrow assertion: it stops
    /// inactivity from dimming the display and Touch Bar, but it does not
    /// block *system* sleep, so closing the lid still sleeps the Mac.
    private func setDisplayAwake(_ on: Bool) {
        if on {
            guard displayAssertion == 0 else { return }
            var id = IOPMAssertionID(0)
            let reason = "Keeping the aquarium Touch Bar awake" as CFString
            let created = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &id
            )
            displayAssertion = created == kIOReturnSuccess ? id : 0
            LayoutLog.note("touchbar", "display-sleep assertion \(created == kIOReturnSuccess ? "held" : "DENIED")")
        } else if displayAssertion != 0 {
            IOPMAssertionRelease(displayAssertion)
            displayAssertion = 0
            LayoutLog.note("touchbar", "display-sleep assertion released")
        }
    }

    private func startWatchdog() {
        let t = Timer(timeInterval: AppDelegate.watchdogInterval, repeats: true) {
            [weak self] _ in self?.reassertIfIdle()
        }
        RunLoop.main.add(t, forMode: .common)
        watchdog = t
    }

    /// `kCGAnyInputEventType` — "an input event of any kind".
    private static let anyInputEvent = CGEventType(rawValue: .max)!

    /// Seconds since the last HID input anywhere on the system.
    private static var secondsSinceInput: Double {
        CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyInputEvent)
    }

    /// The Touch Bar goes dark when you stop using the Mac, and nothing in the
    /// app noticed: we only ever re-asserted on an app becoming active, and
    /// sitting still doesn't activate anything. Claim the bar back once the
    /// system has been idle long enough to have dropped it.
    private func reassertIfIdle() {
        guard alwaysOn else { return }
        let idle = AppDelegate.secondsSinceInput
        let now = Date().timeIntervalSinceReferenceDate
        guard idle > AppDelegate.idleThreshold else { return }
        let due = now - lastReassert > AppDelegate.reassertInterval
        // Heartbeat: proves the timer is still firing and that the system
        // really does consider the user idle, independently of whether the
        // re-present below actually brings the bar back.
        let verbose = ProcessInfo.processInfo.environment["AQUARIUM_WATCHDOG_LOG"] == "1"
        if verbose {
            LayoutLog.note("touchdog",
                           "tick idle=\(Int(idle))s due=\(due) presented=\(barIsPresented) "
                           + "reasserts=\(reassertCount)")
        }
        guard due else { return }
        lastReassert = now
        reassertCount += 1
        let ok = presenter.reassert()
        barIsPresented = ok
        if ok || verbose {
            LayoutLog.note("touchbar", "re-present\(ok ? "ed" : " FAILED") after \(Int(idle))s idle")
        }
    }

    // MARK: - Status item / menu

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "fish", accessibilityDescription: "Aquarium")
        statusItem = item
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let always = NSMenuItem(title: "Always show on Touch Bar", action: #selector(toggleAlwaysOn), keyEquivalent: "")
        always.state = alwaysOn ? .on : .off
        always.target = self
        menu.addItem(always)

        let previewItem = NSMenuItem(title: "Show Preview Window", action: #selector(showPreview), keyEquivalent: "p")
        previewItem.target = self
        menu.addItem(previewItem)

        menu.addItem(.separator())

        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        let themeMenu = NSMenu()
        let freshwater = NSMenuItem(title: "Freshwater", action: #selector(useFreshwater), keyEquivalent: "")
        freshwater.target = self
        let deepSea = NSMenuItem(title: "Deep Sea", action: #selector(useDeepSea), keyEquivalent: "")
        deepSea.target = self
        themeMenu.addItem(freshwater)
        themeMenu.addItem(deepSea)
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        // The Touch Bar's rounded ends differ per model and can't be measured
        // from code, so the safe inset is adjustable and takes effect live.
        let insetItem = NSMenuItem(title: "Edge Inset", action: nil, keyEquivalent: "")
        let insetMenu = NSMenu()
        for value in [0.0, 12.0, 20.0, 28.0, 36.0, 44.0, 56.0] {
            let entry = NSMenuItem(title: value == 0 ? "Off" : "\(Int(value)) pt",
                                   action: #selector(setCornerInset(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = value
            entry.state = abs(controller.cornerInset - value) < 0.5 ? .on : .off
            insetMenu.addItem(entry)
        }
        insetItem.submenu = insetMenu
        menu.addItem(insetItem)

        let newTank = NSMenuItem(title: "New Tank", action: #selector(makeNewTank), keyEquivalent: "n")
        newTank.target = self
        menu.addItem(newTank)

        let clock = NSMenuItem(title: "Follow the system clock", action: #selector(toggleClock), keyEquivalent: "")
        clock.state = followClock ? .on : .off
        clock.target = self
        menu.addItem(clock)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Touch Bar Aquarium", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem?.menu = menu
    }

    @objc private func toggleAlwaysOn() {
        if alwaysOn {
            presenter.disable()
            alwaysOn = false
        } else {
            alwaysOn = presenter.enable()
        }
        setDisplayAwake(alwaysOn)
        rebuildMenu()
    }

    @objc private func showPreview() {
        if preview == nil { preview = PreviewWindowController(controller: controller) }
        preview?.showWindow(nil)
        preview?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func useFreshwater() { applyTheme(.freshwater, named: "freshwater") }
    @objc private func useDeepSea() { applyTheme(.deepSea, named: "deepSea") }

    @objc private func setCornerInset(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        controller.cornerInset = value
        controller.refreshViews()
        LayoutLog.note("touchbar", "edge inset set to \(Int(value))pt")
        rebuildMenu()
    }

    private func applyTheme(_ palette: Palette, named name: String) {
        controller.setTheme(palette, name: name)
        rebuildMenu()
    }

    @objc private func makeNewTank() {
        controller.newTank()
        rebuildMenu()
    }

    @objc private func toggleClock() {
        followClock.toggle()
        controller.setFollowClock(followClock)
        rebuildMenu()
    }
}
