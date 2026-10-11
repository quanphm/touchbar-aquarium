import Foundation

/// Static knobs for the tank. Art-space units: 1 unit == 1 pixel of the small
/// canvas the renderer draws into (the host scales that up for the bar).
public struct TankConfig {
    /// The full tank width. The Touch Bar shows a ~360-wide window of it and
    /// pans across, so a wide tank holds many more fish without crowding.
    public var width: Int = 1080
    public var height: Int = 10
    public var floorHeight: Int = 2
    public var fishCount: Int = 7
    /// A few extra baby fish (fry). Kept small so the tank doesn't crowd.
    public var babyCount: Int = 3
    /// Population cap. Fry grow up and new fry are born, but the tank never
    /// exceeds this many fish, so it can't crowd.
    public var maxFish: Int = 20
    /// Seconds for a fry to mature into an adult (about an hour).
    public var fryGrowSeconds: Double = 3600
    /// Seconds between new fry being born (about two hours).
    public var fryBirthSeconds: Double = 7200
    /// Whether the tank includes its legendary resident. On by default.
    public var legendaryChance: Double = 1.0
    public var seed: UInt64 = 0xA9E1

    /// Day/night cycle. `dayLength` is real seconds per full 24h cycle.
    public var dayNightEnabled: Bool = true
    public var dayLength: Double = 600
    public var startHour: Double = 9
    /// When true, the clock follows real time instead of the fast `dayLength` cycle.
    public var realClock: Bool = false
    /// Environment palette (theme).
    public var palette: Palette = .freshwater

    /// Hidden per-fish satiety. Fullness drains at this rate (units/second),
    /// so a fish that has eaten grows hungry again after a while.
    /// With the default `fullThreshold`, a full fish ignores food for ~1 minute.
    public var satietyDecay: Double = 0.2 / 60.0
    /// A fish at or above this fullness ignores food until it digests.
    public var fullThreshold: Double = 0.8

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
    /// Hidden satiety tracker: 0 = starving, 1 = full. A full fish ignores
    /// food; it drains over time (`TankConfig.satietyDecay`) so it hungers
    /// again after a period.
    public var satiety: Double
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
    public var baby: Bool = false  // a small fry, drawn with a smaller sprite
    public var age: Double = 0      // seconds since spawned (drives fry growth)
    public var growAt: Double = 150 // age at which a fry becomes an adult
    public var bold: Double = 0.5   // 0 shy .. 1 bold (dart rate)
    public var pace: Double = 1.0   // personal speed multiplier
    /// Index of the fish this one is holding station for, or -1, plus the sim
    /// time the yield began. Right of way is granted once and held until that
    /// fish is genuinely past, rather than re-decided every tick — otherwise a
    /// yielding pair oscillates between holding back and charging back in.
    /// The start time is a safety valve: no fish may be parked indefinitely.
    public var wayFrom: Int = -1
    public var waySince: Double = 0

    /// One of the mermaid legendary residents (not the Kohaku koi). Mermaids
    /// don't feed — they drift and glow, and leave the food to the fish.
    public var isMermaid: Bool {
        guard isLegendary else { return false }
        let kinds = Art.legendaryKinds
        return kinds[((legendaryKind % kinds.count) + kinds.count) % kinds.count].shape == .mermaid
    }
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

/// A static background piece: a rock, coral, anemone, or sand castle.
public struct Decor {
    public var kind: Int      // 0 big rock, 1 small rock, 2 branch, 3 fan, 4 brain, 5 anemone, 6 sand castle
    public var variant: Int
    public var x: Int
}

/// A distant reef silhouette that gives the tank depth. `layer` 0 = far (drawn
/// darkest, behind everything), 1 = near.
public struct Spire {
    public var x: Int
    public var width: Int
    public var height: Int
    public var layer: Int = 1
}

/// A drifting, softly glowing mote of plankton — the tank's bioluminescence.
public struct Plankton {
    public var x: Double
    public var y: Double
    public var vx: Double
    public var vy: Double
    public var phase: Double
    public var hue: Int
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
    public private(set) var plankton: [Plankton] = []
    public private(set) var critters: [Critter] = []
    public private(set) var decor: [Decor] = []
    public private(set) var backdrop: [Spire] = []
    /// The columns bubbles rise from. The main column sits near the centre, with
    /// a few more spread across the tank.
    public private(set) var bubblers: [Int] = []
    public private(set) var time: Double = 0
    /// Current time of day, 0..24. Advances with the day/night cycle.
    public private(set) var clockHour: Double = 9
    /// 1.0 = full daylight, 0.0 = deep night. Drives the render tint and how
    /// lively the fish are.
    public var daylight: Double = 1.0

    /// Names of the tank's legendary residents (one of every kind).
    public var legendaryNames: [String] {
        legendaryIndices.compactMap { i in
            guard i < fish.count else { return nil }
            let kinds = Art.legendaryKinds
            let kind = fish[i].legendaryKind
            return kinds[((kind % kinds.count) + kinds.count) % kinds.count].name
        }
    }

    /// The first legendary resident's name, if any.
    public var legendaryName: String? { legendaryNames.first }

    private var rng: SeededRandom
    private var bubbleTimers: [Double] = []
    /// Counts down to the next fry being born.
    private var fryTimer: Double = 0
    private var fearTimer: Double = 0
    private var fearX: Double = 0
    private var legendaryIndices: [Int] = []
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
        // Evenly spaced bubbling columns across the (wide) tank.
        let margin = 6
        let columns = 7
        self.bubblers = (0..<columns).map { i in
            let frac = (Double(i) + 0.5) / Double(columns)
            return max(margin, min(config.width - margin, Int(Double(config.width) * frac)))
        }
        self.clockHour = config.startHour
        self.daylight = AquariumSim.computeDaylight(config.startHour)
        scatterFish()
        if rng.unit() < config.legendaryChance { addLegendary() }
        plantGarden()
        decorate()
        seedCritters()
        seedBubbles()
        seedPlankton()
        fryTimer = config.fryBirthSeconds * rng.range(0.92, 1.08)
    }

    // MARK: - Public interface

    /// Advance the world by `dt` seconds. Safe to call with any non-negative dt.
    public mutating func tick(dt: Double) {
        let dt = max(0, min(dt, 0.1))
        guard dt > 0 else { return }
        time += dt

        if config.dayNightEnabled {
            if config.realClock {
                clockHour = (clockHour + dt / 3600.0).truncatingRemainder(dividingBy: 24)
            } else {
                clockHour += dt * 24.0 / max(1, config.dayLength)
                clockHour = clockHour.truncatingRemainder(dividingBy: 24)
            }
            daylight = AquariumSim.computeDaylight(clockHour)
        }

        updatePellets(dt)
        updateFish(dt)
        updateCritters(dt)
        updateSparkles(dt)
        updateBubbles(dt)
        updatePlankton(dt)
        updateFry(dt)

        if fearTimer > 0 { fearTimer = max(0, fearTimer - dt) }
    }

    /// Re-skin the environment (theme).
    public mutating func setPalette(_ palette: Palette) {
        config.palette = palette
    }

    /// Point the clock at a specific time of day and choose how it advances.
    public mutating func setClock(hour: Double, realClock: Bool) {
        clockHour = hour.truncatingRemainder(dividingBy: 24)
        config.realClock = realClock
        daylight = AquariumSim.computeDaylight(clockHour)
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
            let pace = rng.range(0.85, 1.15)
            fish.append(Fish(
                x: x, y: y,
                vx: isJelly ? rng.range(-1.4, 1.4) : dir * rng.range(2, 4),
                vy: 0,
                species: speciesIndex,
                facing: dir < 0 ? -1 : 1,
                phase: rng.range(0, 6.28),
                speed: rng.range(4.2, 7.2) * style.speedScale * pace,
                satiety: rng.range(0.2, 0.7),
                homeY: homeY,
                homeX: homeX,
                radius: Double(Art.fishSprite(speciesIndex).width) * 0.5,
                tx: x, ty: y, retarget: 0,
                bold: rng.range(0.2, 0.9),
                pace: pace
            ))
            let idx = fish.count - 1
            if isJelly {
                fish[idx].pulse = rng.range(0.5, 2.0)
            } else {
                requestTarget(idx)
            }
        }

        // A few baby fish (fry). They use a smaller sprite and drift within their
        // own patch, so the tank reads as a family without crowding.
        for _ in 0..<max(0, config.babyCount) {
            guard !Art.schoolerPool.isEmpty else { break }
            let speciesIndex = Art.schoolerPool[rng.int(Art.schoolerPool.count)]
            let style = Art.species[speciesIndex]
            let homeY = minY + (maxY - minY) * style.depth
            let homeX = rng.range(minX + 20, maxX - 20)
            let x = rng.range(Double(minX + 6), Double(maxX - 6))
            let y = min(maxY - 1, max(minY + 1, homeY + rng.range(-0.8, 0.8)))
            let dir = rng.unit() < 0.5 ? -1.0 : 1.0
            fish.append(Fish(
                x: x, y: y,
                vx: dir * rng.range(1.5, 3.0),
                vy: 0,
                species: speciesIndex,
                facing: dir < 0 ? -1 : 1,
                phase: rng.range(0, 6.28),
                speed: rng.range(3.4, 5.4) * style.speedScale,
                satiety: rng.range(0.2, 0.7),
                homeY: homeY,
                homeX: homeX,
                radius: Double(Art.frySprite(speciesIndex).width) * 0.5,
                tx: x, ty: y, retarget: 0,
                baby: true,
                growAt: config.fryGrowSeconds * rng.range(0.92, 1.08),
                bold: rng.range(0.3, 0.8),
                pace: rng.range(0.9, 1.1)
            ))
            requestTarget(fish.count - 1)
        }
    }

    /// Add the tank's legendary residents — one of every kind, together.
    private mutating func addLegendary() {
        for (kind, style) in Art.legendaryKinds.enumerated() {
            // The mermaid glides a bit quicker than the grand old koi.
            let speed: Double = style.shape == .mermaid ? 6.2 : 4.2
            // Each legendary gets its own depth band. Sharing the mid-depth
            // line meant the three of them crossed paths at the same height
            // and met head-on far more often than they should.
            let t = Double(kind) / Double(max(1, Art.legendaryKinds.count - 1))
            let homeY = minY + (maxY - minY) * (0.25 + 0.5 * t)
            let x = rng.range(Double(minX + 20), Double(maxX - 40))
            let homeX = rng.range(minX + 50, maxX - 50)
            fish.append(Fish(
                x: x, y: homeY,
                vx: 2, vy: 0,
                species: 0,
                facing: 1,
                phase: rng.range(0, 6.28),
                speed: speed,
                satiety: 0.5,
                homeY: homeY,
                homeX: homeX,
                radius: Double(Art.legendarySprite(kind).width) * 0.5,
                tx: x, ty: homeY, retarget: 0,
                isLegendary: true,
                legendaryKind: kind,
                bold: 0.3,
                pace: 0.9
            ))
            legendaryIndices.append(fish.count - 1)
            requestTarget(fish.count - 1)
        }
    }

    /// Choose a fresh destination for fish `i`, within its depth band and far
    /// enough away to be a real journey. Candidates are scored by how far they
    /// sit from the other fish, which keeps the school spread out over time.
    private mutating func requestTarget(_ i: Int) {
        let band = 1.8
        let tyLo = max(minY + 0.5, fish[i].homeY - band)
        let tyHi = min(maxY - 0.5, fish[i].homeY + band)
        // Roam within a home region so fish stay spread out — but the legendary
        // resident wanders the whole tank.
        let loX: Double
        let hiX: Double
        if fish[i].isLegendary {
            loX = minX + 8
            hiX = maxX - 8
        } else {
            loX = max(minX + 8, fish[i].homeX - 70)
            hiX = min(maxX - 8, fish[i].homeX + 70)
        }

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

    /// A unit direction to push one fish away from another.
    ///
    /// Pushing straight down the line between them is exactly wrong for a
    /// head-on meeting: both fish are already driving along that line, so the
    /// push cancels their forward motion and they grind in place forever.
    /// This tank has ~5px of usable depth against a minimum separation wider
    /// than that, so there is no room to slide out of the way by shoving.
    /// When the pair is closing, the push is rotated towards perpendicular to
    /// the relative motion so they step aside and get past each other.
    ///
    /// The perpendicular keeps the sign that agrees with the current offset,
    /// so a pair splits to opposite sides instead of both flipping across at
    /// once and staying stuck together. Since the water column is barely
    /// taller than a fish, that sideways lane is often blocked by the surface
    /// or the sand — in which case we take the other side, and if both are
    /// blocked we fall back to separating head-on rather than shoving into a
    /// wall and pinning the pair there.
    private static func passVector(dx: Double, dy: Double,
                                   rvx: Double, rvy: Double,
                                   y: Double,
                                   yLo: Double, yHi: Double) -> (x: Double, y: Double) {
        let d = (dx * dx + dy * dy).squareRoot()
        guard d > 0.0001 else { return (1, 0) }
        let ux = dx / d
        let uy = dy / d
        let rvLen = (rvx * rvx + rvy * rvy).squareRoot()
        guard rvLen > 0.001 else { return (ux, uy) }
        // Positive while the two are closing on each other.
        let closing = -(rvx * ux + rvy * uy)
        guard closing > 0 else { return (ux, uy) }
        var px = -rvy / rvLen
        var py = rvx / rvLen
        if px * ux + py * uy < 0 { px = -px; py = -py }

        // The water column is only ~5px tall, far less than the separation
        // distance these fish need — so a sideways lane is a brief nudge, not
        // somewhere to actually fit. Probe with a step that size; asking
        // whether the fish could travel the full separation distance sideways
        // always fails here and would silently drop us back to head-on shoving.
        let nudge = 1.2
        func fitsVertically() -> Bool {
            let next = y + py * nudge
            return next >= yLo && next <= yHi
        }
        // Only swing fully sideways once they are genuinely head-on; a
        // glancing pass still separates normally.
        var headOn = min(1.0, max(0.0, (closing - 0.25) / 1.0))
        if !fitsVertically() {
            px = -px
            py = -py
            if !fitsVertically() { headOn = 0 }
        }
        var nx = ux + (px - ux) * headOn
        var ny = uy + (py - uy) * headOn
        let nl = (nx * nx + ny * ny).squareRoot()
        guard nl > 0.0001 else { return (ux, uy) }
        return (nx / nl, ny / nl)
    }

    /// The neighbour this fish must give way to, if it is closing head-on with
    /// one.
    ///
    /// Separation steering alone cannot resolve a head-on meeting in a tank
    /// this short, so exactly one of the pair brakes. The rule is antisymmetric
    /// — right of way goes to the quicker fish, with the lower index winning a
    /// tie — so both fish reach the same verdict independently without having
    /// to coordinate.
    private func headOnConflict(_ i: Int) -> Int? {
        for j in 0..<fish.count where j != i {
            guard Art.species[fish[j].species].shape != .jelly else { continue }
            let dx = fish[i].x - fish[j].x
            let dy = fish[i].y - fish[j].y
            let d2 = dx * dx + dy * dy
            let reach = (fish[i].radius + fish[j].radius) * 2.2
            guard d2 > 0.0001, d2 < reach * reach else { continue }
            let d = d2.squareRoot()
            let rvx = fish[i].vx - fish[j].vx
            let rvy = fish[i].vy - fish[j].vy
            let rvLen = (rvx * rvx + rvy * rvy).squareRoot()
            guard rvLen > 0.5 else { continue }
            let along = -(rvx * dx + rvy * dy)
            // cosApproach: -1 means closing straight down the line between us,
            // +1 means already pulling apart.
            guard along / (rvLen * d) > 0.7, along / d > 0.8 else { continue }
            let iHasWay = fish[i].speed != fish[j].speed
                ? fish[i].speed > fish[j].speed
                : i < j
            return iHasWay ? nil : j
        }
        return nil
    }

    private mutating func updateFish(_ dt: Double) {
        let n = fish.count
        guard n > 0 else { return }

        for i in 0..<n {
            fish[i].age += dt
            // Jellyfish drift and pulse rather than swim to destinations.
            if Art.species[fish[i].species].shape == .jelly {
                updateJelly(i, dt)
                continue
            }
            // Fry grow into adults — into a random fish species, not necessarily
            // the one they were born as.
            if fish[i].baby, fish[i].age >= fish[i].growAt {
                growUp(i)
            }
            let style = Art.species[fish[i].species]

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

            // Soft pull toward home keeps each fish in its own region (the
            // legendary resident roams free). Clamped: an unclamped spring has
            // a fixed point where it exactly cancels the seek force, and the
            // fish parks there until its retarget timer expires — it looks
            // wedged against a neighbour, but nothing is actually blocking it.
            if !fish[i].isLegendary {
                let homeDx = fish[i].homeX - fish[i].x
                dvx += max(-0.6, min(0.6, homeDx * 0.14))
            }

            // Fish are lively in daylight and languid at night.
            let energy = 0.4 + 0.6 * daylight
            dvx *= energy
            dvy *= energy

            // Light boid steering: schooling species shoal toward the centre and
            // heading of nearby schoolers. Kept gentle so they still roam.
            if Art.schools(fish[i].species) {
                var cx = 0.0, cy = 0.0, avx = 0.0, avy = 0.0, count = 0.0
                let r2 = 55.0 * 55.0
                for j in 0..<n where j != i {
                    guard Art.schools(fish[j].species) else { continue }
                    let dx = fish[j].x - fish[i].x
                    let dy = fish[j].y - fish[i].y
                    if dx * dx + dy * dy < r2 {
                        cx += fish[j].x; cy += fish[j].y
                        avx += fish[j].vx; avy += fish[j].vy
                        count += 1
                    }
                }
                if count > 0 {
                    dvx += ((cx / count) - fish[i].x) * 0.05
                    dvy += ((cy / count) - fish[i].y) * 0.05
                    dvx += ((avx / count) - fish[i].vx) * 0.08
                    dvy += ((avy / count) - fish[i].vy) * 0.08
                }
            }

            // Personalities: flitty species dart in short bursts; puffers
            // deflate on a timer (after being poked). Bold fish dart more.
            fish[i].puff = max(0, fish[i].puff - dt)
            if !fish[i].isLegendary {
                fish[i].burst = max(0, fish[i].burst - dt)
                if fish[i].burst == 0, rng.unit() < style.darts * (0.4 + fish[i].bold) * dt * 0.8 {
                    fish[i].burst = rng.range(0.35, 0.7)
                }
                if fish[i].burst > 0 {
                    dvx *= 1.9
                    dvy *= 1.9
                }
            }
            // Separation steering: anticipate neighbours and step aside when
            // closing, instead of only being pushed apart after overlapping.
            var sepX = 0.0, sepY = 0.0, sepW = 0.0
            let sepReach = 26.0
            for j in 0..<n where j != i {
                guard Art.species[fish[j].species].shape != .jelly else { continue }
                let ox = fish[i].x - fish[j].x
                let oy = fish[i].y - fish[j].y
                let d = (ox * ox + oy * oy).squareRoot()
                guard d < sepReach else { continue }
                let (px, py) = AquariumSim.passVector(
                    dx: ox, dy: oy,
                    rvx: fish[i].vx - fish[j].vx,
                    rvy: fish[i].vy - fish[j].vy,
                    y: fish[i].y, yLo: minY, yHi: maxY
                )
                let urgency = 1 - d / sepReach
                sepX += px * urgency
                sepY += py * urgency
                sepW += urgency
            }

            // Right of way. A head-on meeting can't be resolved by shoving in
            // a tank with ~5px of depth, so one fish holds station until the
            // other is through. Only the drive is braked — the separation
            // force still applies, so the yielding fish steps aside instead of
            // parking in the way.
            let giving = fish[i].wayFrom
            if giving >= 0 && giving < n {
                let dx = fish[i].x - fish[giving].x
                let clear = (fish[i].radius + fish[giving].radius) * 2.0
                // Resume once the other fish has drawn level and moved off, or
                // has simply gone far enough past. Without the receding test
                // a fish stays parked for as long as anything swims nearby.
                let receding = fish[giving].vx * dx > 0
                if abs(dx) > clear || receding || time - fish[i].waySince > 4.0 {
                    fish[i].wayFrom = -1
                }
            } else {
                fish[i].wayFrom = -1
            }
            if fish[i].wayFrom < 0, let blocker = headOnConflict(i) {
                fish[i].wayFrom = blocker
                fish[i].waySince = time
            }
            if fish[i].wayFrom >= 0 {
                dvx *= 0.2
                dvy *= 0.2
            }
            if sepW > 0.001 {
                // Weighted average of the neighbours' push directions, so one
                // close fish dominates rather than many distant ones summing.
                dvx += (sepX / sepW) * fish[i].speed * 0.6
                dvy += (sepY / sepW) * fish[i].speed * 0.6
            }

            // Only hungry fish chase food. A fish that is full ignores pellets
            // until its satiety has drained back below the threshold. Mermaids
            // never feed at all.
            if !fish[i].isMermaid, fish[i].satiety < config.fullThreshold,
               let target = nearestPellet(to: fish[i]) {
                let dx = target.x - fish[i].x
                let dy = target.y - fish[i].y
                let d = max(0.001, (dx * dx + dy * dy).squareRoot())
                let pull = 26 * (0.6 + 0.4 * (1 - fish[i].satiety))
                dvx += (dx / d) * pull
                dvy += (dy / d) * pull
                if d < 1.8 {
                    eatPellet(near: fish[i])
                    fish[i].satiety = 1.0
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
            // Fullness drains, so a full fish eventually gets hungry again.
            fish[i].satiety = max(0, fish[i].satiety - dt * config.satietyDecay)
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
                guard d2 < minD * minD else { continue }
                if d2 <= 0.0001 {
                    // Exactly coincident: any direction we pick from dx/dy is
                    // noise, and skipping here welded them together for good.
                    fish[i].x += 0.2
                    fish[j].x -= 0.2
                    continue
                }
                let d = d2.squareRoot()
                let overlap = (minD - d) * 0.5
                // Cap the per-tick correction: an uncapped push can move a fish
                // 100s of px/s and scramble the whole tank.
                let step = min(overlap, 0.35)
                // Same sideways-swing as the steering, so the fixup reinforces
                // the pass instead of cancelling it.
                let (ux, uy) = AquariumSim.passVector(
                    dx: dx, dy: dy,
                    rvx: fish[i].vx - fish[j].vx,
                    rvy: fish[i].vy - fish[j].vy,
                    y: (fish[i].y + fish[j].y) / 2, yLo: minY, yHi: maxY
                )
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
        if !legendaryIndices.isEmpty {
            sparkleTimer -= dt
            if sparkleTimer <= 0 {
                sparkleTimer = rng.range(0.25, 0.8)
                let li = legendaryIndices[rng.int(legendaryIndices.count)]
                if li < fish.count {
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
        // Each column emits on its own staggered timer, so the streams differ.
        bubbleTimers = bubblers.map { _ in rng.range(0, 1.0) }
        for bx in bubblers {
            for _ in 0..<4 {
                bubbles.append(Bubble(
                    x: Double(bx) + rng.range(-1, 1),
                    y: rng.range(Double(floorY) - 6, Double(floorY) - 1),
                    vy: -rng.range(4, 7),
                    phase: rng.range(0, 6.28),
                    big: rng.unit() < 0.25
                ))
            }
        }
    }

    private mutating func updateBubbles(_ dt: Double) {
        for i in bubblers.indices where i < bubbleTimers.count {
            bubbleTimers[i] -= dt
            if bubbleTimers[i] <= 0 {
                bubbleTimers[i] = rng.range(0.35, 0.9)
                bubbles.append(Bubble(
                    x: Double(bubblers[i]) + rng.range(-1, 1),
                    y: Double(floorY) - 1,
                    vy: -rng.range(4, 7),
                    phase: rng.range(0, 6.28),
                    big: rng.unit() < 0.22
                ))
            }
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

    // MARK: - Plankton

    private mutating func seedPlankton() {
        let count = max(12, config.width / 22)
        for _ in 0..<count {
            plankton.append(Plankton(
                x: rng.range(0, Double(config.width)),
                y: rng.range(1, Double(floorY) - 1),
                vx: rng.range(-1.6, 1.6),
                vy: rng.range(-0.8, 0.8),
                phase: rng.range(0, 6.28),
                hue: rng.int(Art.planktonColors.count)
            ))
        }
    }

    private mutating func updatePlankton(_ dt: Double) {
        let w = Double(config.width)
        for i in 0..<plankton.count {
            plankton[i].phase += dt * (1.0 + Double(plankton[i].hue % 3) * 0.35)
            plankton[i].x += plankton[i].vx * dt
            plankton[i].y += plankton[i].vy * dt
            if plankton[i].x < 0 { plankton[i].x += w }
            if plankton[i].x >= w { plankton[i].x -= w }
            if plankton[i].y < 1 { plankton[i].y = 1; plankton[i].vy = abs(plankton[i].vy) }
            if plankton[i].y > Double(floorY) - 1 {
                plankton[i].y = Double(floorY) - 1
                plankton[i].vy = -abs(plankton[i].vy)
            }
        }
    }

    // MARK: - Fry

    /// Birth a new fry now and then, up to the population cap.
    private mutating func updateFry(_ dt: Double) {
        fryTimer -= dt
        if fryTimer <= 0 {
            if fish.count < config.maxFish { spawnFry() }
            fryTimer = config.fryBirthSeconds * rng.range(0.92, 1.08)
        }
    }

    /// Mature a fry into a random adult fish (a new species, not its birth one).
    private mutating func growUp(_ i: Int) {
        fish[i].baby = false
        if !Art.schoolerPool.isEmpty {
            fish[i].species = Art.schoolerPool[rng.int(Art.schoolerPool.count)]
        }
        let s = Art.species[fish[i].species]
        fish[i].radius = Double(Art.fishSprite(fish[i].species).width) * 0.5
        fish[i].homeY = minY + (maxY - minY) * s.depth
        fish[i].speed = rng.range(4.2, 7.2) * s.speedScale * fish[i].pace
    }

    private mutating func spawnFry() {
        guard !Art.schoolerPool.isEmpty else { return }
        let speciesIndex = Art.schoolerPool[rng.int(Art.schoolerPool.count)]
        let style = Art.species[speciesIndex]
        let homeY = minY + (maxY - minY) * style.depth
        let homeX = rng.range(minX + 20, maxX - 20)
        let x = rng.range(Double(minX + 6), Double(maxX - 6))
        let y = min(maxY - 1, max(minY + 1, homeY + rng.range(-0.8, 0.8)))
        let dir = rng.unit() < 0.5 ? -1.0 : 1.0
        fish.append(Fish(
            x: x, y: y,
            vx: dir * rng.range(1.5, 3.0),
            vy: 0,
            species: speciesIndex,
            facing: dir < 0 ? -1 : 1,
            phase: rng.range(0, 6.28),
            speed: rng.range(3.4, 5.4) * style.speedScale,
            satiety: rng.range(0.2, 0.7),
            homeY: homeY,
            homeX: homeX,
            radius: Double(Art.frySprite(speciesIndex).width) * 0.5,
            tx: x, ty: y, retarget: 0,
            baby: true,
            growAt: config.fryGrowSeconds * rng.range(0.92, 1.08),
            bold: rng.range(0.3, 0.8),
            pace: rng.range(0.9, 1.1)
        ))
        requestTarget(fish.count - 1)
    }

    // MARK: - Cleanup crew

    private mutating func seedCritters() {
        // Anchor each critter on the sand by its sprite height.
        let snailY = Double(floorY) - Double(Art.critterSprite(0).height)
        let shrimpY = Double(floorY) - Double(Art.critterSprite(1).height)
        let starfishY = Double(floorY) - Double(Art.critterSprite(2).height)
        // One snail, two shrimp, one starfish.
        critters.append(Critter(kind: 0, x: rng.range(30, Double(config.width - 30)),
                                y: snailY, vx: rng.range(0.8, 1.8),
                                phase: 0, timer: rng.range(2, 6)))
        for _ in 0..<2 {
            critters.append(Critter(kind: 1, x: rng.range(30, Double(config.width - 30)),
                                    y: shrimpY, vx: 0,
                                    phase: rng.range(0, 6.28), timer: rng.range(0.5, 2)))
        }
        critters.append(Critter(kind: 2, x: rng.range(40, Double(config.width - 40)),
                                y: starfishY, vx: 0,
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
                critters[i].y = Double(floorY) - Double(Art.critterSprite(0).height)
            } else if critters[i].kind == 2 {
                // Starfish: sits still, occasionally creeps an inch.
                if critters[i].timer <= 0 {
                    critters[i].timer = rng.range(4, 12)
                    critters[i].vx = rng.range(-0.6, 0.6)
                }
                critters[i].x += critters[i].vx * dt
                critters[i].vx *= max(0, 1 - 2 * dt)
                critters[i].y = Double(floorY) - Double(Art.critterSprite(2).height)
            } else {
                // Shrimp: hop-scotches along the sand in little bursts.
                if critters[i].timer <= 0 {
                    critters[i].timer = rng.range(0.6, 2.2)
                    critters[i].vx = rng.range(-6, 6)
                }
                critters[i].x += critters[i].vx * dt
                critters[i].vx *= max(0, 1 - 3 * dt)
                let hop = abs(critters[i].vx) > 0.6 ? abs(sin(critters[i].phase * 4)) * 1.6 : 0
                critters[i].y = Double(floorY) - Double(Art.critterSprite(1).height) - hop
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
        // Far reef silhouettes — taller and sparser, drawn darkest for depth.
        var fx = Int(Double(config.width) * 0.03)
        while fx < config.width - 40 {
            let width = rng.int(22) + 12
            let height = rng.int(4) + 5
            backdrop.append(Spire(x: fx, width: width, height: height, layer: 0))
            fx += width + rng.int(70) + 40
        }
        // Near reef silhouettes.
        var bx = Int(Double(config.width) * 0.1)
        while bx < config.width - 30 {
            let width = rng.int(12) + 6
            let height = rng.int(4) + 3
            backdrop.append(Spire(x: bx, width: width, height: height, layer: 1))
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
            if rng.unit() < 0.45 {
                let kind = rng.unit() < 0.22 ? 5 : (2 + rng.int(3))
                decor.append(Decor(kind: kind,
                                   variant: rng.int(Art.coralPalette.count),
                                   x: x))
            }
            x += rng.int(50) + 35
        }
        // One or two sand castles on the sand.
        let castles = 1 + (rng.unit() < 0.5 ? 1 : 0)
        for _ in 0..<castles {
            let x = Int(rng.range(Double(config.width) * 0.15, Double(config.width) * 0.85))
            decor.append(Decor(kind: 6, variant: 0, x: max(2, min(config.width - 12, x))))
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
