import Foundation
import AquariumCore
import AquariumJev

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

// Hidden satiety tracker: feeding fills it, and a full fish ignores food.
// (Decay is disabled here so the check isolates the "full" gate.)
do {
    var cfg = TankConfig()
    cfg.satietyDecay = 0
    var sim = AquariumSim(config: cfg)
    let isHunter: (Fish) -> Bool = { !$0.isMermaid && Art.species[$0.species].shape != .jelly }
    var rounds = 0
    while sim.fish.contains(where: { isHunter($0) && $0.satiety < cfg.fullThreshold }), rounds < 60 {
        for f in sim.fish where isHunter(f) && f.satiety < cfg.fullThreshold {
            sim.feed(x: f.x)
        }
        run(&sim, seconds: 1.5)
        rounds += 1
    }
    let full = sim.fish.filter { isHunter($0) && $0.satiety >= cfg.fullThreshold }.count
    let hunters = sim.fish.filter(isHunter).count
    check("feeding fills each fish's satiety", full == hunters, "\(full)/\(hunters) full")

    // Everyone full -> a fresh pellet sits untouched.
    let before = sim.pellets.count
    sim.feed(x: Double(sim.config.width) / 2)
    run(&sim, seconds: 3)
    check("a full fish won't chase food", sim.pellets.count >= before + 1,
          "pellet eaten while full (\(before) -> \(sim.pellets.count))")
}

// The tracker resets over time: a full fish grows hungry again.
do {
    var sim = AquariumSim()
    let isHunter: (Fish) -> Bool = { !$0.isMermaid && Art.species[$0.species].shape != .jelly }
    var rounds = 0
    while sim.fish.contains(where: { isHunter($0) && $0.satiety < sim.config.fullThreshold }), rounds < 60 {
        for f in sim.fish where isHunter(f) && f.satiety < sim.config.fullThreshold {
            sim.feed(x: f.x)
        }
        run(&sim, seconds: 1.5)
        rounds += 1
    }
    let peak = sim.fish.map { $0.satiety }.max() ?? 0
    run(&sim, seconds: 180)   // no more food; let fullness drain
    let now = sim.fish.map { $0.satiety }.max() ?? 0
    check("satiety drains so fish get hungry again", now < peak - 0.4,
          "fullness \(String(format: "%.2f", peak)) -> \(String(format: "%.2f", now))")
}

// Mermaids are decorative: they never chase or eat a pellet, while the Kohaku
// koi still feeds. Asserted on satiety rather than pellet counts, because any
// hungry fish in the tank will chase a pellet dropped anywhere.
do {
    var cfg = TankConfig()
    cfg.satietyDecay = 0
    var sim = AquariumSim(config: cfg)
    let mermaidKinds = sim.fish.filter(\.isMermaid).map(\.legendaryKind).sorted()
    let koiKind = sim.fish.first { $0.isLegendary && !$0.isMermaid }?.legendaryKind
    check("the tank has mermaids and a koi to test against",
          mermaidKinds.count == 2 && koiKind != nil,
          "\(mermaidKinds.count) mermaids, koi kind \(koiKind.map(String.init) ?? "nil")")

    let sat: (Int) -> Double = { kind in
        sim.fish.first { $0.legendaryKind == kind }?.satiety ?? -1
    }
    let feedOnto: (Int, Int) -> Void = { kind, rounds in
        for _ in 0..<rounds {
            guard let f = sim.fish.first(where: { $0.legendaryKind == kind }) else { return }
            if f.satiety >= cfg.fullThreshold { return }
            sim.feed(x: f.x)
            run(&sim, seconds: 1.5)
        }
    }

    if let kind = mermaidKinds.first {
        let before = sat(kind)
        feedOnto(kind, 40)
        check("a mermaid never eats",
              sat(kind) == before && before < cfg.fullThreshold,
              "satiety \(String(format: "%.2f", before)) -> \(String(format: "%.2f", sat(kind)))")
    }

    if let kind = koiKind {
        feedOnto(kind, 40)
        check("the Kohaku koi still feeds", sat(kind) >= cfg.fullThreshold,
              "satiety \(String(format: "%.2f", sat(kind)))")
    }
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
    check("all legendary kinds spawn together",
          Set(has.legendaryNames) == Set(Art.legendaryKinds.map { $0.name }),
          "\(has.legendaryNames)")
    check("legendary adds one fish each",
          has.fish.count == has.config.fishCount + Art.legendaryKinds.count + has.config.babyCount)
    run(&has, seconds: 30)
    let inside = has.fish.allSatisfy { $0.x >= 0 && $0.x <= Double(has.config.width) }
    check("legendary stays in bounds", inside)
}

// MARK: - Habitat layout judge

func makeScore(_ id: Int, _ total: Double) -> CandidateScore {
    CandidateScore(id: id, focalPoint: 0.5, balance: 0.5, openWater: 0.5,
                   themeCoherent: 0.5, plantUtility: 0.5, total: total)
}

// A layout snapshot is a pure function of the seed.
do {
    let a = LayoutSnapshot.extract(from: AquariumSim())
    let b = LayoutSnapshot.extract(from: AquariumSim())
    check("layout snapshot is deterministic for a seed", a == b)
    check("snapshot describes the habitat", !a.placements.isEmpty && a.features.plantCount > 0)
}

// Plant-bed utility peaks at "comfortable", not "overgrown".
do {
    let u = LayoutScorer.plantUtility(fromScore:)
    check("plant utility peaks at comfortable",
          u(1) > u(0) && u(1) > u(2) && u(1) > u(3))
    check("overgrown plants score worse than sparse", u(3) < u(0))
}

// Selection: highest total wins; ties and gaps resolve to the lowest id.
do {
    let scores = [makeScore(0, 0.4), makeScore(1, 0.9), makeScore(2, 0.7)]
    check("selection picks the highest total", LayoutSelection.bestIndex(scores, candidateCount: 3) == 1)
    check("selection defaults to 0 with no scores", LayoutSelection.bestIndex([], candidateCount: 3) == 0)
    let tie = [makeScore(0, 0.5), makeScore(1, 0.5)]
    check("ties resolve to the lowest id", LayoutSelection.bestIndex(tie, candidateCount: 2) == 0)
    let stray = [makeScore(9, 1.0)]
    check("out-of-range ids are ignored", LayoutSelection.bestIndex(stray, candidateCount: 2) == 0)
}

// The offline heuristic judge answers one score per candidate, within 0…1,
// and is deterministic.
do {
    let sims = (0..<4).map { k -> AquariumSim in
        var cfg = TankConfig(); cfg.seed = UInt64(k) + 1
        return AquariumSim(config: cfg)
    }
    let snaps = sims.map { LayoutSnapshot.extract(from: $0) }
    let context = TankContext(theme: "freshwater", fishCount: sims[0].fish.count, width: sims[0].config.width)
    let judge = HeuristicHabitatJudge()
    let a = judge.score(snaps, context: context)
    let b = judge.score(snaps, context: context)
    check("heuristic judge scores every candidate", a.count == snaps.count)
    check("heuristic totals stay in range", a.allSatisfy { $0.total >= 0 && $0.total <= 1 })
    check("heuristic judge is deterministic", a == b)
}

// The API key is read from the key file and trimmed; the env var overrides it.
do {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("jev-key-\(UUID().uuidString)")
    try? "  my-secret-key\n".write(to: tmp, atomically: true, encoding: .utf8)
    let fresh = { UserDefaults(suiteName: "jev-check-\(UUID().uuidString)")! }
    let fromFile = JevKey.load(environment: [:], keyFile: tmp, defaults: fresh())
    check("key file is read and trimmed", fromFile == "my-secret-key", "got \(fromFile ?? "nil")")
    let fromEnv = JevKey.load(environment: ["TYPESAFE_API_KEY": "env-key"], keyFile: tmp, defaults: fresh())
    check("env var overrides the key file", fromEnv == "env-key", "got \(fromEnv ?? "nil")")
    let missing = JevKey.load(environment: [:], keyFile: tmp.appendingPathExtension("nope"), defaults: fresh())
    check("missing key yields nil", missing == nil, "got \(missing ?? "nil")")
    try? FileManager.default.removeItem(at: tmp)
}

// Fallback: a judge that throws is replaced by the heuristic.
do {
    struct BrokenJudge: HabitatJudge {
        func rank(_ candidates: [LayoutSnapshot], context: TankContext) async throws -> [CandidateScore] {
            throw JevError.transport
        }
    }
    let sims = (0..<3).map { k -> AquariumSim in
        var cfg = TankConfig(); cfg.seed = UInt64(k) + 100
        return AquariumSim(config: cfg)
    }
    let snaps = sims.map { LayoutSnapshot.extract(from: $0) }
    let context = TankContext(theme: "freshwater", fishCount: sims[0].fish.count, width: sims[0].config.width)
    let judge = FallbackHabitatJudge(primary: BrokenJudge(), secondary: HeuristicHabitatJudge())
    let scores = (try? await judge.rank(snaps, context: context)) ?? []
    check("fallback judge recovers from a failure", scores.count == snaps.count)
}

// Optional live smoke test: `JEV_LIVE_TEST=1 swift run aquarium-checks`.
// Verifies the real request path; skipped by default so checks stay offline.
if ProcessInfo.processInfo.environment["JEV_LIVE_TEST"] == "1", let key = JevKey.load() {
    let sims = (0..<3).map { k -> AquariumSim in
        var cfg = TankConfig(); cfg.seed = UInt64(k) &+ 7
        return AquariumSim(config: cfg)
    }
    let snaps = sims.map { LayoutSnapshot.extract(from: $0) }
    let context = TankContext(theme: "freshwater", fishCount: sims[0].fish.count, width: sims[0].config.width)
    let judge = JevHabitatJudge(client: JevClient(config: JevConfig(apiKey: key)))
    do {
        let scores = try await judge.rank(snaps, context: context)
        let best = LayoutSelection.bestIndex(scores, candidateCount: snaps.count)
        print("        live Jev ranked \(scores.count) candidates; best #\(best)")
        for s in scores {
            print(String(format: "          #%d total %.2f  focal %.2f  balance %.2f  open %.2f  theme %.2f  plants %.2f",
                         s.id, s.total, s.focalPoint, s.balance, s.openWater, s.themeCoherent, s.plantUtility))
        }
        check("live Jev answered for every candidate", scores.count == snaps.count)
    } catch {
        check("live Jev request succeeded", false, "\(error)")
    }
} else {
    print("        (live Jev test skipped; set JEV_LIVE_TEST=1 to run)")
}

// Baby fish (fry): present, small, and keep the tank uncrowded.
do {
    var sim = AquariumSim()
    let babies = sim.fish.filter { $0.baby }
    check("tank includes baby fish", babies.count == sim.config.babyCount, "got \(babies.count)")
    let smaller = babies.allSatisfy { Art.frySprite($0.species).width < Art.fishSprite($0.species).width }
    check("babies use a smaller sprite", smaller)
    run(&sim, seconds: 30)
    check("babies stay in the tank", sim.fish.filter { $0.baby }.allSatisfy {
        $0.x >= 0 && $0.x <= Double(sim.config.width) && $0.y >= 0 && $0.y <= Double(sim.config.height)
    })
}

// Fry grow into adults and new fry are born, all under the population cap.
// (Real timings are ~1h grow / ~2h birth; compress them to keep this fast.)
do {
    var cfg = TankConfig()
    cfg.fryGrowSeconds = 8
    cfg.fryBirthSeconds = 12
    cfg.maxFish = cfg.fishCount + Art.legendaryKinds.count + cfg.babyCount + 3
    var sim = AquariumSim(config: cfg)
    let babies0 = sim.fish.filter { $0.baby }.count
    let startCount = sim.fish.count
    run(&sim, seconds: 60)
    let babies1 = sim.fish.filter { $0.baby }.count
    check("fry grow into adults", babies1 < babies0, "\(babies0) -> \(babies1)")
    check("new fry are born over time", sim.fish.count > startCount, "\(startCount) -> \(sim.fish.count)")
    check("population stays under the cap", sim.fish.count <= cfg.maxFish, "\(sim.fish.count)")
}

// Per-fish personalities vary.
do {
    let sim = AquariumSim()
    let paces = Set(sim.fish.map { Int(($0.pace * 100).rounded()) })
    let bolds = Set(sim.fish.map { Int(($0.bold * 100).rounded()) })
    check("fish have varied personalities", paces.count > 1 && bolds.count > 1,
          "\(paces.count) paces, \(bolds.count) bolds")
}

// New species, and only the Kohaku legendary remains.
do {
    let names = Set(Art.species.map { $0.name })
    check("betta and goldfish were added", names.contains("betta") && names.contains("goldfish"))
    check("legendary kinds are the koi and two mermaids",
          Art.legendaryKinds.map { $0.name } == ["Kohaku", "Rainbow Mermaid", "Purple Mermaid"])
    check("the mermaid uses its own art",
          Art.legendaryKinds[1].shape == .mermaid
              && Art.legendarySprite(1).height > Art.legendarySprite(0).height)
    check("new species are spawnable",
          Art.schoolerPool.contains(11) && Art.schoolerPool.contains(12))
}

// Bioluminescent plankton drift within the tank.
do {
    var sim = AquariumSim()
    check("tank has plankton", !sim.plankton.isEmpty, "\(sim.plankton.count)")
    run(&sim, seconds: 30)
    check("plankton stays in the tank", sim.plankton.allSatisfy {
        $0.x >= 0 && $0.x <= Double(sim.config.width) && $0.y >= 0 && $0.y <= Double(sim.config.height)
    })
}

// Regression: fish must be able to get past each other. A "wedged" fish is one
// sitting inside a neighbour's spacing radius while making no ground — the
// symptom of two fish shoving head-on forever. This tank is 10px of water
// against fish up to 18px long, so there is no room to slide out of the way
// and the deadlock is easy to fall into.
do {
    let dt = 1.0 / 60.0
    var sim = AquariumSim()
    var anchor = [Double](repeating: 0, count: sim.fish.count)
    var last = sim.fish.map { ($0.x, $0.y) }
    var stall = [Double](repeating: 0, count: sim.fish.count)
    var worstStall = 0.0
    var worstLegendStall = 0.0
    var worstWho = ""
    var t = 0.0
    while t < 240 {
        sim.tick(dt: dt)
        for i in 0..<sim.fish.count {
            if t - anchor[i] >= 1.0 {
                // Slide the measurement window forward, but never reset
                // `stall` here — a wedged fish would then read as 1s forever.
                anchor[i] = t
                last[i] = (sim.fish[i].x, sim.fish[i].y)
            }
            let moved = abs(sim.fish[i].x - last[i].0) + abs(sim.fish[i].y - last[i].1)
            var crowded = false
            for j in 0..<sim.fish.count where j != i {
                let dx = sim.fish[i].x - sim.fish[j].x
                let dy = sim.fish[i].y - sim.fish[j].y
                let minD = (sim.fish[i].radius + sim.fish[j].radius) * 1.15
                if dx * dx + dy * dy < minD * minD { crowded = true; break }
            }
            if crowded && moved < 0.75 {
                stall[i] += dt
                if stall[i] > worstStall {
                    worstStall = stall[i]
                    let f = sim.fish[i]
                    worstWho = f.isMermaid ? "mermaid" : (f.isLegendary ? "legendary" : "fish#\(i)/sp\(f.species)")
                }
                if sim.fish[i].isLegendary { worstLegendStall = max(worstLegendStall, stall[i]) }
            } else {
                stall[i] = 0
            }
        }
        t += dt
    }
    check("no fish gets wedged against a neighbour", worstStall < 3.0,
          "longest stuck run: \(String(format: "%.2f", worstStall))s (\(worstWho))")
    // The legendary residents roam the whole tank rather than holding a home
    // range, so they share the water with everything else and used to meet
    // head-on far more than any other pair — they are the canary for this.
    check("legendary residents never get stuck on each other", worstLegendStall < 3.0,
          "longest stuck run: \(String(format: "%.2f", worstLegendStall))s")
}

print("\n\(checks - failures)/\(checks) checks passed")
if failures > 0 {
    FileHandle.standardError.write(Data("\(failures) check(s) failed\n".utf8))
    exit(1)
}