import Foundation

/// A straight (non-premultiplied) RGBA8 color.
public struct RGBA: Equatable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8
    public var a: UInt8

    public init(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8 = 255) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    public init(hex: UInt32, alpha: UInt8 = 255) {
        self.r = UInt8((hex >> 16) & 0xFF)
        self.g = UInt8((hex >> 8) & 0xFF)
        self.b = UInt8(hex & 0xFF)
        self.a = alpha
    }

    public static let clear = RGBA(0, 0, 0, 0)

    /// Linear interpolation toward `other`. Used for gradients and day/night tinting.
    public func mixed(with other: RGBA, _ t: Double) -> RGBA {
        let t = max(0, min(1, t))
        func lerp(_ a: UInt8, _ b: UInt8) -> UInt8 {
            UInt8(max(0, min(255, (Double(a) * (1 - t) + Double(b) * t).rounded())))
        }
        return RGBA(lerp(r, other.r), lerp(g, other.g), lerp(b, other.b), lerp(a, other.a))
    }

    public func withAlpha(_ a: UInt8) -> RGBA { RGBA(r, g, b, a) }
}

/// A mutable RGBA8 image. Row-major, top-left origin.
public struct Frame {
    public let width: Int
    public let height: Int
    public private(set) var pixels: [UInt8]

    public init(width: Int, height: Int) {
        self.width = max(1, width)
        self.height = max(1, height)
        self.pixels = [UInt8](repeating: 0, count: self.width * self.height * 4)
    }

    @inline(__always)
    private func inBounds(_ x: Int, _ y: Int) -> Bool {
        x >= 0 && y >= 0 && x < width && y < height
    }

    /// Replace a pixel (no blending).
    public mutating func set(_ x: Int, _ y: Int, _ c: RGBA) {
        guard inBounds(x, y) else { return }
        let i = (y * width + x) * 4
        pixels[i] = c.r
        pixels[i + 1] = c.g
        pixels[i + 2] = c.b
        pixels[i + 3] = c.a
    }

    public func get(_ x: Int, _ y: Int) -> RGBA {
        guard inBounds(x, y) else { return .clear }
        let i = (y * width + x) * 4
        return RGBA(pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3])
    }

    /// Source-over blend a possibly translucent pixel.
    public mutating func blend(_ x: Int, _ y: Int, _ c: RGBA) {
        guard inBounds(x, y), c.a > 0 else { return }
        if c.a == 255 { set(x, y, c); return }
        let bg = get(x, y)
        let sa = Double(c.a) / 255
        let da = Double(bg.a) / 255
        let outA = sa + da * (1 - sa)
        guard outA > 0 else { set(x, y, .clear); return }
        func ch(_ s: UInt8, _ d: UInt8) -> UInt8 {
            let v = (Double(s) * sa + Double(d) * da * (1 - sa)) / outA
            return UInt8(max(0, min(255, v.rounded())))
        }
        set(x, y, RGBA(ch(c.r, bg.r), ch(c.g, bg.g), ch(c.b, bg.b), UInt8((outA * 255).rounded())))
    }

    public mutating func fill(_ c: RGBA) {
        for y in 0..<height {
            for x in 0..<width { set(x, y, c) }
        }
    }

    public mutating func fillRect(x: Int, y: Int, w: Int, h: Int, _ c: RGBA) {
        guard w > 0, h > 0 else { return }
        for yy in y..<(y + h) {
            for xx in x..<(x + w) { blend(xx, yy, c) }
        }
    }
}
