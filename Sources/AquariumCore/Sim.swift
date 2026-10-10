import Foundation

/// Static knobs for the tank. Art-space units: 1 unit == 1 pixel of the small
/// canvas the renderer draws into (the host scales that up for the bar).
public struct TankConfig {
    public var width: Int = 360
    public var height: Int = 10
    public var floorHeight: Int = 2
    public var fishCount: Int = 7
    /// Whether the tank includes its legendary resident. On by default.
    public var legendaryChance: Double = 1.0
    public var seed: UInt64 = 0xA9E1

    /// Day/night cycle. `dayLength` is real seconds per full 24h cycle.
    public var dayNightEnabled: Bool = true
    public var dayLength: Double = 600
    public var startHour: Double = 9
    /// Environment palette (theme).
    public var palette: Palette = .freshwater

    public init() {}
}

public struct Fish {
    public var x: Double
    public var y: Double
    public var vx: Double
    public var vy: Double
    public var species: Int
    public var facing: Int      // -1 left, +1 right
    public var phase: Double    // animation phase
    public var speed: Double    // preferred cruise speed
    public var hunger: Double   // 0..1
    public var homeY: Double    // preferred depth (art-space y)
    public var homeX: Double    // territory center (keeps the tank spread out)
    public var radius: Double   // sprite half-width, for spacing

    // Wander destination. Each fish swims to a target, then picks another,
    // which keeps them roaming the whole tank instead of bunching up.
    public var tx: Double
    public var ty: Double
    public var retarget: Double // seconds until a new destination

    public var isLegendary: Bool = false
    public var legendaryKind: Int = 0
    public var burst: Double = 0   // remaining dart-burst time
    public var puff: Double = 0    // remaining puffer-inflation time
    public var pulse: Double = 0   // jellyfish pulse timer
}

public struct Bubble {
    public var x: Double
    public var y: Double
    public var vy: Double
    public var phase: Double
    public var big: Bool
}

public struct Pellet {
    public var x: Double
    public var y: Double
    public var vy: Double
    public var life: Double
}

public struct Plant {
    public var x: Int
    public var height: Int
    public var phase: Double
}

/// A glowing mote trailing the legendary fish.
public struct Sparkle {
    public var x: Double
    public var y: Double
    public var vy: Double
    public var life: Double
    public var maxLife: Double
}

/// A little bottom-dweller: a snail or a shrimp.
public struct Critter {
    public var kind: Int      // 0 = snail, 1 = shrimp
    public var x: Double
    public var y: Double
    public var vx: Double
    public var phase: Double
    public var timer: Double
}

/// A static background piece: a rock or a coral.
public struct Decor {
    public var kind: Int      // 0 big rock, 1 small rock, 2 branch, 3 fan, 4 brain
    public var variant: Int
    public var x: Int
}

/// A distant reef silhouette that gives the tank depth.
public struct Spire {
    public var x: Int
    public var width: Int
    public var height: Int
}

/// The tank's living model. This is the deep module: a tiny interface
/// (`tick`/`feed`/`poke` plus read-only state) hiding all the behavior —
/// roaming, spacing, depth preference, food seeking, bubbles, plants.
/// It imports no UI framework, so it is fully testable headless.
public struct AquariumSim {
    public private(set) var config: TankConfig
    public private(set) var fish: [Fish] = []
    public private(set) var bubbles: [Bubble] = []
    public private(set) var pellets: [Pellet] = []
    public private(set) var plants: [Plant] = []
    public private(set) var sparkles: [Sparkle] = []
    public private(set) var critters: [Critter] = []
    public private(set) var decor: [Decor] = []
    public private(set) var backdrop: [Spire] = []
    public private(set) var bubblerX: Int = 0
    public private(set) var time: Double = 0
    /// Current time of day, 0..24. Advances with the day/night cycle.
    public private(set) var clockHour: Double = 9
    /// 1.0 = full daylight, 0.0 = deep night. Drives the render tint and how
    /// lively the fish are.
    public var daylight: Double = 1.0

    /// Name of the legendary resident, if the tank rolled one.
    public var legendaryName: String? {
        guard let i = legendaryIndex, i < fish.count else { return nil }
        return Art.legendaryKinds[fish[i].legendaryKind].name
    }

    private var rng: SeededRandom
    private var bubbleTimer: Double = 0
    private var fearTimer: Double = 0
    private var fearX: Double = 0
    private var legendaryIndex: Int?
    private var sparkleTimer: Double = 0

    public var floorY: Int { config.height - config.floorHeight }
    private var minX: Double { 7 }
    private var maxX: Double { Double(config.width) - 8 }
    private var minY: Double { 1.5 }
    private var maxY: Double { Double(floorY) - 1.5 }

    /// Smooth daylight curve: ~1.0 around 13:00, ~0.12 around 01:00.
    public static func computeDaylight(_ hour: Double) -> Double {
        let h = hour.truncatingRemainder(dividingBy: 24)
        let phase = (h - 13.0) / 24.0 * 2.0 * .pi
        let t = (cos(phase) + 1) / 2
        return 0.12 + 0.88 * t
    }

    public init(config: TankConfig = TankConfig()) {
        self.config = config
        self.rng = SeededRandom(seed: config.seed)
        self.bubblerX = config.width - 26
        self.clockHour = config.startHour
        self.daylight = AquariumSim.computeDaylight(config.startHour)
        scatterFish()
        if rng.unit() < config.legendaryChance { addLegendary() }
        plantGarden()
        decorate()
        seedCritters()
        seedBubbles()
    }

    // MARK: - Public interface

    /// Advance the world by `dt` seconds. Safe to call with any non-negative dt.
    public mutating func tick(dt: Double) {
        let dt = max(0, min(dt, 0.1))
        guard dt > 0 else { return }
        time += dt

        if config.dayNightEnabled {
            clockHour += dt * 24.0 / max(1, config.dayLength)
            clockHour = clockHour.truncatingRemainder(dividingBy: 24)
            daylight = AquariumSim.computeDaylight(clockHour)
        }

        updatePellets(dt)
        updateFish(dt)
        updateCritters(dt)
        updateSparkles(dt)
        updateBubbles(dt)

        if fearTimer > 0 { fearTimer = max(0, fearTimer - dt) }
    }

    /// Re-skin the environment (theme).
    public mutating func setPalette(_ palette: Palette) {
        config.palette = palette
    }

    /// Drop food at horizontal position `x` (art-space). Fish will swim to it.
    public mutating func feed(x: Double) {
        let cx = max(minX, min(maxX, x))
        pellets.append(Pellet(x: cx, y: 1.0, vy: 2.5, life: 22))
    }

    /// Tap the glass at `x`. Nearby fish scatter.
    @discardableResult
    public mutating func poke(x: Double) -> Int {
        fearX = max(minX, min(maxX, x))
        fearTimer = 1.6
        // A puffer puffs up when startled.
        for i in 0..<fish.count
            where Art.species[fish[i].species].shape == .puffer && abs(fish[i].x - fearX) < 90 {
            fish[i].puff = 1.6
        }
        return fish.filter { abs($0.x - fearX) < 70 }.count
    }

    // MARK: - Fish

    private mutating func scatterFish() {
        // The headline cast, then fill the remaining slots with random
        // schoolers so the "3 other fishes" vary from tank to tank.
        var roster: [Int] = [9, 8, 10, 10]   // clownfish, pufferfish, two jellyfish
        var pool = Art.schoolerPool
        for _ in 0..<max(0, config.fishCount - roster.count) {
            guard !pool.isEmpty else { break }
            roster.append(pool.remove(at: rng.int(pool.count)))
        }

        for (k, speciesIndex) in roster.enumerated() {
            let style = Art.species[speciesIndex]
            let isJelly = style.shape == .jelly
            let homeY = minY + (maxY - minY) * style.depth
            // Evenly spaced territories keep the school spread across the tank.
            let homeX = minX + (Double(k) + 0.5) / Double(roster.count) * (maxX - minX) + rng.range(-8, 8)
            let x = rng.range(Double(minX + 6), Double(maxX - 6))
            let y = isJelly
                ? rng.range(minY + 1, maxY - 1)
                : min(maxY - 1, max(minY + 1, homeY + rng.range(-0.8, 0.8)))
            let dir = rng.unit() < 0.5 ? -1.0 : 1.0
            fish.append(Fish(
                x: x, y: y,
                vx: isJelly ? rng.range(-1.4, 1.4) : dir * rng.range(2, 4),
                vy: 0,
                species: speciesIndex,
                facing: dir < 0 ? -1 : 1,
                phase: rng.range(0, 6.28),
                speed: rng.range(4.2, 7.2) * style.speedScale,
                hunger: rng.range(0.4, 1.0),
                homeY: homeY,
                homeX: homeX,
                radius: Double(Art.fishSprite(speciesIndex).width) * 0.5,
                tx: x, ty: y, retarget: 0
            ))
            let idx = fish.count - 1
            if isJelly {
                fish[idx].pulse = rng.range(0.5, 2.0)
            } else {
                requestTarget(idx)
            }
        }
    }

    /// Add the tank's legendary resident (only when the opening roll succeeds).
    private mutating func addLegendary() {
        let kind = rng.int(Art.legendaryKinds.count)
        let homeY = minY + (maxY - minY) * 0.5
        let x = rng.range(Double(minX + 20), Double(maxX - 40))
        let homeX = rng.range(minX + 50, maxX - 50)
        fish.append(Fish(
            x: x, y: homeY,
            vx: 2, vy: 0,
            species: 0,
            facing: 1,
            phase: rng.range(0, 6.28),
            speed: 3.6,
            hunger: 0.8,
            homeY: homeY,
            homeX: homeX,
            radius: Double(Art.legendarySprite(kind).width) * 0.5,
            tx: x, ty: homeY, retarget: 0,
            isLegendary: true,
            legendaryKind: kind
        ))
        legendaryIndex = fish.count - 1
        requestTarget(fish.count - 1)
    }

    /// Choose a fresh destination for fish `i`, within its depth band and far
    /// enough away to be a real journey. Candidates are scored by how far they
    /// sit from the other fish, which keeps the school spread out over time.
    private mutating func requestTarget(_ i: Int) {
        let band = 1.8
        let tyLo = max(minY + 0.5, fish[i].homeY - band)
        let tyHi = min(maxY - 0.5, fish[i].homeY + band)
        // Roam within a home region so fish stay spread out.
        let loX = max(minX + 8, fish[i].homeX - 70)
        let hiX = min(maxX - 8, fish[i].homeX + 70)

        var bestX = fish[i].x
        var bestScore = -Double.greatestFiniteMagnitude
        for _ in 0..<6 {
            var candidate = rng.range(loX, hiX)
            if abs(candidate - fish[i].x) < 45 {
                candidate = fish[i].x + (candidate >= fish[i].x ? 60 : -60)
                candidate = min(hiX, max(loX, candidate))
            }
            var nearest = Double.greatestFiniteMagnitude
            for j in 0..<fish.count where j != i {
                nearest = min(nearest, abs(candidate - fish[j].x))
            }
            if nearest > bestScore { bestScore = nearest; bestX = candidate }
        }
        fish[i].tx = bestX
        fish[i].ty = rng.range(tyLo, tyHi)
        fish[i].retarget = rng.range(8.0, 16.0)
    }

    private mutating func updateFish(_ dt: Double) {
        let n = fish.count
        guard n > 0 else { return }

        for i in 0..<n {
            // Jellyfish drift and pulse rather than swim to destinations.
            if Art.species[fish[i].species].shape == .jelly {
                updateJelly(i, dt)
                continue
            }

            // Swim toward the current destination; pick a new one on arrival
            // or when the timer runs out.
            fish[i].retarget -= dt
            var dxT = fish[i].tx - fish[i].x
            var dyT = fish[i].ty - fish[i].y
            var distT = (dxT * dxT + dyT * dyT).squareRoot()
            if fish[i].retarget <= 0 || distT < 5 {
                requestTarget(i)
                dxT = fish[i].tx - fish[i].x
                dyT = fish[i].ty - fish[i].y
                distT = max(0.001, (dxT * dxT + dyT * dyT).squareRoot())
            }

            // Seek the destination. (Overlaps are resolved positionally after
            // the loop, so spacing can never cancel a fish's progress.)
            let approach = 0.45 + 0.55 * min(1.0, distT / 12.0)
            var dvx = (dxT / max(0.001, distT)) * fish[i].speed * approach
            var dvy = (dyT / max(0.001, distT)) * fish[i].speed * approach * 0.45

            // Soft pull toward home keeps each fish in its own region.
            dvx += (fish[i].homeX - fish[i].x) * 0.14

            // Fish are lively in daylight and languid at night.
            let energy = 0.4 + 0.6 * daylight
            dvx *= energy
            dvy *= energy

            // Personalities: flitty species dart in short bursts; puffers
            // deflate on a timer (after being poked).
            fish[i].puff = max(0, fish[i].puff - dt)
            if !fish[i].isLegendary {
                fish[i].burst = max(0, fish[i].burst - dt)
                if fish[i].burst == 0, rng.unit() < Art.species[fish[i].species].darts * dt * 0.8 {
                    fish[i].burst = rng.range(0.35, 0.7)
                }
                if fish[i].burst > 0 {
                    dvx *= 1.9
                    dvy *= 1.9
                }
            }
            if let target = nearestPellet(to: fish[i]) {
                let dx = target.x - fish[i].x
                let dy = target.y - fish[i].y
                let d = max(0.001, (dx * dx + dy * dy).squareRoot())
                let pull = 26 * (0.6 + 0.4 * (1 - fish[i].hunger))
                dvx += (dx / d) * pull
                dvy += (dy / d) * pull
                if d < 1.8 {
                    eatPellet(near: fish[i])
                    fish[i].hunger = 1.0
                }
            }

            // Flee a poke.
            if fearTimer > 0 {
                let dir: Double = fish[i].x >= fearX ? 1 : -1
                let strength = 46 * (fearTimer / 1.6)
                dvx += dir * strength
                dvy += (fish[i].y < Double(floorY) / 2 ? 10 : -10) * (fearTimer / 1.6)
            }

            // Steer current velocity toward the desired velocity.
            let k = min(1, 6 * dt)
            fish[i].vx += (dvx - fish[i].vx) * k
            fish[i].vy += (dvy - fish[i].vy) * k

            fish[i].x += fish[i].vx * dt
            fish[i].y += fish[i].vy * dt

            // Keep inside; at a wall, guarantee outward momentum so a fish
            // commits to leaving instead of turning in place.
            if fish[i].x < minX {
                fish[i].x = minX
                fish[i].vx = max(fish[i].vx, 4)
                fish[i].tx = rng.range(minX + 40, maxX - 8)
            } else if fish[i].x > maxX {
                fish[i].x = maxX
                fish[i].vx = min(fish[i].vx, -4)
                fish[i].tx = rng.range(minX + 8, maxX - 40)
            }
            if fish[i].y < minY { fish[i].y = minY; fish[i].vy = max(fish[i].vy, 2) }
            if fish[i].y > maxY { fish[i].y = maxY; fish[i].vy = min(fish[i].vy, -2) }

            // Facing with hysteresis so the sprite doesn't flicker.
            if fish[i].vx > 0.5 { fish[i].facing = 1 }
            else if fish[i].vx < -0.5 { fish[i].facing = -1 }

            fish[i].phase += dt * (abs(fish[i].vx) * 0.35 + 1.5)
            fish[i].hunger = max(0, fish[i].hunger - dt * 0.03)
        }

        relaxSpacing()
    }

    /// Push overlapping fish apart positionally. Unlike a force, this can never
    /// cancel a fish's momentum, so slow fish don't get pinned in place.
    private mutating func relaxSpacing() {
        let count = fish.count
        guard count > 1 else { return }
        for i in 0..<count {
            let jellyI = Art.species[fish[i].species].shape == .jelly
            for j in (i + 1)..<count {
                // Jellyfish are soft: let them pass through everything.
                if jellyI || Art.species[fish[j].species].shape == .jelly { continue }
                let dx = fish[i].x - fish[j].x
                let dy = fish[i].y - fish[j].y
                let minD = (fish[i].radius + fish[j].radius) * 1.15
                let d2 = dx * dx + dy * dy
                guard d2 > 0.0001, d2 < minD * minD else { continue }
                let d = d2.squareRoot()
                let overlap = (minD - d) * 0.5
                // Cap the per-tick correction: an uncapped push can move a fish
                // 100s of px/s and scramble the whole tank.
                let step = min(overlap, 0.35)
                let ux = dx / d
                let uy = dy / d
                fish[i].x += ux * step
                fish[i].y += uy * step
                fish[j].x -= ux * step
                fish[j].y -= uy * step
            }
        }
        for i in 0..<count {
            fish[i].x = min(maxX, max(minX, fish[i].x))
            fish[i].y = min(maxY, max(minY, fish[i].y))
        }
    }

    /// Jellyfish don't seek destinations: they pulse upward, slowly sink, and
    /// drift with a gentle current.
    private mutating func updateJelly(_ i: Int, _ dt: Double) {
        fish[i].phase += dt
        fish[i].pulse -= dt
        if fish[i].pulse <= 0 {
            fish[i].pulse = rng.range(1.8, 3.2)
            fish[i].vy = -rng.range(3.5, 6.0)          // contract upward
            if rng.unit() < 0.4 { fish[i].vx = rng.range(-1.6, 1.6) }
        }
        fish[i].vy += 3.5 * dt                          // slow sink between pulses
        fish[i].x += fish[i].vx * dt
        fish[i].y += fish[i].vy * dt

        if fish[i].y < minY { fish[i].y = minY; fish[i].vy = abs(fish[i].vy) * 0.3 }
        if fish[i].y > maxY { fish[i].y = maxY; fish[i].vy = -abs(fish[i].vy) * 0.3 }
        if fish[i].x < minX { fish[i].x = minX; fish[i].vx = abs(fish[i].vx) }
        if fish[i].x > maxX { fish[i].x = maxX; fish[i].vx = -abs(fish[i].vx) }
    }

    private func nearestPellet(to f: Fish) -> Pellet? {
        var best: Pellet?
        var bestD = Double.greatestFiniteMagnitude
        for p in pellets {
            let dx = p.x - f.x
            let dy = p.y - f.y
            let d = dx * dx + dy * dy
            if d < bestD { bestD = d; best = p }
        }
        return best
    }

    private mutating func eatPellet(near f: Fish) {
        var bestIndex = -1
        var bestD = Double.greatestFiniteMagnitude
        for (idx, p) in pellets.enumerated() {
            let d = (p.x - f.x) * (p.x - f.x) + (p.y - f.y) * (p.y - f.y)
            if d < bestD { bestD = d; bestIndex = idx }
        }
        if bestIndex >= 0 && bestD < 4 { pellets.remove(at: bestIndex) }
    }

    // MARK: - Pellets

    private mutating func updatePellets(_ dt: Double) {
        var kept: [Pellet] = []
        kept.reserveCapacity(pellets.count)
        for var p in pellets {
            p.life -= dt
            if p.y < Double(floorY) - 1 {
                p.y += p.vy * dt
                if p.y > Double(floorY) - 1 { p.y = Double(floorY) - 1 }
            }
            if p.life > 0 { kept.append(p) }
        }
        pellets = kept
    }

    // MARK: - Legendary sparkles

    private mutating func updateSparkles(_ dt: Double) {
        if let li = legendaryIndex, li < fish.count {
            sparkleTimer -= dt
            if sparkleTimer <= 0 {
                sparkleTimer = rng.range(0.25, 0.8)
                let f = fish[li]
                let life = rng.range(0.6, 1.4)
                sparkles.append(Sparkle(
                    x: f.x + rng.range(-7, 7),
                    y: f.y + rng.range(-3, 2),
                    vy: -rng.range(2, 5),
                    life: life,
                    maxLife: life
                ))
            }
        }
        var kept: [Sparkle] = []
        kept.reserveCapacity(sparkles.count)
        for var s in sparkles {
            s.life -= dt
            s.y += s.vy * dt
            s.x += rng.range(-2, 2) * dt
            if s.life > 0 { kept.append(s) }
        }
        sparkles = kept
    }

    // MARK: - Bubbles

    private mutating func seedBubbles() {
        for _ in 0..<6 {
            bubbles.append(Bubble(
                x: Double(bubblerX) + rng.range(-1, 1),
                y: rng.range(Double(floorY) - 6, Double(floorY) - 1),
                vy: -rng.range(4, 7),
                phase: rng.range(0, 6.28),
                big: rng.unit() < 0.25
            ))
        }
    }

    private mutating func updateBubbles(_ dt: Double) {
        bubbleTimer -= dt
        if bubbleTimer <= 0 {
            bubbleTimer = rng.range(0.3, 1.0)
            bubbles.append(Bubble(
                x: Double(bubblerX) + rng.range(-1, 1),
                y: Double(floorY) - 1,
                vy: -rng.range(4, 7),
                phase: rng.range(0, 6.28),
                big: rng.unit() < 0.22
            ))
        }
        var kept: [Bubble] = []
        kept.reserveCapacity(bubbles.count)
        for var b in bubbles {
            b.phase += dt * 3
            b.x += sin(b.phase) * dt * 6
            b.y += b.vy * dt
            if b.y > -1.5 { kept.append(b) }
        }
        bubbles = kept
    }

    // MARK: - Cleanup crew

    private mutating func seedCritters() {
        // One snail, two shrimp, one starfish.
        critters.append(Critter(kind: 0, x: rng.range(30, Double(config.width - 30)),
                                y: Double(floorY) - 3, vx: rng.range(0.8, 1.8),
                                phase: 0, timer: rng.range(2, 6)))
        for _ in 0..<2 {
            critters.append(Critter(kind: 1, x: rng.range(30, Double(config.width - 30)),
                                    y: Double(floorY) - 2, vx: 0,
                                    phase: rng.range(0, 6.28), timer: rng.range(0.5, 2)))
        }
        critters.append(Critter(kind: 2, x: rng.range(40, Double(config.width - 40)),
                                y: Double(floorY) - 5, vx: 0,
                                phase: rng.range(0, 6.28), timer: rng.range(3, 10)))
    }

    private mutating func updateCritters(_ dt: Double) {
        for i in 0..<critters.count {
            critters[i].phase += dt
            critters[i].timer -= dt
            if critters[i].kind == 0 {
                // Snail: slow crawl, pausing now and then.
                if critters[i].timer <= 0 {
                    critters[i].timer = rng.range(3, 9)
                    critters[i].vx = rng.unit() < 0.4 ? 0 : rng.range(0.7, 1.6) * (rng.unit() < 0.5 ? -1 : 1)
                }
                critters[i].x += critters[i].vx * dt
                critters[i].y = Double(floorY) - 3
            } else if critters[i].kind == 2 {
                // Starfish: sits still, occasionally creeps an inch.
                if critters[i].timer <= 0 {
                    critters[i].timer = rng.range(4, 12)
                    critters[i].vx = rng.range(-0.6, 0.6)
                }
                critters[i].x += critters[i].vx * dt
                critters[i].vx *= max(0, 1 - 2 * dt)
                critters[i].y = Double(floorY) - 5
            } else {
                // Shrimp: hop-scotches along the sand in little bursts.
                if critters[i].timer <= 0 {
                    critters[i].timer = rng.range(0.6, 2.2)
                    critters[i].vx = rng.range(-6, 6)
                }
                critters[i].x += critters[i].vx * dt
                critters[i].vx *= max(0, 1 - 3 * dt)
                let hop = abs(critters[i].vx) > 0.6 ? abs(sin(critters[i].phase * 4)) * 1.6 : 0
                critters[i].y = Double(floorY) - 2 - hop
            }
            let lo = 6.0
            let hi = Double(config.width) - 8
            if critters[i].x < lo { critters[i].x = lo; critters[i].vx = abs(critters[i].vx) }
            if critters[i].x > hi { critters[i].x = hi; critters[i].vx = -abs(critters[i].vx) }
        }
    }

    // MARK: - Decor

    /// Scatter static rocks and corals along the back of the tank.
    private mutating func decorate() {
        // Distant reef silhouettes for a sense of depth.
        var bx = Int(Double(config.width) * 0.1)
        while bx < config.width - 30 {
            let width = rng.int(12) + 6
            let height = rng.int(4) + 3
            backdrop.append(Spire(x: bx, width: width, height: height))
            bx += width + rng.int(55) + 28
        }
        // Rock formations.
        for frac in [0.16, 0.62, 0.9] {
            let x = Int(Double(config.width) * frac) + rng.int(7) - 3
            decor.append(Decor(kind: rng.unit() < 0.5 ? 0 : 1, variant: 0,
                               x: max(2, min(config.width - 10, x))))
        }
        // Coral formations (and the odd anemone).
        var x = 12
        while x < config.width - 12 {
            if rng.unit() < 0.7 {
                let kind = rng.unit() < 0.22 ? 5 : (2 + rng.int(3))
                decor.append(Decor(kind: kind,
                                   variant: rng.int(Art.coralPalette.count),
                                   x: x))
            }
            x += rng.int(26) + 32
        }
    }

    private mutating func plantGarden() {
        let maxH = floorY - 1
        var x = 6
        while x < config.width - 6 {
            if rng.unit() < 0.85 {
                // Occasionally a tall kelp strand.
                let h = rng.unit() < 0.3 ? rng.int(2) + 5 : rng.int(4) + 3
                plants.append(Plant(
                    x: x,
                    height: min(h, maxH),
                    phase: rng.range(0, 6.28)
                ))
                // Occasional companion blade a couple of px away for a bushier bed.
                if rng.unit() < 0.4, x + 2 < config.width - 6 {
                    plants.append(Plant(x: x + 2, height: min(rng.int(3) + 2, maxH), phase: rng.range(0, 6.28)))
                }
            }
            x += rng.int(7) + 7
        }
    }
}
