import AppKit
import AquariumCore

/// Supplies the Touch Bar. This is the seam: today it wraps the public
/// `NSTouchBar` API (visible while the app is frontmost). A second adapter for
/// the private DFR API will slot in here for always-on display.
final class TouchBarHost: NSObject, NSTouchBarDelegate {
    static let itemID = NSTouchBarItem.Identifier("com.touchbaraquarium.tank")
    static let barID = NSTouchBar.CustomizationIdentifier("com.touchbaraquarium.bar")

    private let controller: AquariumController

    init(controller: AquariumController) {
        self.controller = controller
    }

    func makeBar() -> NSTouchBar {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.customizationIdentifier = TouchBarHost.barID
        bar.defaultItemIdentifiers = [TouchBarHost.itemID]
        bar.customizationAllowedItemIdentifiers = [TouchBarHost.itemID]
        bar.principalItemIdentifier = TouchBarHost.itemID
        return bar
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard identifier == TouchBarHost.itemID else { return nil }
        let item = NSCustomTouchBarItem(identifier: identifier)
        item.customizationLabel = "Aquarium"
        let view = TankView(controller: controller, tag: "touchbar")
        view.frame = NSRect(x: 0, y: 0, width: 900, height: 30)
        item.view = view
        return item
    }
}
