import AppKit
import CoreGraphics
import AquariumCore

/// Draws the tank. Reused verbatim in the preview window and in the Touch Bar
/// item, so the two always look identical. Everything here is presentation:
/// it just turns `AquariumController.sim` state into pixels.
final class TankView: NSView {
    private let controller: AquariumController
    private let logTag: String
    /// Reused render target so we don't allocate a buffer every frame.
    private var artFrame: Frame

    init(controller: AquariumController, tag: String = "") {
        self.controller = controller
        self.logTag = tag
        // Sized to the visible window in `draw`; 1px placeholder until then.
        self.artFrame = Frame(width: 1, height: controller.sim.config.height)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        controller.addObserver(self)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isOpaque: Bool { true }

    /// Whether this view is actually being shown (so we can skip redraws).
    var isOnScreen: Bool {
        window != nil && !isHiddenOrHasHiddenAncestor
    }

    /// Ask the Touch Bar for as much width as it will give a principal item.
    /// Height is pinned to the bar's real 30pt so the art scales a clean 3×.
    override var intrinsicContentSize: NSSize {
        NSSize(width: 1085, height: 30)
    }

    override func layout() {
        super.layout()
        LayoutLog.record(logTag, bounds.size)
        // Let the controller clamp panning against the width we actually show.
        if bounds.width > 0 { controller.viewportArtWidth = Double(viewportWidth) }
    }

    // MARK: - Layout maths

    /// Integer scale so pixels stay crisp. Fills the height, centres horizontally.
    private var scale: CGFloat {
        max(1, (bounds.height / CGFloat(controller.sim.config.height)).rounded(.down))
    }

    /// How much tank is drawn across the bar.
    ///
    /// Deliberately narrower than the full width: the bar's ends are rounded
    /// and the panel doesn't reach the bezel there, so anything drawn in that
    /// stretch is swallowed. Stopping short of it means no fish is ever drawn
    /// where the corner eats the panel — a jellyfish near the end of the tank
    /// used to come out half-drawn. The corners are left bare.
    private var viewportWidth: Int {
        let inset = 2 * controller.cornerInset
        return max(1, Int(((bounds.width - inset) / scale).rounded(.down)))
    }

    private var imageRect: NSRect {
        let s = scale
        let w = CGFloat(viewportWidth) * s
        let h = CGFloat(controller.sim.config.height) * s
        return NSRect(x: (bounds.width - w) / 2, y: (bounds.height - h) / 2, width: w, height: h)
    }

    private func artX(for pointX: CGFloat) -> Double {
        let rect = imageRect
        guard rect.width > 0 else { return 0 }
        return Double(controller.cameraOffset)
            + Double((pointX - rect.minX) / scale)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setShouldAntialias(false)
        ctx.interpolationQuality = .none
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fill(bounds)

        let vw = viewportWidth
        if artFrame.width != vw || artFrame.height != controller.sim.config.height {
            artFrame = Frame(width: vw, height: controller.sim.config.height)
        }
        Aquarium.render(controller.sim, into: &artFrame, cameraX: controller.cameraOffset)
        guard let img = TankView.makeCGImage(artFrame) else { return }
        ctx.draw(img, in: imageRect)
    }

    static func makeCGImage(_ frame: Frame) -> CGImage? {
        // The renderer fills an opaque background, so alpha is already 255.
        let cs = CGColorSpaceCreateDeviceRGB()
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let provider = CGDataProvider(data: Data(frame.pixels) as CFData) else { return nil }
        return CGImage(
            width: frame.width, height: frame.height,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: frame.width * 4,
            space: cs, bitmapInfo: info, provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }

    // MARK: - Interaction
    // Preview window: click drops food, drag pans, right-click taps the glass.
    // Touch Bar: tap drops food, drag pans.

    private var dragStartX: CGFloat?
    private var lastX: CGFloat?
    private var didPan = false

    override func mouseDown(with event: NSEvent) {
        let x = convert(event.locationInWindow, from: nil).x
        dragStartX = x; lastX = x; didPan = false
    }

    override func mouseDragged(with event: NSEvent) {
        let x = convert(event.locationInWindow, from: nil).x
        pan(from: lastX, to: x); lastX = x
    }

    override func mouseUp(with event: NSEvent) {
        defer { dragStartX = nil; lastX = nil; didPan = false }
        guard !didPan else { return }
        controller.feed(atArtX: artX(for: convert(event.locationInWindow, from: nil).x))
    }

    override func rightMouseDown(with event: NSEvent) {
        let x = convert(event.locationInWindow, from: nil).x
        controller.poke(atArtX: artX(for: x))
    }

    // Preview window: scroll horizontally to pan the (wider) tank.
    override func scrollWheel(with event: NSEvent) {
        controller.scrollCamera(by: Double(event.scrollingDeltaX) * 2)
    }

    // Touch Bar: direct touches arrive here. Tap feeds, drag pans.
    override func touchesBegan(with event: NSEvent) {
        guard let touch = event.touches(matching: .began, in: self).first else { return }
        let x = touch.location(in: self).x
        dragStartX = x; lastX = x; didPan = false
    }

    override func touchesMoved(with event: NSEvent) {
        guard let touch = event.touches(matching: .moved, in: self).first else { return }
        let x = touch.location(in: self).x
        pan(from: lastX, to: x); lastX = x
    }

    override func touchesEnded(with event: NSEvent) {
        defer { dragStartX = nil; lastX = nil; didPan = false }
        guard !didPan, let start = dragStartX else { return }
        controller.feed(atArtX: artX(for: start))
    }

    override func touchesCancelled(with event: NSEvent) {
        dragStartX = nil; lastX = nil; didPan = false
    }

    /// Pan the camera by a horizontal drag, so the content follows the finger.
    private func pan(from previousX: CGFloat?, to x: CGFloat) {
        guard let prev = previousX else { return }
        if let start = dragStartX, abs(x - start) > 3 { didPan = true }
        guard didPan else { return }
        controller.scrollCamera(by: -Double((x - prev) / scale))
    }
}

/// Records the sizes each tank view is laid out at, so the real Touch Bar
/// principal-area width can be read back without a screenshot.
enum LayoutLog {
    private static var last: [String: String] = [:]

    static func record(_ tag: String, _ size: NSSize) {
        guard !tag.isEmpty else { return }
        let s = "\(Int(size.width.rounded()))x\(Int(size.height.rounded()))"
        guard last[tag] != s else { return }
        last[tag] = s
        append("[\(tag)] \(s)")
    }

    static func note(_ tag: String, _ text: String) {
        append("[\(tag)] \(text)")
    }

    private static func append(_ line: String) {
        let url = URL(fileURLWithPath: "/tmp/touchbar-aquarium-layout.log")
        let data = Data((line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }
}
