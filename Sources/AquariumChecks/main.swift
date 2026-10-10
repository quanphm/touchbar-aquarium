import Foundation
import AquariumCore

// A tiny test runner proving the deep module's contract through its interface.
// These are the same checks you'd write in XCTest; they just run on Command
// Line Tools alone (no Xcode).

var checks = 0
var failures = 0

func check(_ name: String, _ condition: Bool, _ detail: @autoclosure () -> String = "") {
    checks += 1
    if condition {
        print("  ok    \(name)")
    } else {
        failures += 1
        let d = detail()
        print("  FAIL  \(name)\(d.isEmpty ? "" : "  — \(d)")")
    }
}

func run(_ sim: inout AquariumSim, seconds: Double, dt: Double = 1.0 / 60.0) {
    var t = 0.0
    while t < seconds {
        sim.tick(dt: dt)
        t += dt
    }
}

print("AquariumCore checks")

// Fish count is stable over time.
do {
    var sim = AquariumSim()
    let n = sim.fish.count
    run(&sim, seconds: 30)
    check("fish count stable over 30s", sim.fish.count == n, "expected \(n), got \(sim.fish.count)")
}

// Fish never leave the tank bounds.
do {
    var sim = AquariumSim()
    run(&sim, seconds: 60)
    let inside = sim.fish.allSatisfy {
        $0.x >= 0 && $0.x <= Double(sim.config.width) && $0.y >= 0 && $0.y <= Double(sim.config.height)
    }
    check("fish stay inside the tank", inside)
}

// Same seed => identical world (determinism).
do {
    var a = AquariumSim()
    var b = AquariumSim()
    run(&a, seconds: 12)
    run(&b, seconds: 12)
    let same = zip(a.fish, b.fish).allSatisfy { abs($0.x - $1.x) < 1e-9 && abs($0.y - $1.y) < 1e-9 }
    check("deterministic for a fixed seed", same)
}

// Feeding registers food, and it does not linger forever.
do {
    var sim = AquariumSim()
    sim.feed(x: Double(sim.config.width) / 2)
    check("feed() adds a pellet", sim.pellets.count == 1, "got \(sim.pellets.count)")
    run(&sim, seconds: 25)
    check("pellet is consumed or expires", sim.pellets.isEmpty, "\(sim.pellets.count) left")
}

// Poking scatters fish without breaking the world.
do {
    var sim = AquariumSim()
    let n = sim.fish.count
    sim.poke(x: Double(sim.config.width) / 2)
    run(&sim, seconds: 0.3)
    check("poke keeps fish count intact", sim.fish.count == n)
}

// Bounds hold even in a cramped tank.
do {
    var config = TankConfig()
    config.width = 60
    config.height = 8
    config.fishCount = 3
    var sim = AquariumSim(config: config)
    run(&sim, seconds: 20)
    let inside = sim.fish.allSatisfy { $0.x >= 0 && $0.x <= Double(config.width) }
    check("tiny tank keeps fish in bounds", inside)
}

// Regression: fish must roam, not jitter against a wall. A corner-stuck fish
// flips its velocity sign almost every tick; a healthy one flips rarely.
do {
    var sim = AquariumSim()
    let dt = 1.0 / 60.0
    let n = sim.fish.count
    var lastSign = [Int](repeating: 0, count: n)
    var flips = [Int](repeating: 0, count: n)
    var lo = [Double](repeating: .greatestFiniteMagnitude, count: n)
    var hi = [Double](repeating: -.greatestFiniteMagnitude, count: n)

    var t = 0.0
    while t < 40 {
        sim.tick(dt: dt)
        for (i, f) in sim.fish.enumerated() {
            let sign = f.vx > 0.5 ? 1 : (f.vx < -0.5 ? -1 : lastSign[i])
            if sign != 0, lastSign[i] != 0, sign != lastSign[i] { flips[i] += 1 }
            lastSign[i] = sign
            lo[i] = min(lo[i], f.x)
            hi[i] = max(hi[i], f.x)
        }
        t += dt
    }

    let worstFlips = flips.max() ?? 0
    check("no fish jitters against the wall", worstFlips < 80, "max velocity sign flips: \(worstFlips)")

    let ranges = zip(lo, hi).map { Int($1 - $0) }
    print("        travel ranges (px): \(ranges)")
    // Exclude the legendary (glides slowly) and jellyfish (drift) from the
    // "must roam" check.
    let normalRanges = zip(ranges, sim.fish).filter {
        !$0.1.isLegendary && Art.species[$0.1.species].shape != .jelly
    }.map { $0.0 }
    let smallestRange = Double(normalRanges.min() ?? 0)
    check("every fish roams well", smallestRange > 20, "smallest horizontal range: \(Int(smallestRange))px")
}

// Legendary resident: always present by default, and deterministic for a seed.
do {
    var off = TankConfig(); off.legendaryChance = 0
    var none = AquariumSim(config: off)
    run(&none, seconds: 5)
    check("legendary can be disabled", none.legendaryName == nil)

    var has = AquariumSim()
    check("legendary present by default", has.legendaryName != nil, "name: \(has.legendaryName ?? "nil")")
    check("legendary adds one fish", has.fish.count == has.config.fishCount + 1)
    run(&has, seconds: 30)
    let inside = has.fish.allSatisfy { $0.x >= 0 && $0.x <= Double(has.config.width) }
    check("legendary stays in bounds", inside)
}

print("\n\(checks - failures)/\(checks) checks passed")
if failures > 0 {
    FileHandle.standardError.write(Data("\(failures) check(s) failed\n".utf8))
    exit(1)
}
