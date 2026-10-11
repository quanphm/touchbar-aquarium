import Foundation

/// Ranks candidate habitats with Jev: one `POST /v1/systemone` carrying every
/// candidate, with the fuzzy composition questions asked in parallel and the
/// weighted pick done in code.
///
/// Code computes the measurable features (in `LayoutSnapshot`); Jev judges the
/// five dimensions below per candidate; `LayoutScorer` combines them.
public struct JevHabitatJudge: HabitatJudge {
    public let client: JevClient
    public var scorer: LayoutScorer

    public init(client: JevClient, scorer: LayoutScorer = LayoutScorer()) {
        self.client = client
        self.scorer = scorer
    }

    /// A live judge when a key is available, otherwise the offline heuristic.
    /// The live judge itself falls back on any request failure.
    public static func liveOrHeuristic() -> any HabitatJudge {
        guard let key = JevKey.load() else { return HeuristicHabitatJudge() }
        let client = JevClient(config: JevConfig(apiKey: key))
        return FallbackHabitatJudge(
            primary: JevHabitatJudge(client: client),
            secondary: HeuristicHabitatJudge()
        )
    }

    public func rank(_ candidates: [LayoutSnapshot], context: TankContext) async throws -> [CandidateScore] {
        let state = try JSONValue.encoding(StateBody(
            tank: TankState(theme: context.theme, fishCount: context.fishCount, width: context.width),
            candidates: candidates.enumerated().map { i, snap in
                CandidateState(id: i, features: snap.features, placements: snap.placements)
            }
        ))

        var questions: [String: JSONValue] = [:]
        for i in candidates.indices {
            let p = "candidates[\(i)]"
            questions["c\(i)_focal_point"] = JevQuestion.noul(
                "Does the habitat composition in `\(p)` have a clear focal point — one dominant feature such as a large rock or tall coral that anchors the eye?",
                yes: "A single feature clearly dominates the composition",
                no: "No feature stands out; the layout reads as flat or evenly scattered"
            )
            questions["c\(i)_balance"] = JevQuestion.noul(
                "Are the left and right halves of `\(p)` comparably occupied, so neither side looks empty or clumped together?"
            )
            questions["c\(i)_open_water"] = JevQuestion.noul(
                "Does `\(p)` leave enough open water for `tank.fish_count` fish to swim freely, without the decor or plant bed crowding the tank?"
            )
            questions["c\(i)_theme_coherent"] = JevQuestion.noul(
                "Do the decor types, coral colors, and plant density in `\(p)` suit a `tank.theme` aquarium?"
            )
            questions["c\(i)_plant_bed"] = JevQuestion.score(
                "How dense is the plant bed in `\(p)`?",
                levels: ["sparse", "comfortable", "lush", "overgrown"]
            )
        }

        let response = try await client.evaluate(state: state, questions: questions)

        return try candidates.indices.map { i in
            guard let focal = response.answers["c\(i)_focal_point"]?.noul,
                  let balance = response.answers["c\(i)_balance"]?.noul,
                  let openWater = response.answers["c\(i)_open_water"]?.noul,
                  let theme = response.answers["c\(i)_theme_coherent"]?.noul,
                  let plantScore = response.answers["c\(i)_plant_bed"]?.score
            else {
                throw JevError.decoding("missing answer for candidate \(i)")
            }
            let plantUtility = LayoutScorer.plantUtility(fromScore: plantScore)
            let total = scorer.total(focalPoint: focal, balance: balance, openWater: openWater,
                                     themeCoherent: theme, plantUtility: plantUtility)
            return CandidateScore(id: i, focalPoint: focal, balance: balance, openWater: openWater,
                                  themeCoherent: theme, plantUtility: plantUtility, total: total)
        }
    }
}

// MARK: - State shape

private struct TankState: Encodable {
    let theme: String
    let fishCount: Int
    let width: Int

    enum CodingKeys: String, CodingKey {
        case theme, width
        case fishCount = "fish_count"
    }
}

private struct CandidateState: Encodable {
    let id: Int
    let features: LayoutSnapshot.Features
    let placements: [LayoutSnapshot.Placement]
}

private struct StateBody: Encodable {
    let tank: TankState
    let candidates: [CandidateState]
}
