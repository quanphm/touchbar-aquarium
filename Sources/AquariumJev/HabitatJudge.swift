import Foundation

/// Tank-level attributes every candidate shares. Kept alongside the per-candidate
/// layouts so questions can reference `tank.theme` and `tank.fish_count`.
public struct TankContext: Codable, Equatable {
    public var theme: String
    public var fishCount: Int
    public var width: Int

    public init(theme: String, fishCount: Int, width: Int) {
        self.theme = theme
        self.fishCount = fishCount
        self.width = width
    }

    enum CodingKeys: String, CodingKey {
        case theme, width
        case fishCount = "fish_count"
    }
}

/// One candidate's judged dimensions, all normalised to 0…1, plus the weighted
/// `total` code uses to pick a winner.
public struct CandidateScore: Equatable {
    public var id: Int
    public var focalPoint: Double
    public var balance: Double
    public var openWater: Double
    public var themeCoherent: Double
    public var plantUtility: Double
    public var total: Double

    public init(id: Int, focalPoint: Double, balance: Double, openWater: Double,
                themeCoherent: Double, plantUtility: Double, total: Double) {
        self.id = id
        self.focalPoint = focalPoint
        self.balance = balance
        self.openWater = openWater
        self.themeCoherent = themeCoherent
        self.plantUtility = plantUtility
        self.total = total
    }
}

/// Weights are ours to tune; changing one does not require re-asking the model.
public struct ScoreWeights: Equatable {
    public var focalPoint: Double
    public var balance: Double
    public var openWater: Double
    public var themeCoherent: Double
    public var plantUtility: Double

    public init(focalPoint: Double = 0.30, balance: Double = 0.25, openWater: Double = 0.30,
                themeCoherent: Double = 0.15, plantUtility: Double = 0.20) {
        self.focalPoint = focalPoint
        self.balance = balance
        self.openWater = openWater
        self.themeCoherent = themeCoherent
        self.plantUtility = plantUtility
    }

    public var sum: Double { focalPoint + balance + openWater + themeCoherent + plantUtility }
}

/// Combines independent judgments into one number. Pure and unit-testable.
public struct LayoutScorer: Equatable {
    public var weights: ScoreWeights

    public init(weights: ScoreWeights = ScoreWeights()) {
        self.weights = weights
    }

    public func total(focalPoint: Double, balance: Double, openWater: Double,
                      themeCoherent: Double, plantUtility: Double) -> Double {
        let w = weights
        let raw = w.focalPoint * focalPoint
            + w.balance * balance
            + w.openWater * openWater
            + w.themeCoherent * themeCoherent
            + w.plantUtility * plantUtility
        let s = w.sum
        return s <= 0 ? 0 : raw / s
    }

    /// Utility of a plant-bed density, where the Score levels are
    /// 0 = sparse, 1 = comfortable, 2 = lush, 3 = overgrown. Density is not
    /// monotonic "more is better": comfort peaks at level 1 and overgrowth penalised.
    public static func plantUtility(fromScore score: Double) -> Double {
        let levels: [Double] = [0.55, 1.0, 0.70, 0.15]
        let x = max(0, min(Double(levels.count - 1), score))
        let i = min(levels.count - 2, Int(x))
        let t = x - Double(i)
        return levels[i] * (1 - t) + levels[i + 1] * t
    }
}

/// A judge ranks candidate habitats. Async because the real one is a network
/// call; the vocabulary is small so tests can stub it.
public protocol HabitatJudge {
    func rank(_ candidates: [LayoutSnapshot], context: TankContext) async throws -> [CandidateScore]
}

/// Tries `primary` (Jev) and falls back to `secondary` (heuristics) on any
/// failure — missing key, offline, rate limit, or a malformed answer.
public struct FallbackHabitatJudge: HabitatJudge {
    public let primary: any HabitatJudge
    public let secondary: any HabitatJudge

    public init(primary: any HabitatJudge, secondary: any HabitatJudge) {
        self.primary = primary
        self.secondary = secondary
    }

    public func rank(_ candidates: [LayoutSnapshot], context: TankContext) async throws -> [CandidateScore] {
        do {
            return try await primary.rank(candidates, context: context)
        } catch {
            return try await secondary.rank(candidates, context: context)
        }
    }
}

/// The deterministic, offline baseline. Judges the same dimensions from the
/// code-computed features, so the tank always builds — and so there is a
/// reference to compare Jev against.
public struct HeuristicHabitatJudge: HabitatJudge {
    public var scorer: LayoutScorer

    public init(scorer: LayoutScorer = LayoutScorer()) {
        self.scorer = scorer
    }

    public func rank(_ candidates: [LayoutSnapshot], context: TankContext) async throws -> [CandidateScore] {
        score(candidates, context: context)
    }

    /// The synchronous core, so tests and previews need no async.
    public func score(_ candidates: [LayoutSnapshot], context: TankContext) -> [CandidateScore] {
        candidates.enumerated().map { (i, snap) in
            let f = snap.features
            let balance = 1 - min(1, abs(f.leftMassPct - f.rightMassPct) / 100)
            let coverOK = 1 - smoothstep(f.plantCoveragePct, 40, 80)
            let decorCount = Double(f.rockCount + f.coralCount + f.anemoneCount)
            let decorOK = 1 - min(1, decorCount / 14)
            let openWater = clamp(0.6 * coverOK + 0.4 * decorOK)
            let focalPoint = focalScore(snap)
            let themeCoherent = themeScore(snap, theme: context.theme)
            let plantUtility = LayoutScorer.plantUtility(fromScore: plantBedScore(f.plantCoveragePct))
            let total = scorer.total(focalPoint: focalPoint, balance: balance, openWater: openWater,
                                     themeCoherent: themeCoherent, plantUtility: plantUtility)
            return CandidateScore(id: i, focalPoint: focalPoint, balance: balance, openWater: openWater,
                                  themeCoherent: themeCoherent, plantUtility: plantUtility, total: total)
        }
    }

    private func focalScore(_ snap: LayoutSnapshot) -> Double {
        let hasLargeRock = snap.placements.contains { $0.type == "rock_large" }
        let centerOccupied = snap.placements.contains { $0.xPct >= 33 && $0.xPct <= 67 }
        return clamp((hasLargeRock ? 0.6 : 0.35) + (centerOccupied ? 0.4 : 0.0))
    }

    private func themeScore(_ snap: LayoutSnapshot, theme: String) -> Double {
        let f = snap.features
        if theme == "reef" {
            return clamp(0.4 + Double(f.coralCount + f.anemoneCount) / 8 * 0.6)
        }
        // Freshwater and deep sea: a planted bed with a few rocks reads right.
        return clamp(0.5 + Double(f.plantCount) / 30 * 0.3 + Double(f.rockCount) / 4 * 0.2)
    }

    /// Map plant coverage (%) onto the 0…3 density scale.
    private func plantBedScore(_ coverage: Double) -> Double {
        if coverage < 15 { return coverage / 15 }                 // 0 → sparse, 1 → comfortable
        if coverage < 40 { return 1 + (coverage - 15) / 25 }      // 1 → 2
        return 2 + min(1, (coverage - 40) / 30)                    // 2 → 3
    }

    private func smoothstep(_ x: Double, _ a: Double, _ b: Double) -> Double {
        guard b > a else { return x >= b ? 1 : 0 }
        let t = clamp((x - a) / (b - a))
        return t * t * (3 - 2 * t)
    }

    private func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
}

/// Pure selection so the "generate K → judge → keep the best" step is testable
/// without a network or a Controller. Ties resolve to the lowest id.
public enum LayoutSelection {
    public static func bestIndex(_ scores: [CandidateScore], candidateCount: Int) -> Int {
        guard candidateCount > 0 else { return 0 }
        var best = 0
        var bestTotal = -Double.greatestFiniteMagnitude
        for id in 0..<candidateCount {
            guard let s = scores.first(where: { $0.id == id }) else { continue }
            if s.total > bestTotal { bestTotal = s.total; best = id }
        }
        return best
    }
}
