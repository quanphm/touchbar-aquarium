import AppKit
import Foundation
import QuartzCore
import AquariumCore

/// Owns the one true simulation and drives it on a timer. Both the preview
/// window and the Touch Bar view render from the same controller, so they show
/// the same tank.
final class AquariumController {
    private(set) var sim: AquariumSim
    private let observers = NSHashTable<NSView>.weakObjects()
    private var timer: Timer?
    private var lastTime = CACurrentMediaTime()
    private let fps: Double = 20

    private var theme: Palette = .freshwater
    private var followClock = true

    init() {
        // A fresh tank every launch: randomise the seed so the layout, the fish,
        // and the legendary roll differ each time. The sim stays deterministic
        // for a given seed, so tests and PNG previews reproduce.
        sim = AquariumSim(config: AquariumController.makeConfig(palette: .freshwater, followClock: true))
    }

    /// Re-roll the whole tank (new layout, fish, legendary) with a fresh seed.
    func newTank() {
        sim = AquariumSim(config: AquariumController.makeConfig(palette: theme, followClock: followClock))
    }

    func setTheme(_ palette: Palette) {
        theme = palette
        sim.setPalette(palette)
    }

    /// Follow the Mac's real clock (true) or the fast day cycle (false).
    func setFollowClock(_ on: Bool) {
        followClock = on
        sim.setClock(hour: on ? AquariumController.currentHour() : sim.clockHour, realClock: on)
    }

    private static func makeConfig(palette: Palette, followClock: Bool) -> TankConfig {
        var cfg = TankConfig()
        cfg.seed = UInt64.random(in: 0..<UInt64.max)
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

    // MARK: - Interaction

    func feed(atArtX x: Double) { sim.feed(x: x) }

    @discardableResult
    func poke(atArtX x: Double) -> Int { sim.poke(x: x) }
}
