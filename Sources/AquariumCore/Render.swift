import Foundation

/// The pure renderer: `AquariumSim` state -> pixels. No AppKit, no timers.
/// A CLI uses it to emit PNGs; the AppKit view uses it to fill the bar.
public enum Aquarium {
    public static func render(_ sim: AquariumSim, into frame: inout Frame) {
        renderFull(sim, into: &frame)
    }

    /// Render a window `frame.width` wide of a (possibly wider) tank, scrolled to
    /// `cameraX` art pixels. Lets a long tank pan through a narrow view.
    public static func render(_ sim: AquariumSim, into frame: inout Frame, cameraX: Int) {
        var full = Frame(width: sim.config.width, height: sim.config.height)
        renderFull(sim, into: &full)
        let maxX = max(0, sim.config.width - frame.width)
        let cx = max(0, min(maxX, cameraX))
        for y in 0..<frame.height {
            for x in 0..<frame.width {
                frame.set(x, y, full.get(x + cx, y))
            }
        }
    }

    private static func renderFull(_ sim: AquariumSim, into frame: inout Frame) {
        let w = frame.width
        let h = frame.height
        let floorY = sim.floorY
        let palette = sim.config.palette

        drawWater(&frame, w: w, h: h, palette: palette)
        drawRays(&frame, w: w, floorY: floorY, time: sim.time, palette: palette)
        drawMotes(&frame, w: w, floorY: floorY, time: sim.time)
        drawSubstrate(&frame, w: w, h: h, floorY: floorY, palette: palette)
        drawCaustics(&frame, w: w, h: h, floorY: floorY, time: sim.time, palette: palette)
        drawBackdrop(&frame, sim: sim, floorY: floorY, palette: palette)
        drawDecor(&frame, sim: sim, floorY: floorY)
        drawPlants(&frame, sim: sim, floorY: floorY, palette: palette)
        drawCritters(&frame, sim: sim, floorY: floorY)
        drawPellets(&frame, sim: sim)
        drawFish(&frame, sim: sim, floorY: floorY)
        drawSparkles(&frame, sim: sim)
        drawBubbles(&frame, sim: sim)
        drawShimmer(&frame, w: w, time: sim.time)

        if sim.daylight < 1 {
            applyNight(&frame, w: w, h: h, daylight: sim.daylight, palette: palette)
        }
    }

    // MARK: - Background

    private static func drawWater(_ frame: inout Frame, w: Int, h: Int, palette: Palette) {
        for y in 0..<h {
            let t = Double(y) / Double(max(1, h - 1))
            let c = palette.waterTop.mixed(with: palette.waterBottom, t)
            for x in 0..<w { frame.set(x, y, c) }
        }
    }

    private static func drawShimmer(_ frame: inout Frame, w: Int, time: Double) {
        // A drifting surface band near the top.
        let drift = Int((sin(time * 0.7) * 30).rounded())
        for x in 0..<w {
            let band = (x + drift + w) % 40 < 22 ? 1 : 0
            if band == 1 { frame.blend(x, 0, Art.shimmer) }
        }
    }

    // MARK: - Substrate & decor

    private static func drawRays(_ frame: inout Frame, w: Int, floorY: Int, time: Double, palette: Palette) {
        let origins = [Int(Double(w) * 0.14), Int(Double(w) * 0.38), Int(Double(w) * 0.66), Int(Double(w) * 0.86)]
        for (i, ox) in origins.enumerated() {
            let drift = sin(time * 0.25 + Double(i)) * 3
            for y in 0..<floorY {
                let slant = y / 3
                let x = ox + slant + Int(drift.rounded())
                frame.blend(x, y, palette.rayColor)
                if i % 2 == 0 { frame.blend(x + 1, y, palette.rayColor) }
            }
        }
    }

    private static func drawMotes(_ frame: inout Frame, w: Int, floorY: Int, time: Double) {
        for i in 0..<16 {
            let base = i &* 97 &+ 13
            let x = (base &* 13 &+ Int(time * 5)) % max(1, w)
            let y = (base &* 7) % max(1, floorY)
            frame.blend(x, y, Art.mote)
        }
    }

    private static func drawSubstrate(_ frame: inout Frame, w: Int, h: Int, floorY: Int, palette: Palette) {
        for y in floorY..<h {
            let c = y == floorY ? palette.sandTop : palette.sandLow
            for x in 0..<w { frame.set(x, y, c) }
        }
        // Deterministic speckles and a few pebbles on the sand.
        for x in 0..<w {
            if (x &* 2654435761 &+ floorY &* 40503) % 13 == 0 {
                frame.set(x, floorY, palette.sandSpeck)
            }
            if (x &* 40503 &+ 7) % 23 == 0 {
                frame.set(x, floorY, Art.pebbleDark)
                if (x &* 2246822519) % 2 == 0 { frame.set(x, floorY - 1, Art.pebbleLight) }
            }
        }
    }

    private static func drawDecor(_ frame: inout Frame, sim: AquariumSim, floorY: Int) {
        let offsets = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        for d in sim.decor {
            let sprite = Art.decorSprite(kind: d.kind, variant: d.variant)
            // Corals and anemones sway gently in the current.
            let sway = d.kind >= 2 ? Int((sin(sim.time * 1.1 + Double(d.x) * 0.13) * 0.7).rounded()) : 0
            let y = floorY - sprite.height
            if d.kind >= 2 {
                // Corals glow softly, bioluminescent-style.
                let base = Art.coralPalette[((d.variant % Art.coralPalette.count) + Art.coralPalette.count) % Art.coralPalette.count]
                let glow = base.withAlpha(42)
                for (dx, dy) in offsets {
                    sprite.drawSilhouette(into: &frame, x: d.x + dx + sway, y: y + dy, color: glow)
                }
            }
            sprite.draw(into: &frame, x: d.x + sway, y: y)
        }
    }

    /// Dappled light playing over the sand and lower water.
    private static func drawCaustics(_ frame: inout Frame, w: Int, h: Int, floorY: Int, time: Double, palette: Palette) {
        for y in max(0, floorY - 3)..<h {
            for x in 0..<w {
                let n = sin(Double(x) * 0.17 + time * 1.1)
                    + sin(Double(x) * 0.08 - time * 0.7 + Double(y) * 1.3)
                if n > 1.0 { frame.blend(x, y, palette.caustic) }
            }
        }
    }

    /// Distant reef spires, drawn in a flat silhouette for depth.
    private static func drawBackdrop(_ frame: inout Frame, sim: AquariumSim, floorY: Int, palette: Palette) {
        for s in sim.backdrop {
            for row in 0..<s.height {
                let y = floorY - 1 - row
                let shrink = row / 2
                let x0 = s.x + shrink
                let width = max(1, s.width - shrink * 2)
                for x in x0..<(x0 + width) {
                    frame.blend(x, y, palette.silhouette)
                }
            }
        }
    }

    private static func drawPlants(_ frame: inout Frame, sim: AquariumSim, floorY: Int, palette: Palette) {
        for p in sim.plants {
            for k in 0..<p.height {
                let py = floorY - 1 - k
                let frac = Double(k) / Double(max(1, p.height))
                let sway = Int((sin(sim.time * 1.5 + p.phase + Double(k) * 0.4) * frac * 2.4).rounded())
                frame.blend(p.x + sway, py, plantColor(frac, palette))
            }
        }
    }

    private static func plantColor(_ frac: Double, _ palette: Palette) -> RGBA {
        frac < 0.5
            ? palette.plantBase.mixed(with: palette.plantMid, frac * 2)
            : palette.plantMid.mixed(with: palette.plantTip, (frac - 0.5) * 2)
    }

    // MARK: - Entities

    private static func drawCritters(_ frame: inout Frame, sim: AquariumSim, floorY: Int) {
        for c in sim.critters {
            let sprite = Art.critterSprite(c.kind)
            let px = max(0, min(frame.width - sprite.width, Int(c.x.rounded()) - sprite.width / 2))
            let py = max(0, min(floorY - sprite.height, Int(c.y.rounded())))
            sprite.draw(into: &frame, x: px, y: py, flipX: c.vx < 0)
        }
    }

    private static func drawPellets(_ frame: inout Frame, sim: AquariumSim) {
        for p in sim.pellets {
            let x = Int(p.x.rounded())
            let y = Int(p.y.rounded())
            frame.blend(x, y, Art.pellet)
            frame.blend(x, y + 1, Art.pellet)
        }
    }

    private static func drawFish(_ frame: inout Frame, sim: AquariumSim, floorY: Int) {
        let offsets = [(-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, -1), (-1, 1), (1, 1)]
        let palette = sim.config.palette
        let minY = 1.5
        let span = max(0.001, (Double(floorY) - 1.5) - minY)

        for f in sim.fish {
            let style = Art.species[((f.species % Art.species.count) + Art.species.count) % Art.species.count]
            let isJelly = style.shape == .jelly
            let sprite = f.isLegendary
                ? Art.legendarySprite(f.legendaryKind)
                : (f.baby ? Art.frySprite(f.species) : Art.fishSprite(f.species, puffed: f.puff > 0))
            let flip = f.facing < 0
            // A gentle vertical bob reads as "swimming"; the tail flap below adds
            // the actual swish. (Row-wise body undulation looked torn at this size.)
            let bob = Int((sin(f.phase) * 0.6).rounded())
            var px = Int(f.x.rounded()) - sprite.width / 2
            var py = Int(f.y.rounded()) - sprite.height / 2 + bob
            px = max(0, min(frame.width - sprite.width, px))
            py = max(0, min(floorY - sprite.height, py))

            if f.isLegendary {
                let glow = Art.legendaryGlow(f.legendaryKind).withAlpha(58)
                for (dx, dy) in offsets {
                    sprite.drawSilhouette(into: &frame, x: px + dx, y: py + dy, color: glow, flipX: flip)
                }
            } else if isJelly, let glowColor = style.glow {
                let glow = glowColor.withAlpha(26)
                for (dx, dy) in offsets {
                    sprite.drawSilhouette(into: &frame, x: px + dx, y: py + dy, color: glow, flipX: flip)
                }
            }

            if isJelly {
                drawJelly(&frame, sprite: sprite, x: px, y: py, phase: f.phase)
                continue
            }

            // Depth cue: a fish that hangs nearer the surface reads as farther
            // back, so it is tinted toward the water. (1 = near, 0 = far.)
            let near = max(0, min(1, (f.homeY - minY) / span))
            let depth = 1 - near

            let fin: RGBA, highlight: RGBA, accent: RGBA
            let tailCols: Int
            if f.isLegendary {
                let kinds = Art.legendaryKinds
                let k = kinds[((f.legendaryKind % kinds.count) + kinds.count) % kinds.count]
                fin = k.fin
                highlight = k.glow.mixed(with: RGBA(hex: 0xFFFFFF), 0.30)
                accent = k.patch
                tailCols = 2
            } else {
                fin = style.fin
                highlight = style.highlight
                accent = style.accent
                tailCols = f.baby ? 2 : Art.tailColumns(for: style.shape)
            }

            drawFishSprite(&frame, sprite: sprite, x: px, y: py, flip: flip,
                           tailCols: tailCols, phase: f.phase, burst: f.burst,
                           depth: depth, palette: palette,
                           fin: fin, highlight: highlight, accent: accent)
        }
    }

    /// Draws a fish column by column so the tail can swish independently of the
    /// body, the back catches a rim light, and the fin tips take the accent.
    private static func drawFishSprite(_ frame: inout Frame, sprite: PixelSprite, x: Int, y: Int,
                                       flip: Bool, tailCols: Int, phase: Double, burst: Double,
                                       depth: Double, palette: Palette,
                                       fin: RGBA, highlight: RGBA, accent: RGBA) {
        // The tail flaps as a unit (never tearing from the body); the tip moves
        // a little further during a dart burst.
        let swish = sin(phase * 1.9) * (0.9 + (burst > 0.05 ? 0.5 : 0))
        let tint = (1 - depth) * 0.26

        // Topmost opaque pixel per column, for the back's rim light.
        var topRow = [Int](repeating: -1, count: sprite.width)
        for col in 0..<sprite.width {
            for row in 0..<sprite.height where sprite.pixels[row * sprite.width + col] != nil {
                topRow[col] = row
                break
            }
        }

        for row in 0..<sprite.height {
            for col in 0..<sprite.width {
                guard var c = sprite.pixels[row * sprite.width + col] else { continue }

                var dx = 0
                if tailCols >= 2 && col < tailCols {
                    // Shift the whole tail together so it never tears off the body.
                    dx = Int(swish.rounded())
                }
                if c == fin { c = c.mixed(with: accent, 0.35) }
                if row == topRow[col] { c = c.mixed(with: highlight, 0.40) }
                if tint > 0.001 { c = c.mixed(with: palette.waterTop, tint) }

                let sx = flip ? (sprite.width - 1 - col) : col
                frame.blend(x + sx + (flip ? -dx : dx), y + row, c)
            }
        }
    }

    /// Jellyfish bell is rigid; the tentacle rows wobble as it pulses.
    private static func drawJelly(_ frame: inout Frame, sprite: PixelSprite, x: Int, y: Int, phase: Double) {
        let tentacleRows = 2
        let off = Int((sin(phase * 2.4) * 1.0).rounded())
        for row in 0..<sprite.height {
            let isTentacle = row >= sprite.height - tentacleRows
            let dx = isTentacle ? off : 0
            for col in 0..<sprite.width {
                guard var c = sprite.pixels[row * sprite.width + col] else { continue }
                c.a = UInt8((Double(c.a) * 0.92).rounded())
                frame.blend(x + col + dx, y + row, c)
            }
        }
    }

    private static func drawSparkles(_ frame: inout Frame, sim: AquariumSim) {
        for s in sim.sparkles {
            let a = max(0, min(1, s.life / s.maxLife))
            frame.blend(Int(s.x.rounded()), Int(s.y.rounded()), Art.sparkle.withAlpha(UInt8(255 * a)))
        }
    }

    private static func drawBubbles(_ frame: inout Frame, sim: AquariumSim) {
        for b in sim.bubbles {
            let x = Int(b.x.rounded())
            let y = Int(b.y.rounded())
            if b.big {
                frame.blend(x, y, Art.bubble)
                frame.blend(x + 1, y, Art.bubble)
                frame.blend(x, y + 1, Art.bubble)
                frame.blend(x + 1, y + 1, Art.bubble)
                frame.blend(x, y, Art.bubbleHi)
            } else {
                frame.blend(x, y, Art.bubble)
            }
        }
    }

    // MARK: - Day / night

    private static func applyNight(_ frame: inout Frame, w: Int, h: Int, daylight: Double, palette: Palette) {
        let amount = (1 - max(0, min(1, daylight))) * 0.7
        for y in 0..<h {
            for x in 0..<w {
                frame.set(x, y, frame.get(x, y).mixed(with: palette.night, amount))
            }
        }
    }
}
