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
    /// Light pattern colour: clownfish bands, racing stripes, the neon tetra's
    /// electric lateral stripe. Defaults to the belly.
    public let stripe: RGBA
    /// Dark pattern colour: lateral lines, spots, shoulder marks, a catfish's
    /// speckles. Defaults to a deep shade of the body.
    public let pattern: RGBA
    /// The glint beside the eye. Defaults to near-white.
    public let eyeHi: RGBA
    /// The 1px edge that makes a fish read against water and sand. Defaults to
    /// a deep shade of the body.
    public let outline: RGBA
    /// Soft aura color (jellyfish). Defaults to nil.
    public let glow: RGBA?
    /// Rim-light sheen along the fish's back. Defaults to a lightened body.
    public let highlight: RGBA
    /// Fin-tip accent. Defaults to a lightened fin.
    public let accent: RGBA

    public init(_ name: String, shape: FishShape, body: RGBA, belly: RGBA, fin: RGBA, eye: RGBA,
                depth: Double, speedScale: Double = 1.0, darts: Double = 0.15,
                stripe: RGBA? = nil, pattern: RGBA? = nil, eyeHi: RGBA? = nil, accent: RGBA? = nil,
                outline: RGBA? = nil, glow: RGBA? = nil, highlight: RGBA? = nil) {
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
        self.pattern = pattern ?? body.mixed(with: RGBA(hex: 0x0A1020), 0.55)
        self.eyeHi = eyeHi ?? RGBA(hex: 0xFFFFFF)
        self.outline = outline ?? body.mixed(with: RGBA(hex: 0x0A1020), 0.62)
        self.glow = glow
        self.highlight = highlight ?? body.mixed(with: RGBA(hex: 0xFFFFFF), 0.38)
        self.accent = accent ?? fin.mixed(with: RGBA(hex: 0xFFFFFF), 0.30)
    }
}

/// What art a legendary resident uses.
public enum LegendaryShape { case koi, mermaid }

/// A rare, named catch — the tank's legendary resident. Bigger and wreathed in
/// a soft glow.
public struct LegendaryKind {
    public let name: String
    public let shape: LegendaryShape
    public let body: RGBA
    public let belly: RGBA
    public let fin: RGBA
    public let eye: RGBA
    public let patch: RGBA
    public let glow: RGBA
    /// Hair colours for a mermaid (up to 4). Empty for the koi.
    public let hair: [RGBA]

    public init(_ name: String, shape: LegendaryShape = .koi, body: RGBA, belly: RGBA,
                fin: RGBA, eye: RGBA, patch: RGBA, glow: RGBA, hair: [RGBA] = []) {
        self.name = name
        self.shape = shape
        self.body = body
        self.belly = belly
        self.fin = fin
        self.eye = eye
        self.patch = patch
        self.glow = glow
        self.hair = hair
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

    /// Bioluminescent plankton tints.
    public static let planktonColors: [RGBA] = [
        RGBA(hex: 0x7FF0E0),  // cyan
        RGBA(hex: 0xB79CFF),  // violet
        RGBA(hex: 0x8CFF9E),  // green
    ]

    public static let night = RGBA(hex: 0x0A1A2E)

    // MARK: - Species

    public static let species: [FishStyle] = [
        // Neon tetra: silver-blue with its signature electric lateral stripe and
        // a red lower-rear flare.
        FishStyle("neon", shape: .standard,
                  body: RGBA(hex: 0x3AA6E8), belly: RGBA(hex: 0xD6E4F0), fin: RGBA(hex: 0xE8503A), eye: RGBA(hex: 0x0C1016),
                  depth: 0.35, speedScale: 1.15, darts: 0.35,
                  stripe: RGBA(hex: 0x7FE4FF), pattern: RGBA(hex: 0x1E5FA8), outline: RGBA(hex: 0x0E2A55)),
        // Guppy: slim body behind a big flowing fan tail with a colour spot.
        FishStyle("guppy", shape: .guppy,
                  body: RGBA(hex: 0xF2A03C), belly: RGBA(hex: 0xFFD9A0), fin: RGBA(hex: 0xE86A2E), eye: RGBA(hex: 0x1C1208),
                  depth: 0.30, speedScale: 0.95, darts: 0.6,
                  stripe: RGBA(hex: 0xFFCB6A), pattern: RGBA(hex: 0x9B4B12),
                  accent: RGBA(hex: 0xFFD15C), outline: RGBA(hex: 0x5A2A0A)),
        // Zebra danio: torpedo body with twin pale racing stripes.
        FishStyle("danio", shape: .standard,
                  body: RGBA(hex: 0x5FC9B6), belly: RGBA(hex: 0xE0F6F1), fin: RGBA(hex: 0x2E9285), eye: RGBA(hex: 0x0B1A17),
                  depth: 0.18, speedScale: 1.25, darts: 0.5,
                  stripe: RGBA(hex: 0xF2FBE9), pattern: RGBA(hex: 0x1E6F63), outline: RGBA(hex: 0x0C3B34)),
        // Platy: deeper body, dark tail-base, a shoulder spot.
        FishStyle("platy", shape: .standard,
                  body: RGBA(hex: 0xD25577), belly: RGBA(hex: 0xF6C9D5), fin: RGBA(hex: 0x97284A), eye: RGBA(hex: 0x1A0C12),
                  depth: 0.45, speedScale: 0.90, darts: 0.2,
                  stripe: RGBA(hex: 0xF6C9D5), pattern: RGBA(hex: 0x511126), outline: RGBA(hex: 0x40061A)),
        // Harlequin rasbora: gold with a dark lateral line.
        FishStyle("rasbora", shape: .standard,
                  body: RGBA(hex: 0xE3C24A), belly: RGBA(hex: 0xF9EFC0), fin: RGBA(hex: 0xC08E22), eye: RGBA(hex: 0x1A1408),
                  depth: 0.40, speedScale: 1.05, darts: 0.3,
                  stripe: RGBA(hex: 0xFBEFB4), pattern: RGBA(hex: 0x3A2C0C), outline: RGBA(hex: 0x2A2008)),
        // Cherry barb: deep red, darker back, a black shoulder spot.
        FishStyle("cherry barb", shape: .standard,
                  body: RGBA(hex: 0xD8452E), belly: RGBA(hex: 0xF2B6A6), fin: RGBA(hex: 0x8E2318), eye: RGBA(hex: 0x1A0A08),
                  depth: 0.35, speedScale: 1.10, darts: 0.35,
                  stripe: RGBA(hex: 0xF0A090), pattern: RGBA(hex: 0x2A0806), outline: RGBA(hex: 0x3A0806)),
        // Cory catfish: long, low, speckled, with whisker barbels.
        FishStyle("cory", shape: .loach,
                  body: RGBA(hex: 0xA88F6E), belly: RGBA(hex: 0xE6DAC2), fin: RGBA(hex: 0x6F6050), eye: RGBA(hex: 0x120E08),
                  depth: 0.85, speedScale: 0.70, darts: 0.1,
                  stripe: RGBA(hex: 0xCBB794), pattern: RGBA(hex: 0x4A3C28),
                  eyeHi: RGBA(hex: 0xF6EEDA), outline: RGBA(hex: 0x2E2416)),
        // Angelfish: tall diamond, vertical dark bars, amber fin tips.
        FishStyle("angelfish", shape: .angel,
                  body: RGBA(hex: 0xD3D5DF), belly: RGBA(hex: 0xF4F5F9), fin: RGBA(hex: 0x2E3038), eye: RGBA(hex: 0x0A0C10),
                  depth: 0.45, speedScale: 0.65, darts: 0.05,
                  stripe: RGBA(hex: 0xF4F5F9), pattern: RGBA(hex: 0x3E424E),
                  accent: RGBA(hex: 0xF2C84A), outline: RGBA(hex: 0x14161C)),
        // Puffer: round and spotted; the puffed pose is its own art.
        FishStyle("puffer", shape: .puffer,
                  body: RGBA(hex: 0x9BC53D), belly: RGBA(hex: 0xEDF5C0), fin: RGBA(hex: 0x6F8F2A), eye: RGBA(hex: 0x181A0A),
                  depth: 0.58, speedScale: 0.60, darts: 0.1,
                  stripe: RGBA(hex: 0xEDF5C0), pattern: RGBA(hex: 0x4E6A16), outline: RGBA(hex: 0x2E3D0C)),
        // Clownfish: orange with three white bands edged in dark.
        FishStyle("clownfish", shape: .clown,
                  body: RGBA(hex: 0xF48120), belly: RGBA(hex: 0xFFD9A8), fin: RGBA(hex: 0xE06A1E), eye: RGBA(hex: 0x1A1008),
                  depth: 0.42, speedScale: 0.9, darts: 0.25,
                  stripe: RGBA(hex: 0xFFFBF5), pattern: RGBA(hex: 0x2A1408), outline: RGBA(hex: 0x5A2404)),
        // Jellyfish: lavender bell with ribs and tip-tinted tentacles.
        FishStyle("jellyfish", shape: .jelly,
                  body: RGBA(hex: 0xBFAEEF), belly: RGBA(hex: 0xF1EBFF), fin: RGBA(hex: 0x8E7AD0), eye: RGBA(hex: 0x201830),
                  depth: 0.5, speedScale: 0.5, darts: 0.0,
                  stripe: RGBA(hex: 0xE7DEFF), pattern: RGBA(hex: 0x6A55B8), outline: RGBA(hex: 0x3A2C66),
                  glow: RGBA(hex: 0xC7B4FF)),
        // Betta: indigo body under a split rose veil fin.
        FishStyle("betta", shape: .betta,
                  body: RGBA(hex: 0x5B3FC0), belly: RGBA(hex: 0xCFC2F2), fin: RGBA(hex: 0xE23B6D), eye: RGBA(hex: 0x120C18),
                  depth: 0.38, speedScale: 0.75, darts: 0.12,
                  stripe: RGBA(hex: 0x8F76E8), pattern: RGBA(hex: 0x241452),
                  accent: RGBA(hex: 0xFF8FB0), outline: RGBA(hex: 0x1A0C38)),
        // Goldfish: round gold body, a wen, and a flowing split tail.
        FishStyle("goldfish", shape: .goldfish,
                  body: RGBA(hex: 0xF5B301), belly: RGBA(hex: 0xFFE9A6), fin: RGBA(hex: 0xE08A00), eye: RGBA(hex: 0x1A1206),
                  depth: 0.52, speedScale: 0.7, darts: 0.1,
                  stripe: RGBA(hex: 0xFFF0BE), pattern: RGBA(hex: 0xB06A00),
                  accent: RGBA(hex: 0xFF6A3A), outline: RGBA(hex: 0x6A3D00)),
        ]

    /// Species pool for the "other fishes" slots (everything but the
    /// headline cast: clownfish, puffer, jellyfish, and the eel).
    public static let schoolerPool: [Int] = [0, 1, 2, 3, 4, 5, 6, 7, 11, 12]

    private static var spriteCache: [Int: PixelSprite] = [:]

    /// The character palette every fish sprite is coloured from. Kept in one
    /// place so the art can use any layer: o body, b belly, f fin, e eye,
    /// h eye glint, l outline, w light pattern, k dark pattern, a accent.
    private static func fishPalette(_ style: FishStyle) -> [Character: RGBA] {
        [
            "o": style.body,
            "b": style.belly,
            "f": style.fin,
            "e": style.eye,
            "h": style.eyeHi,
            "l": style.outline,
            "w": style.stripe,
            "k": style.pattern,
            "a": style.accent,
            "t": style.fin,
        ]
    }

    /// Sprite for a species index (cheaply cached — built once per species).
    /// `puffed` swaps in the inflated puffer pose.
    public static func fishSprite(_ index: Int, puffed: Bool = false) -> PixelSprite {
        let i = normalized(index)
        let style = species[i]
        let usePuffed = puffed && style.shape == .puffer
        let key = i * 2 + (usePuffed ? 1 : 0)
        if let cached = spriteCache[key] { return cached }
        let art = usePuffed ? pufferPuffedArt : (speciesArt(i) ?? shapeArt(style.shape))
        let sprite = PixelSprite(art: art, fishPalette(style))
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

    // A baby fish (fry): its species' palette, but small — same layering as the
    // adults (outline, glint) so it reads as the same world. 5x3.
    static let fryShape = """
.loo.
flohe
.lbb.
"""

    private static var fryCache: [Int: PixelSprite] = [:]

    /// A small fry coloured like species `index`.
    public static func frySprite(_ index: Int) -> PixelSprite {
        let i = normalized(index)
        if let cached = fryCache[i] { return cached }
        let s = species[i]
        let sprite = PixelSprite(art: fryShape, fishPalette(s))
        fryCache[i] = sprite
        return sprite
    }

    // MARK: - Legendary fish

    public static let legendaryKinds: [LegendaryKind] = [
        LegendaryKind("Kohaku",
                      body: RGBA(hex: 0xF4F1EC), belly: RGBA(hex: 0xFFFFFF), fin: RGBA(hex: 0xDAD3C8),
                      eye: RGBA(hex: 0x161311), patch: RGBA(hex: 0xD93B2B), glow: RGBA(hex: 0xFFB59A)),
        LegendaryKind("Rainbow Mermaid", shape: .mermaid,
                      body: RGBA(hex: 0xF2C9A0), belly: RGBA(hex: 0xFFE6C8), fin: RGBA(hex: 0x35C4A0),
                      eye: RGBA(hex: 0x2A2030), patch: RGBA(hex: 0x9B5DE5), glow: RGBA(hex: 0xFFB0E0),
                      hair: [RGBA(hex: 0xE85D9E), RGBA(hex: 0xF2A03C), RGBA(hex: 0x59C36A), RGBA(hex: 0x5B8DEF)]),
        LegendaryKind("Purple Mermaid", shape: .mermaid,
                      body: RGBA(hex: 0xF2C9A0), belly: RGBA(hex: 0xFFE6C8), fin: RGBA(hex: 0x9B6BE0),
                      eye: RGBA(hex: 0x2A2030), patch: RGBA(hex: 0x6A4CC8), glow: RGBA(hex: 0xC9A0FF),
                      hair: [RGBA(hex: 0x9B5DE5), RGBA(hex: 0xB07CE8), RGBA(hex: 0x7B4FC8), RGBA(hex: 0xD0A8F0)]),
    ]

    public static func legendarySprite(_ kind: Int) -> PixelSprite {
        let k = legendaryKinds[((kind % legendaryKinds.count) + legendaryKinds.count) % legendaryKinds.count]
        switch k.shape {
        case .koi:
            return PixelSprite(art: legendaryArt, [
                "o": k.body, "b": k.belly, "p": k.patch, "f": k.fin, "e": k.eye,
                "h": RGBA(hex: 0xFFFFFF), "l": k.body.mixed(with: RGBA(hex: 0x1A1410), 0.55),
            ])
        case .mermaid:
            return mermaidSprite(k)
        }
    }

    public static func legendaryGlow(_ kind: Int) -> RGBA {
        legendaryKinds[((kind % legendaryKinds.count) + legendaryKinds.count) % legendaryKinds.count].glow
    }

    // A koi, 18x6, facing right — elongated body, flowing tail, dorsal fin,
    // barbels, mottled red patches, and a 1px outline. Chars: o body, b belly,
    // p patch, f fin/tail, e eye, h glint, l outline, . transparent.
    static let legendaryArt = """
........ffff......
...looooppoopppool
..ffooppppooppheol
..ffoobppbbppbbbbl
...lbbbbbbbbbbbbl.
......lbbbbbbl....
"""

    // A mermaid, 8x7: a rounded head of rainbow hair, a face with dark eyes, a
    // shell top, and a fish tail with a fluke. Hair/tail colours come from the kind.
    static let rainbowMermaidArt = """
..rrooy.
.rrooyyy
rrsssssy
rrsesesy
.bbbbby.
.ttttt..
ttTttTt.
"""

    public static let mermaidCrown = RGBA(hex: 0xF6C84A)
    public static let mermaidBlush = RGBA(hex: 0xF7A8C0)
    public static let mermaidMouth = RGBA(hex: 0xE05A6A)
    public static let mermaidHairPink = RGBA(hex: 0xE85D9E)
    public static let mermaidHairOrange = RGBA(hex: 0xF2A03C)
    public static let mermaidHairGreen = RGBA(hex: 0x59C36A)
    public static let mermaidHairBlue = RGBA(hex: 0x5B8DEF)
    public static let mermaidSkin = RGBA(hex: 0xF2C9A0)
    public static let mermaidEye = RGBA(hex: 0x2A2030)
    public static let mermaidBra = RGBA(hex: 0x9B5DE5)
    public static let mermaidTail = RGBA(hex: 0x35C4A0)
    public static let mermaidTailDark = RGBA(hex: 0x1E8A72)

    /// A mermaid sprite coloured from its legendary kind (hair, skin, tail, bra).
    public static func mermaidSprite(_ k: LegendaryKind) -> PixelSprite {
        let hair = k.hair.count >= 4
            ? k.hair
            : [mermaidHairPink, mermaidHairOrange, mermaidHairGreen, mermaidHairBlue]
        return PixelSprite(art: rainbowMermaidArt, [
            "g": mermaidCrown,
            "r": hair[0],
            "o": hair[1],
            "y": hair[2],
            "u": hair[3],
            "s": k.body,
            "e": k.eye,
            "k": mermaidBlush,
            "m": mermaidMouth,
            "b": k.patch,
            "t": k.fin,
            "T": k.fin.mixed(with: RGBA(hex: 0x000000), 0.35),
        ])
    }

    private static func normalized(_ index: Int) -> Int {
        ((index % species.count) + species.count) % species.count
    }

    // Art written flush-left so indentation is not baked in, so no leading
    // indentation is baked into the sprite.
    // Chars: o = body, b = belly, f = fin/tail, e = eye, h = eye glint,
    //        l = outline, w = light pattern, k = dark pattern, a = accent.

    /// A species' own body art where its identity needs more than a recoloured
    /// shared shape. Falls back to `shapeArt` for anything not listed.
    private static func speciesArt(_ index: Int) -> String? {
        switch index {
        case 0:   // neon tetra: slim, electric lateral stripe, red lower-rear
            return """
            .looooool
            flwwwwoeh
            .fffooool
            ..lbbbbbl
            """
        case 1:   // guppy: big fan tail with an eye-spot, slim body
            return """
            .ffa..ooooo
            ffffa.oooeh
            .ffa..ooooo
            ..ffa.bbbbb
            """
        case 2:   // danio: torpedo with twin pale racing stripes
            return """
            .looooohl
            lwwowweo.
            .bbbbbbbl
            """
        case 3:   // platy: deep body, dark tail-base, one shoulder spot
            return """
            .looooool
            looooooeh
            lokooool.
            .bbbbbbbl
            """
        case 4:   // rasbora: gold, dark lateral line
            return """
            .looooohl
            lkkkkkkeo
            .lbbbbbbl
            """
        case 5:   // cherry barb: deep red, dark back, black shoulder spot
            return """
            .lkkkkkkl
            looooooeh
            lkoooool.
            .bbbbbbbl
            """
        case 6:   // cory: long, low, speckled, whisker barbels
            return """
            .looooooe.
            lkoookook.
            .llbbbbll.
            """
        case 7:   // angelfish: tall diamond, vertical bars, amber fin tips
            return """
            ..aooo..
            .lkoool.
            lkoooeho
            .lkoool.
            ..abbb..
            """
        case 8:   // puffer: round and spotted
            return """
            ..koo..
            .ooook.
            kooehok
            .ooook.
            ..bbb..
            """
        case 9:   // clownfish: three white bands edged in dark
            return """
            .lowoowool
            flwoowooeh
            .lbwbbwbbl
            """
        case 10:  // jellyfish: ribbed bell, tip-tinted tentacles
            return """
            ..bbbb..
            .boooob.
            bokookob
            .oooooo.
            ..t..t..
            ..a..a..
            """
        case 11:  // betta: split rose veil fin, iridescent body
            return """
            .f..ooooo..
            ff.ooooooo.
            ffaooooeo..
            ff.ooooooo.
            .f..bbbbb..
            """
        case 12:  // goldfish: round gold body, wen, split flowing tail
            return """
            ..ooooo...
            ffoooooh..
            ffooooeho.
            .ffoooooo.
            ..bbbbb...
            """
        default:
            return nil
        }
    }

    /// Fallback body plan for a shape (also the generic look when a species has
    /// no art of its own).
    private static func shapeArt(_ shape: FishShape) -> String {
        switch shape {
        case .standard:
            return """
            .looooool
            flooooeoh
            ..lbbbbbl
            """
        case .guppy:
            return """
            .ffa..ooooo
            ffffa.oooeh
            .ffa..ooooo
            ..ffa.bbbbb
            """
        case .angel:
            return """
            ..aooo..
            .lkoool.
            lkoooeho
            .lkoool.
            ..abbb..
            """
        case .loach:
            return """
            .looooooe.
            lkoookook.
            .llbbbbll.
            """
        case .puffer:
            return """
            ..koo..
            .ooook.
            kooehok
            .ooook.
            ..bbb..
            """
        case .clown:
            return """
            .lowoowool
            flwoowooeh
            .lbwbbwbbl
            """
        case .betta:
            return """
            .f..ooooo..
            ff.ooooooo.
            ffaooooeo..
            ff.ooooooo.
            .f..bbbbb..
            """
        case .goldfish:
            return """
            ..ooooo...
            ffoooooh..
            ffooooeho.
            .ffoooooo.
            ..bbbbb...
            """
        case .jelly:
            return """
            ..bbbb..
            .boooob.
            bokookob
            .oooooo.
            ..t..t..
            ..a..a..
            """
        }
    }

    // Inflated puffer pose — rounder and spiky, 9x7.
    static let pufferPuffedArt = """
..f...f..
.ooooooo.
oookookoo
foooehooo
oookookoo
.ooooooo.
..b...b..
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

    /// A blue crab, 8x5, scuttling left or right. Wider than it is tall, like
    /// everything else that lives on the sand. The lighter top row gives the
    /// carapace a bit of volume so it doesn't read as a flat blue box at this
    /// size. Chars: o shell, h shell highlight, l legs/claws, e eye.
    static let crabShape = """
..ll..ll
.hoooooh
loee.ool
.loooool
..ll..ll
"""

    public static let crabShell = RGBA(hex: 0xC4432A)
    public static let crabShellHi = RGBA(hex: 0xE8795C)
    public static let crabLeg = RGBA(hex: 0x8A2A18)
    public static let crabEye = RGBA(hex: 0x1A0C08)

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
        } else if kind == 3 {
            sprite = PixelSprite(art: crabShape, ["o": crabShell, "h": crabShellHi, "l": crabLeg, "e": crabEye])
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

    // A little sand castle, 9x6: crenellated top, shaded walls, a dark doorway.
    static let sandCastleShape = """
c.c.c.c.c
ccccccccc
cCcccccCc
cCcdddcCc
cCcdddcCc
ccccccccc
"""

    public static let sandCastle = RGBA(hex: 0xE3C48C)
    public static let sandCastleShade = RGBA(hex: 0xBFA06A)
    public static let sandCastleDark = RGBA(hex: 0x6E5430)

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
    /// 3 fan coral, 4 brain coral, 5 anemone, 6 sand castle.
    public static func decorSprite(kind: Int, variant: Int) -> PixelSprite {
        switch kind {
        case 0: return PixelSprite(art: bigRockShape, ["r": rockDark, "R": rockLight])
        case 1: return PixelSprite(art: smallRockShape, ["r": rockDark, "R": rockLight])
        case 2: return coralSprite(branchCoralShape, variant)
        case 3: return coralSprite(fanCoralShape, variant)
        case 4: return coralSprite(brainCoralShape, variant)
        case 6: return PixelSprite(art: sandCastleShape,
                                   ["c": sandCastle, "C": sandCastleShade, "d": sandCastleDark])
        default: return coralSprite(anemoneShape, variant)
        }
    }

    private static func coralSprite(_ art: String, _ variant: Int) -> PixelSprite {
        let base = coralPalette[((variant % coralPalette.count) + coralPalette.count) % coralPalette.count]
        return PixelSprite(art: art, ["c": base, "t": base, "w": base.mixed(with: RGBA(hex: 0xFFFFFF), 0.45)])
    }
}
