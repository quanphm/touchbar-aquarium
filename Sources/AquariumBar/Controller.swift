import AppKit
import Foundation
import Dispatch
import QuartzCore
@preconcurrency import AquariumCore
@preconcurrency import AquariumJev

/// Owns the one true simulation and drives it on a timer. Both the preview
/// window and the Touch Bar view render from the same controller, so they show
/// the same tank.
final class AquariumController: @unchecked Sendable {
    private(set) var sim: AquariumSim
    private let observers = NSHashTable<NSView>.weakObjects()
    private var timer: Timer?
    private var lastTime = CACurrentMediaTime()
    private let fps: Double = 30

    /// Horizontal camera over the (wider) tank. The user scrolls it (Touch Bar
    /// drag, or the preview window's scroll wheel); it never moves on its own.
    private(set) var cameraX: Double = 0
    private let viewportArtWidth: Double = 360   // nominal visible width

    private var theme: Palette = .freshwater
    private var themeName: String = "freshwater"
    private var followClock = false

    /// Ranks candidate habitats for "New Tank" (Jev with a heuristic fallback).
    private let judge: any HabitatJudge
    /// Bumped on every New Tank so a slower, stale selection can't clobber a newer one.
    private var newTankGeneration = 0

    /// How many candidate tanks "New Tank" generates and lets the judge rank.
    static let candidateCount = 6

    /// Called on the main thread after the tank is swapped (the selection is async).
    var onTankChanged: (() -> Void)?

    init(judge: any HabitatJudge = JevHabitatJudge.liveOrHeuristic()) {
        self.judge = judge
        // A fresh tank every launch: randomise the seed so the layout, the fish,
        // and the legendary roll differ each time. The sim stays deterministic
        // for a given seed, so tests and PNG previews reproduce.
        sim = AquariumSim(config: AquariumController.makeConfig(palette: .freshwater, followClock: followClock, seed: nil))
    }

    /// Re-roll the tank, then keep the best of `candidateCount` layouts by the
    /// judge's ranking. The current tank stays visible until the pick completes.
    func newTank() {
        newTankGeneration += 1
        let generation = newTankGeneration

        let baseSeed = UInt64.random(in: 0..<UInt64.max)
        let candidates: [AquariumSim] = (0..<AquariumController.candidateCount).map { k in
            let seed = baseSeed &+ UInt64(k) &* 0x9E37_79B9_7F4A_7C15
            return AquariumSim(config: AquariumController.makeConfig(palette: theme, followClock: followClock, seed: seed))
        }
        let snapshots = candidates.map { LayoutSnapshot.extract(from: $0) }
        let first = candidates[0]
        let context = TankContext(theme: themeName, fishCount: first.fish.count, width: first.config.width)

        Task { [weak self] in
            guard let self else { return }
            let scores = (try? await self.judge.rank(snapshots, context: context)) ?? []
            let best = LayoutSelection.bestIndex(scores, candidateCount: candidates.count)
            DispatchQueue.main.async {
                guard generation == self.newTankGeneration else { return }
                self.sim = candidates[best]
                self.onTankChanged?()
            }
        }
    }

    func setTheme(_ palette: Palette, name: String) {
        theme = palette
        themeName = name
        sim.setPalette(palette)
    }

    /// Follow the Mac's real clock (true) or the fast day cycle (false).
    func setFollowClock(_ on: Bool) {
        followClock = on
        sim.setClock(hour: on ? AquariumController.currentHour() : sim.clockHour, realClock: on)
    }

    private static func makeConfig(palette: Palette, followClock: Bool, seed: UInt64?) -> TankConfig {
        var cfg = TankConfig()
        cfg.seed = seed ?? UInt64.random(in: 0..<UInt64.max)
        cfg.palette = palette
        cfg.realClock = followClock
        if followClock { cfg.startHour = currentHour() }
        return cfg
    }

    private static func currentHour() -> Double {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return Double(parts.hour ?? 9) + Double(parts.minute ?? 0) / 60.0
    }

    func addObserver(_ view: NSView) { observers.add(view) }

    func start() {
        guard timer == nil else { return }
        lastTime = CACurrentMediaTime()
        let t = Timer(timeInterval: 1.0 / fps, repeats: true) { [weak self] _ in self?.step() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func step() {
        let now = CACurrentMediaTime()
        let dt = min(now - lastTime, 0.1)
        lastTime = now
        sim.tick(dt: dt)
        for view in observers.allObjects where (view as? TankView)?.isOnScreen ?? true {
            view.setNeedsDisplay(view.bounds)
        }
    }

    // MARK: - Camera

    /// The art-space x the visible window starts at.
    var cameraOffset: Int { Int(cameraX.rounded()) }

    /// Scroll the camera by `dx` art pixels, clamped to the tank.
    func scrollCamera(by dx: Double) {
        let maxX = max(0, Double(sim.config.width) - viewportArtWidth)
        cameraX = max(0, min(maxX, cameraX + dx))
    }

    // MARK: - Interaction

    func feed(atArtX x: Double) { sim.feed(x: x) }

    @discardableResult
    func poke(atArtX x: Double) -> Int { sim.poke(x: x) }
}
