import Foundation

/// A tiny pixel-art bitmap. `nil` pixels are transparent.
public struct PixelSprite: Equatable {
    public let width: Int
    public let height: Int
    public let pixels: [RGBA?]

    public init(width: Int, height: Int, pixels: [RGBA?]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    /// Build from ASCII art. `.` and space are transparent; every other character
    /// must be present in `palette`. Write art flush-left in the source so no
    /// leading indentation is baked into the sprite.
    public init(art: String, _ palette: [Character: RGBA]) {
        var rows = art
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { Array($0) }
        while let first = rows.first, first.allSatisfy({ $0 == " " }) { rows.removeFirst() }
        while let last = rows.last, last.allSatisfy({ $0 == " " }) { rows.removeLast() }

        let w = rows.map(\.count).max() ?? 0
        let h = rows.count
        var px = [RGBA?](repeating: nil, count: w * h)
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() {
                if ch == "." || ch == " " { continue }
                px[y * w + x] = palette[ch]
            }
        }
        self.init(width: w, height: h, pixels: px)
    }

    public var mirrored: PixelSprite {
        var px = [RGBA?](repeating: nil, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                px[y * width + x] = pixels[y * width + (width - 1 - x)]
            }
        }
        return PixelSprite(width: width, height: height, pixels: px)
    }

    /// Draw only the opaque pixels as a single flat color (used for glow auras).
    public func drawSilhouette(into frame: inout Frame, x ox: Int, y oy: Int, color: RGBA, flipX: Bool = false) {
        for y in 0..<height {
            for x in 0..<width {
                guard pixels[y * width + x] != nil else { continue }
                let sx = flipX ? (width - 1 - x) : x
                frame.blend(ox + sx, oy + y, color)
            }
        }
    }

    /// Draw with the top-left corner at (x, y). `flipX` mirrors horizontally.
    public func draw(into frame: inout Frame, x ox: Int, y oy: Int, flipX: Bool = false, alpha: Double = 1) {
        guard alpha > 0 else { return }
        let aMul = max(0, min(1, alpha))
        for y in 0..<height {
            for x in 0..<width {
                guard var c = pixels[y * width + x] else { continue }
                if aMul < 1 { c.a = UInt8((Double(c.a) * aMul).rounded()) }
                let sx = flipX ? (width - 1 - x) : x
                frame.blend(ox + sx, oy + y, c)
            }
        }
    }
}
