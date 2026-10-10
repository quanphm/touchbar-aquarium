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
        self.artFrame = Frame(width: controller.sim.config.width, height: controller.sim.config.height)
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
    }

    // MARK: - Layout maths

    /// Integer scale so pixels stay crisp. Fills the height, centres horizontally.
    private var scale: CGFloat {
        max(1, (bounds.height / CGFloat(controller.sim.config.height)).rounded(.down))
    }

    private var imageRect: NSRect {
        let s = scale
        let w = CGFloat(controller.sim.config.width) * s
        let h = CGFloat(controller.sim.config.height) * s
        return NSRect(x: (bounds.width - w) / 2, y: (bounds.height - h) / 2, width: w, height: h)
    }

    private func artX(for pointX: CGFloat) -> Double {
        let rect = imageRect
        guard rect.width > 0 else { return 0 }
        return Double((pointX - rect.minX) / scale)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setShouldAntialias(false)
        ctx.interpolationQuality = .none
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fill(bounds)

        Aquarium.render(controller.sim, into: &artFrame)
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
    // Preview window: a click drops food; right-click taps the glass.

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        controller.feed(atArtX: artX(for: p.x))
    }

    override func rightMouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        controller.poke(atArtX: artX(for: p.x))
    }

    // Touch Bar: direct touches arrive here.
    override func touchesBegan(with event: NSEvent) {
        let touches = event.touches(matching: .began, in: self)
        guard let touch = touches.first else { return }
        let p = touch.location(in: self)
        controller.feed(atArtX: artX(for: p.x))
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
