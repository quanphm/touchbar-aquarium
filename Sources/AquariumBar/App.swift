import AppKit
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
    private let controller = AquariumController()
    private lazy var presenter = SystemModalPresenter(controller: controller)
    private var preview: PreviewWindowController?
    private var statusItem: NSStatusItem?
    private var alwaysOn = false
    private var followClock = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()
        setupStatusItem()
        LayoutLog.note("legendary", controller.sim.legendaryNames.joined(separator: ", "))

        alwaysOn = presenter.enable()
        if !alwaysOn {
            // Private API unavailable: at least show it while we're frontmost.
            showPreview()
        }
        rebuildMenu()

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
        presenter.disable()
    }

    @objc private func activeAppChanged() {
        if alwaysOn { presenter.present() }
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
