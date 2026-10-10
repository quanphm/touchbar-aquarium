import Foundation

/// Deterministic, seedable PRNG (SplitMix64). Keeps the simulation reproducible
/// so tests can assert exact behavior and the art never re-rolls on every launch.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func nextUInt() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1).
    mutating func unit() -> Double {
        Double(nextUInt() >> 11) / Double(1 << 53)
    }

    mutating func range(_ a: Double, _ b: Double) -> Double {
        a + (b - a) * unit()
    }

    mutating func int(_ n: Int) -> Int {
        n <= 0 ? 0 : Int(nextUInt() % UInt64(n))
    }
}
