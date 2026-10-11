import Foundation
import AquariumCore
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// A dev tool: renders the tank to PNG(s) so the pixel art can be reviewed
// without a GUI or the Touch Bar. Run from the package root.

struct Options {
    var out = "out/aquarium.png"
    var strip = 1          // how many frames to capture
    var step = 0.5         // seconds between captured frames
    var warmup = 2.0       // seconds to settle before capturing
    var scale = 3          // integer nearest-neighbour upscale for the PNG
    var feeds: [Double] = []
    var legendary = false  // force a legendary resident for previewing
    var seed: UInt64?     // pin the world for reproducible renders
    var theme = "freshwater"
    var hour: Double?     // pin the time of day (0..24)
    var sprites = false   // render a lineup of key sprites instead of the tank
    var viewport: Int?    // render only a window this wide (art px), scrolled
    var camera: Int = 0   // art-px offset of that window
}

func parseArgs() -> Options {
    var o = Options()
    let args = CommandLine.arguments
    var i = 1
    while i < args.count {
        switch args[i] {
        case "--out": i += 1; if i < args.count { o.out = args[i] }
        case "--strip": i += 1; if i < args.count { o.strip = Int(args[i]) ?? o.strip }
        case "--step": i += 1; if i < args.count { o.step = Double(args[i]) ?? o.step }
        case "--warmup": i += 1; if i < args.count { o.warmup = Double(args[i]) ?? o.warmup }
        case "--scale": i += 1; if i < args.count { o.scale = Int(args[i]) ?? o.scale }
        case "--feed": i += 1; if i < args.count, let x = Double(args[i]) { o.feeds.append(x) }
        case "--legendary": o.legendary = true
        case "--seed": i += 1; if i < args.count { o.seed = UInt64(args[i]) }
        case "--theme": i += 1; if i < args.count { o.theme = args[i] }
        case "--hour": i += 1; if i < args.count { o.hour = Double(args[i]) }
        case "--sprites": o.sprites = true
        case "--viewport": i += 1; if i < args.count, let v = Int(args[i]) { o.viewport = v }
        case "--camera": i += 1; if i < args.count { o.camera = Int(args[i]) ?? o.camera }
        default: break
        }
        i += 1
    }
    return o
}

let opts = parseArgs()

if opts.sprites {
    let row: [PixelSprite] = [
        Art.legendarySprite(0), Art.legendarySprite(1), Art.legendarySprite(2),
        Art.fishSprite(9), Art.fishSprite(8), Art.fishSprite(10), Art.fishSprite(0),
        Art.fishSprite(11), Art.fishSprite(12),
        Art.critterSprite(0), Art.critterSprite(1), Art.critterSprite(2),
        Art.decorSprite(kind: 0, variant: 0), Art.decorSprite(kind: 2, variant: 0),
        Art.decorSprite(kind: 3, variant: 1), Art.decorSprite(kind: 4, variant: 2),
        Art.decorSprite(kind: 5, variant: 0), Art.decorSprite(kind: 6, variant: 0),
    ]
    let gap = 2
    let totalW = row.reduce(0) { $0 + $1.width + gap } + gap
    let totalH = (row.map(\.height).max() ?? 1) + 4
    var f = Frame(width: totalW, height: totalH)
    f.fill(RGBA(hex: 0x0B2A5E))
    var x = gap
    for s in row {
        s.draw(into: &f, x: x, y: max(0, totalH - 2 - s.height))
        x += s.width + gap
    }
    if let url = writePNG(f, scale: max(1, opts.scale), to: opts.out) {
        print("Wrote \(url.path) (sprite lineup)")
        exit(0)
    }
}

var config = TankConfig()
if let s = opts.seed { config.seed = s }
if opts.legendary { config.legendaryChance = 1.0 }
if let h = opts.hour { config.startHour = h }
switch opts.theme.lowercased() {
case "deep", "deepsea", "deep-sea": config.palette = .deepSea
case "reef": config.palette = .reef
default: config.palette = .freshwater
}
var sim = AquariumSim(config: config)
if !sim.legendaryNames.isEmpty { print("legendary residents: \(sim.legendaryNames.joined(separator: ", "))") }

// Settle the tank.
var t = 0.0
let dt = 1.0 / 60.0
while t < opts.warmup {
    for x in opts.feeds where abs(t) < 0.001 { sim.feed(x: x) }
    sim.tick(dt: dt)
    t += dt
}

// Capture frames.
var frames: [Frame] = []
for _ in 0..<max(1, opts.strip) {
    var f: Frame
    if let vw = opts.viewport {
        f = Frame(width: vw, height: sim.config.height)
        Aquarium.render(sim, into: &f, cameraX: opts.camera)
    } else {
        f = Frame(width: sim.config.width, height: sim.config.height)
        Aquarium.render(sim, into: &f)
    }
    frames.append(f)

    var s = 0.0
    while s < opts.step {
        sim.tick(dt: dt)
        s += dt
    }
}

let combined = combineVertically(frames, gap: 2)
guard let url = writePNG(combined, scale: max(1, opts.scale), to: opts.out) else {
    FileHandle.standardError.write(Data("failed to write PNG\n".utf8))
    exit(1)
}
print("Wrote \(url.path)  (\(frames.count) frame(s), art \(sim.config.width)x\(sim.config.height))")

// MARK: - Helpers

func combineVertically(_ frames: [Frame], gap: Int) -> Frame {
    let w = frames.map(\.width).max() ?? 1
    let totalH = frames.reduce(0) { $0 + $1.height } + gap * max(0, frames.count - 1)
    var out = Frame(width: w, height: totalH)
    out.fill(RGBA(hex: 0x111111))
    var y = 0
    for f in frames {
        for fy in 0..<f.height {
            for fx in 0..<f.width {
                out.set(fx, y + fy, f.get(fx, fy))
            }
        }
        y += f.height + gap
    }
    return out
}

func cgImage(from frame: Frame) -> CGImage? {
    var bytes = frame.pixels
    for i in stride(from: 3, to: bytes.count, by: 4) { bytes[i] = 255 } // force opaque
    let cs = CGColorSpaceCreateDeviceRGB()
    let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
    guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
    return CGImage(
        width: frame.width, height: frame.height,
        bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: frame.width * 4,
        space: cs, bitmapInfo: info, provider: provider,
        decode: nil, shouldInterpolate: false, intent: .defaultIntent
    )
}

func writePNG(_ frame: Frame, scale: Int, to path: String) -> URL? {
    guard let img = cgImage(from: frame) else { return nil }
    let W = frame.width * scale
    let H = frame.height * scale
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil, width: W, height: H,
        bitsPerComponent: 8, bytesPerRow: 0, space: cs,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { return nil }
    ctx.interpolationQuality = .none
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: W, height: H))
    guard let out = ctx.makeImage() else { return nil }

    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        return nil
    }
    CGImageDestinationAddImage(dest, out, nil)
    guard CGImageDestinationFinalize(dest) else { return nil }
    return url
}
