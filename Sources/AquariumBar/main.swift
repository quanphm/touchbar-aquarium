import AppKit

// Background (menu-bar) app: no Dock icon, no window at launch. The tank is
// presented straight onto the Touch Bar via the system-modal presenter.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
