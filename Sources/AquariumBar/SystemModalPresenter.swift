import AppKit
import TouchBarPrivate

/// Presents the tank as a *system-modal* Touch Bar, so it stays visible while
/// you work in other apps. This is the second adapter behind the Touch Bar
/// seam; it uses Apple-private APIs and degrades gracefully to the public
/// frontmost behavior if they are unavailable.
final class SystemModalPresenter {
    /// Identifier for our Control Strip tray icon.
    static let trayID = NSTouchBarItem.Identifier("com.touchbaraquarium.tray")

    private let host: TouchBarHost
    private var bar: NSTouchBar?
    private var trayInstalled = false

    init(controller: AquariumController) {
        self.host = TouchBarHost(controller: controller)
    }

    /// Installs the tray icon and presents the bar. Returns false if the
    /// private API isn't available (caller should fall back to frontmost mode).
    @discardableResult
    func enable() -> Bool {
        TBSetShowsCloseBoxWhenFrontMost(false)
        installTrayItem()
        return present()
    }

    /// (Re-)presents the bar. Re-asserted when the frontmost app changes.
    @discardableResult
    func present() -> Bool {
        let bar = self.bar ?? host.makeBar()
        self.bar = bar
        return TBPresentSystemModal(bar, 1, Self.trayID)
    }

    func disable() {
        if let bar { TBDismissSystemModal(bar) }
        bar = nil
    }

    private func installTrayItem() {
        guard !trayInstalled else { return }
        trayInstalled = true
        let item = NSCustomTouchBarItem(identifier: Self.trayID)
        let button = NSButton(title: "", target: self, action: #selector(reshow))
        button.image = NSImage(systemSymbolName: "fish", accessibilityDescription: "Aquarium")
        button.bezelStyle = .texturedRounded
        item.view = button
        item.customizationLabel = "Aquarium"
        TBAddSystemTrayItem(item)
        TBSetControlStripPresence(Self.trayID, true)
    }

    @objc private func reshow() { _ = present() }
}
