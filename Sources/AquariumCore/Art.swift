import Foundation

/// Body silhouettes. Different shapes give the tank real variety instead of one
/// fish recolored many times.
public enum FishShape {
    case standard   // slim schooler (tetras, danios, barbs)
    case guppy      // big flowing tail
    case angel      // tall and slow
    case loach      // long, thin, hugs the floor
    case puffer     // round and stubby
    case clown      // striped anemonefish
    case betta      // showy, long flowing fins
    case goldfish   // round-bodied and golden
    case jelly      // pulsing jellyfish (drifter)
}

/// One recolorable species. `depth` is where it likes to hang (0 = surface,
/// 1 = the sand); `speedScale` scales its cruise speed.
public struct FishStyle {
    public let name: String
    public let shape: FishShape
    public let body: RGBA
    public let belly: RGBA
    public let fin: RGBA
    public let eye: RGBA
    public let depth: Double
    public let speedScale: Double
    /// Tendency to make quick darting bursts (0 calm .. 1 flitty).
    public let darts: Double
    /// Extra stripe color (clownfish bands). Defaults to the belly.
    public let stripe: RGBA
    /// Soft aura color (jellyfish). Defaults to nil.
    public let glow: RGBA?
    /// Rim-light sheen along the fish's back. Defaults to a lightened body.
    public let highlight: RGBA
    /// Fin-tip accent. Defaults to a lightened fin.
    public let accent: RGBA

    public init(_ name: String, shape: FishShape, body: RGBA, belly: RGBA, fin: RGBA, eye: RGBA,
                depth: Double, speedScale: Double = 1.0, darts: Double = 0.15,
                stripe: RGBA? = nil, glow: RGBA? = nil,
                highlight: RGBA? = nil, accent: RGBA? = nil) {
        self.name = name
        self.shape = shape
        self.body = body
        self.belly = belly
        self.fin = fin
        self.eye = eye
        self.depth = depth
        self.speedScale = speedScale
        self.darts = darts
        self.stripe = stripe ?? belly
        self.glow = glow
        self.highlight = highlight ?? body.mixed(with: RGBA(hex: 0xFFFFFF), 0.38)
        self.accent = accent ?? fin.mixed(with: RGBA(hex: 0xFFFFFF), 0.30)
    }
}

/// A rare, named catch — the tank's legendary resident. Bigger and wreathed in
/// a soft glow.
public struct LegendaryKind {
    public let name: String
    public let body: RGBA
    public let belly: RGBA
    public let fin: RGBA
    public let eye: RGBA
    public let patch: RGBA
    public let glow: RGBA

    public init(_ name: String, body: RGBA, belly: RGBA, fin: RGBA, eye: RGBA, patch: RGBA, glow: RGBA) {
        self.name = name
        self.body = body
        self.belly = belly
        self.fin = fin
        self.eye = eye
        self.patch = patch
        self.glow = glow
    }
}

/// Environment colors. Swapping the palette re-skins the whole tank (a "theme").
public struct Palette {
    public let waterTop: RGBA
    public let waterBottom: RGBA
    public let sandTop: RGBA
    public let sandLow: RGBA
    public let sandSpeck: RGBA
    public let plantBase: RGBA
    public let plantMid: RGBA
    public let plantTip: RGBA
    public let rayColor: RGBA
    public let night: RGBA
    public let silhouette: RGBA
    public let caustic: RGBA

    public init(waterTop: RGBA, waterBottom: RGBA, sandTop: RGBA, sandLow: RGBA, sandSpeck: RGBA,
                plantBase: RGBA, plantMid: RGBA, plantTip: RGBA, rayColor: RGBA, night: RGBA,
                silhouette: RGBA, caustic: RGBA) {
        self.waterTop = waterTop
        self.waterBottom = waterBottom
        self.sandTop = sandTop
        self.sandLow = sandLow
        self.sandSpeck = sandSpeck
        self.plantBase = plantBase
        self.plantMid = plantMid
        self.plantTip = plantTip
        self.rayColor = rayColor
        self.night = night
        self.silhouette = silhouette
        self.caustic = caustic
    }

    /// Bright planted freshwater tank.
    public static let freshwater = Palette(
        waterTop: RGBA(hex: 0x0B2A5E), waterBottom: RGBA(hex: 0x1C63A8),
        sandTop: RGBA(hex: 0xD9B98A), sandLow: RGBA(hex: 0x9E7F52), sandSpeck: RGBA(hex: 0xEAD3A2),
        plantBase: RGBA(hex: 0x2C7A4C), plantMid: RGBA(hex: 0x3E9B63), plantTip: RGBA(hex: 0x6FC585),
        rayColor: RGBA(hex: 0xBFEFFF, alpha: 22), night: RGBA(hex: 0x08182E),
        silhouette: RGBA(hex: 0x0A2B55), caustic: RGBA(hex: 0xDFF6FF, alpha: 34)
    )

    /// Cold and bioluminescent.
    public static let deepSea = Palette(
        waterTop: RGBA(hex: 0x0B2236), waterBottom: RGBA(hex: 0x0E3A5E),
        sandTop: RGBA(hex: 0x2A3550), sandLow: RGBA(hex: 0x141C2E), sandSpeck: RGBA(hex: 0x3A4A6A),
        plantBase: RGBA(hex: 0x1E5A7A), plantMid: RGBA(hex: 0x2E8AA8), plantTip: RGBA(hex: 0x7FE8E0),
        rayColor: RGBA(hex: 0x6AC8E0, alpha: 20), night: RGBA(hex: 0x02060C),
        silhouette: RGBA(hex: 0x061726), caustic: RGBA(hex: 0x8FD8FF, alpha: 26)
    )

    /// Vivid reef: royal-blue water and pink sand.
    public static let reef = Palette(
        waterTop: RGBA(hex: 0x123C86), waterBottom: RGBA(hex: 0x2E82C8),
        sandTop: RGBA(hex: 0xE8A6C0), sandLow: RGBA(hex: 0xC07898), sandSpeck: RGBA(hex: 0xF6C8DA),
        plantBase: RGBA(hex: 0x1E7A5A), plantMid: RGBA(hex: 0x2E9B6A), plantTip: RGBA(hex: 0x6FC585),
        rayColor: RGBA(hex: 0xCFE8FF, alpha: 22), night: RGBA(hex: 0x08203E),
        silhouette: RGBA(hex: 0x0C2C6A), caustic: RGBA(hex: 0xFFFFFF, alpha: 34)
    )
}

/// Every color and sprite in the tank. Kept in one place so the whole look is
/// tunable from here.
public enum Art {
    // MARK: - Palette

    public static let waterTop = RGBA(hex: 0x1D5A6B)
    public static let waterBottom = RGBA(hex: 0x08222C)
    public static let shimmer = RGBA(hex: 0x6FB6C4, alpha: 90)

    public static let sandTop = RGBA(hex: 0xC7A96B)
    public static let sandLow = RGBA(hex: 0x8A6E3F)
    public static let sandSpeck = RGBA(hex: 0xB18F52)

    public static let rockDark = RGBA(hex: 0x5C5850)
    public static let rockLight = RGBA(hex: 0x8C877E)
    public static let rockHint = RGBA(hex: 0xA9A399)

    public static let plantBase = RGBA(hex: 0x2C7A4C)
    public static let plantMid = RGBA(hex: 0x3E9B63)
    public static let plantTip = RGBA(hex: 0x6FC585)

    public static let rayColor = RGBA(hex: 0xA8ECF2, alpha: 16)
    public static let pebbleDark = RGBA(hex: 0x6E5A34)
    public static let pebbleLight = RGBA(hex: 0xE0C88C)
    public static let mote = RGBA(hex: 0xCFE9EF, alpha: 34)

    public static let pellet = RGBA(hex: 0xD8B25C)
    public static let sparkle = RGBA(hex: 0xFFF3C4)
    public static let bubble = RGBA(hex: 0xAFE0FF, alpha: 200)
    public static let bubbleHi = RGBA(hex: 0xEAFAFF, alpha: 230)

    public static let night = RGBA(hex: 0x0A1A2E)

    // MARK: - Species

    public static let species: [FishStyle] = [
        FishStyle("neon", shape: .standard, body: RGBA(hex: 0x37A6E8), belly: RGBA(hex: 0xC9D6E2), fin: RGBA(hex: 0xE8503A), eye: RGBA(hex: 0x0C1016), depth: 0.35, speedScale: 1.15, darts: 0.35),
        FishStyle("guppy", shape: .guppy, body: RGBA(hex: 0xF2A03C), belly: RGBA(hex: 0xFFD9A0), fin: RGBA(hex: 0xE86A2E), eye: RGBA(hex: 0x1C1208), depth: 0.30, speedScale: 0.95, darts: 0.6),
        FishStyle("danio", shape: .standard, body: RGBA(hex: 0x45C4B0), belly: RGBA(hex: 0xD3F3EE), fin: RGBA(hex: 0x2E9285), eye: RGBA(hex: 0x0B1A17), depth: 0.18, speedScale: 1.25, darts: 0.5),
        FishStyle("platy", shape: .standard, body: RGBA(hex: 0xD25577), belly: RGBA(hex: 0xF3C3CF), fin: RGBA(hex: 0x97284A), eye: RGBA(hex: 0x1A0C12), depth: 0.45, speedScale: 0.90, darts: 0.2),
        FishStyle("rasbora", shape: .standard, body: RGBA(hex: 0xE3C24A), belly: RGBA(hex: 0xF7E9AE), fin: RGBA(hex: 0xC08E22), eye: RGBA(hex: 0x1A1408), depth: 0.40, speedScale: 1.05, darts: 0.3),
        FishStyle("cherry barb", shape: .standard, body: RGBA(hex: 0xD6452E), belly: RGBA(hex: 0xF0B0A0), fin: RGBA(hex: 0x8E2318), eye: RGBA(hex: 0x1A0A08), depth: 0.35, speedScale: 1.10, darts: 0.35),
        FishStyle("cory", shape: .loach, body: RGBA(hex: 0xA08C72), belly: RGBA(hex: 0xDCCFB8), fin: RGBA(hex: 0x6F6050), eye: RGBA(hex: 0x120E08), depth: 0.85, speedScale: 0.70, darts: 0.1),
        FishStyle("angelfish", shape: .angel, body: RGBA(hex: 0xC9CBD6), belly: RGBA(hex: 0xF2F3F7), fin: RGBA(hex: 0x2E3038), eye: RGBA(hex: 0x0A0C10), depth: 0.45, speedScale: 0.65, darts: 0.05),
        FishStyle("puffer", shape: .puffer, body: RGBA(hex: 0x9BC53D), belly: RGBA(hex: 0xE6F0B0), fin: RGBA(hex: 0x6F8F2A), eye: RGBA(hex: 0x181A0A), depth: 0.58, speedScale: 0.60, darts: 0.1),
        FishStyle("clownfish", shape: .clown, body: RGBA(hex: 0xF08A2A), belly: RGBA(hex: 0xFFD9A8), fin: RGBA(hex: 0xE06A1E), eye: RGBA(hex: 0x1A1008), depth: 0.42, speedScale: 0.9, darts: 0.25, stripe: RGBA(hex: 0xFFF4F0)),
        FishStyle("jellyfish", shape: .jelly, body: RGBA(hex: 0xB8A6F0), belly: RGBA(hex: 0xEDE6FF), fin: RGBA(hex: 0x8E7AD0), eye: RGBA(hex: 0x201830), depth: 0.5, speedScale: 0.5, darts: 0.0, glow: RGBA(hex: 0xC7B4FF)),
        FishStyle("betta", shape: .betta, body: RGBA(hex: 0x5B3FC0), belly: RGBA(hex: 0xC9BCF0), fin: RGBA(hex: 0xE23B6D), eye: RGBA(hex: 0x120C18), depth: 0.38, speedScale: 0.75, darts: 0.12),
        FishStyle("goldfish", shape: .goldfish, body: RGBA(hex: 0xF5B301), belly: RGBA(hex: 0xFFE7A0), fin: RGBA(hex: 0xE08A00), eye: RGBA(hex: 0x1A1206), depth: 0.52, speedScale: 0.7, darts: 0.1),
    ]

    /// Species pool for the "3 other fishes" slots (everything but the
    /// headline cast: clownfish, puffer, jellyfish).
    public static let schoolerPool: [Int] = [0, 1, 2, 3, 4, 5, 6, 7, 11, 12]

    private static var spriteCache: [Int: PixelSprite] = [:]

    /// Sprite for a species index (cheaply cached — built once per species).
    /// `puffed` swaps in the inflated puffer pose.
    public static func fishSprite(_ index: Int, puffed: Bool = false) -> PixelSprite {
        let i = normalized(index)
        let style = species[i]
        let usePuffed = puffed && style.shape == .puffer
        let key = i * 2 + (usePuffed ? 1 : 0)
        if let cached = spriteCache[key] { return cached }
        let art = usePuffed ? pufferPuffedArt : shapeArt(style.shape)
        let sprite = PixelSprite(art: art, [
            "o": style.body,
            "b": style.belly,
            "f": style.fin,
            "e": style.eye,
            "w": style.stripe,
            "t": style.fin,
        ])
        spriteCache[key] = sprite
        return sprite
    }

    public static func style(_ index: Int) -> FishStyle {
        species[normalized(index)]
    }

    /// How many leftmost sprite columns form the tail, for the swim flap.
    public static func tailColumns(for shape: FishShape) -> Int {
        switch shape {
        case .standard, .clown: return 2
        case .guppy: return 3
        case .angel, .loach: return 1
        case .betta: return 4
        case .goldfish: return 2
        case .puffer, .jelly: return 0
        }
    }

    /// Whether a species shoals: the slim schoolers (tetras, danios, barbs,
    /// guppies). Bottom-dwellers, angels, and the headline cast do not.
    public static func schools(_ index: Int) -> Bool {
        switch style(index).shape {
        case .standard, .guppy: return true
        default: return false
        }
    }

    // A baby fish (fry): its species' palette, but small. 5x3.
    static let fryShape = """
.ooo.
ffooe
.bbb.
"""

    private static var fryCache: [Int: PixelSprite] = [:]

    /// A small fry coloured like species `index`.
    public static func frySprite(_ index: Int) -> PixelSprite {
        let i = normalized(index)
        if let cached = fryCache[i] { return cached }
        let s = species[i]
        let sprite = PixelSprite(art: fryShape, ["o": s.body, "b": s.belly, "f": s.fin, "e": s.eye])
        fryCache[i] = sprite
        return sprite
    }

    // MARK: - Legendary fish

    public static let legendaryKinds: [LegendaryKind] = [
        LegendaryKind("Kohaku",
                      body: RGBA(hex: 0xF4F1EC), belly: RGBA(hex: 0xFFFFFF), fin: RGBA(hex: 0xDAD3C8),
                      eye: RGBA(hex: 0x161311), patch: RGBA(hex: 0xD93B2B), glow: RGBA(hex: 0xFFB59A)),
    ]

    public static func legendarySprite(_ kind: Int) -> PixelSprite {
        let k = legendaryKinds[((kind % legendaryKinds.count) + legendaryKinds.count) % legendaryKinds.count]
        return PixelSprite(art: legendaryArt, [
            "o": k.body, "b": k.belly, "p": k.patch, "f": k.fin, "e": k.eye,
        ])
    }

    public static func legendaryGlow(_ kind: Int) -> RGBA {
        legendaryKinds[((kind % legendaryKinds.count) + legendaryKinds.count) % legendaryKinds.count].glow
    }

    // A koi, 18x6, facing right — elongated body, flowing tail, dorsal fin,
    // barbels, and multiple red patches (mottled, koi-style).
    // Chars: o body, b belly, p patch, f fin/tail, e eye, . transparent.
    static let legendaryArt = """
........ffff......
...foooppoooppoo..
.ff.oppoopppooooeo
.ff.bbppbbppbbbb..
...fbbbbbbbbbbff..
......bbbbbb......
"""

    private static func normalized(_ index: Int) -> Int {
        ((index % species.count) + species.count) % species.count
    }

    // Art written flush-left so indentation is not baked in.
    // Chars: o = body, b = belly, f = fin/tail, e = eye, . = transparent.
    private static func shapeArt(_ shape: FishShape) -> String {
        switch shape {
        case .standard:
            return """
            f.ooooo..
            ffooooeoo
            f.bbbbb..
            """
        case .guppy:
            return """
            ff..ooooo..
            fff.oooooeo
            ff..bbbbbb.
            f...oooo...
            """
        case .angel:
            return """
            f..ooo..
            f.ooooo.
            ffoooeoo
            f.ooooo.
            f..bbb..
            """
        case .loach:
            return """
            f.oooooeoo
            ffbbbbbbbb
            """
        case .puffer:
            return """
            ..ooo..
            .ooooo.
            oooooeo
            .ooooo.
            ..bbb..
            """
        case .clown:
            return """
            ..oowoowoo
            ffoowooweo
            ..bbwbbwbb
            """
        case .betta:
            return """
            .f..ooooo..
            ff.oooooeoo
            ffffoooooo.
            ff.ooooooo.
            .f..bbbbb..
            """
        case .goldfish:
            return """
            ..ooooo...
            ffooooooo.
            ffoooooeoo
            .ffoooooo.
            ..bbbbb...
            """
        case .jelly:
            return """
            ..bbb..
            .boooo.
            booooob
            .ooooo.
            ..t.t..
            ..t.t..
            """
        }
    }

    // Inflated puffer pose — rounder and spiky, 9x7.
    static let pufferPuffedArt = """
..f...f..
.ooooooo.
ooooooooo
f.ooooeoo
ooooooooo
.ooooooo.
..f...f..
"""

    // MARK: - Cleanup crew

    // A green garden snail, 9x6: a round spiral shell, a dark head with a bright
    // eye on the right, and an orange foot. Faces right.
    static let snailShape = """
..ooooo..
.oGGGgo..
oGggGgddo
oGgGggddy
.oGGGddo.
fffffffff
"""

    static let shrimpShape = """
..oo..
ffoooo
"""

    private static var critterCache: [Int: PixelSprite] = [:]

    public static func critterSprite(_ kind: Int) -> PixelSprite {
        if let cached = critterCache[kind] { return cached }
        let sprite: PixelSprite
        if kind == 0 {
            sprite = PixelSprite(art: snailShape, [
                "o": critterOutline,
                "g": snailShellDark,
                "G": snailShellLight,
                "d": snailBody,
                "y": snailEye,
                "f": snailFoot,
            ])
        } else if kind == 2 {
            sprite = PixelSprite(art: starfishShape, ["s": starfishBody, "S": starfishHi])
        } else {
            sprite = PixelSprite(art: shrimpShape, ["o": shrimpBody, "f": shrimpFin])
        }
        critterCache[kind] = sprite
        return sprite
    }

    // MARK: - Extra creatures & decor

    static let starfishShape = """
..s..
.sSs.
sssss
.s.s.
.s.s.
"""

    static let anemoneShape = """
.t.t.t.
ttttttt
.ttttt.
..ttt..
"""

    public static let starfishBody = RGBA(hex: 0xE8804A)
    public static let starfishHi = RGBA(hex: 0xFFC08A)

    /// A waving anemone (kind 5), tinted from the coral palette.
    public static func anemoneSprite(_ variant: Int) -> PixelSprite {
        coralSprite(anemoneShape, variant)
    }

    /// Shared dark outline so the bottom-dwellers read against the sand.
    public static let critterOutline = RGBA(hex: 0x3A2030)

    /// Green garden snail: dark/light shell greens, a very dark head, a bright
    /// eye, and an orange foot.
    public static let snailShellDark = RGBA(hex: 0x2E5B2F)
    public static let snailShellLight = RGBA(hex: 0x6FBF3F)
    public static let snailBody = RGBA(hex: 0x1B3B1E)
    public static let snailEye = RGBA(hex: 0xF2D24B)
    public static let snailFoot = RGBA(hex: 0xE0913A)

    /// Salmon shrimp.
    public static let shrimpBody = RGBA(hex: 0xE8A6A0)
    public static let shrimpFin = RGBA(hex: 0xC96A64)

    static let rockShape = """
    .rrrr.
    rrrrrr
    rrRrrr
    """

    public static func rockSprite() -> PixelSprite {
        PixelSprite(art: rockShape, ["r": rockDark, "R": rockLight])
    }

    // MARK: - Background decor (rocks & coral)

    static let bigRockShape = """
..rrrr..
.rrrrrr.
rrrrrrrr
rrRrrrrr
"""

    static let smallRockShape = """
.rr.
rRRr
"""

    static let branchCoralShape = """
c.....c
cc...cc
.cc.cc.
..ccc..
..ccc..
..cwc..
"""

    static let fanCoralShape = """
.c.c.c.
ccccccc
.cwcwc.
..ccc..
..cwc..
"""

    static let brainCoralShape = """
.cccc.
cccccc
ccwccc
.cccc.
"""

    public static let coralPalette: [RGBA] = [
        RGBA(hex: 0xE8618A),   // pink
        RGBA(hex: 0xF0913A),   // orange
        RGBA(hex: 0x9A6AD0),   // purple
        RGBA(hex: 0x36B3A0),   // teal
    ]

    /// Background piece. kind: 0 big rock, 1 small rock, 2 branch coral,
    /// 3 fan coral, 4 brain coral, 5 anemone.
    public static func decorSprite(kind: Int, variant: Int) -> PixelSprite {
        switch kind {
        case 0: return PixelSprite(art: bigRockShape, ["r": rockDark, "R": rockLight])
        case 1: return PixelSprite(art: smallRockShape, ["r": rockDark, "R": rockLight])
        case 2: return coralSprite(branchCoralShape, variant)
        case 3: return coralSprite(fanCoralShape, variant)
        case 4: return coralSprite(brainCoralShape, variant)
        default: return coralSprite(anemoneShape, variant)
        }
    }

    private static func coralSprite(_ art: String, _ variant: Int) -> PixelSprite {
        let base = coralPalette[((variant % coralPalette.count) + coralPalette.count) % coralPalette.count]
        return PixelSprite(art: art, ["c": base, "t": base, "w": base.mixed(with: RGBA(hex: 0xFFFFFF), 0.45)])
    }
}
