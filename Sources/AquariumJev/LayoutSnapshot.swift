import Foundation
import AquariumCore

/// A text-only description of a tank's static habitat — rocks, corals,
/// anemones, and the plant bed — plus the features code computes from it.
///
/// System One models accept text only (no images), so a candidate tank is
/// described numerically and structurally and Jev judges the composition from
/// that description. Fish, motion, and pixels are deliberately excluded: this
/// is a layout judgment, not a render.
public struct LayoutSnapshot: Codable, Equatable {
    /// One background piece, placed by horizontal position (0–100% of width).
    public struct Placement: Codable, Equatable {
        public var type: String     // rock_large, rock_small, branch_coral, fan_coral, brain_coral, anemone
        public var xPct: Double
        public var size: String?    // rocks: large / small
        public var color: String?   // corals: pink / orange / purple / teal

        public init(type: String, xPct: Double, size: String? = nil, color: String? = nil) {
            self.type = type
            self.xPct = xPct
            self.size = size
            self.color = color
        }

        enum CodingKeys: String, CodingKey {
            case type, size, color
            case xPct = "x_pct"
        }
    }

    /// Numbers computed in code so the model never has to do arithmetic.
    public struct Features: Codable, Equatable {
        public var rockCount: Int
        public var coralCount: Int
        public var anemoneCount: Int
        public var plantCount: Int
        public var plantCoveragePct: Double
        public var leftMassPct: Double
        public var rightMassPct: Double
        public var largestGapPx: Int
        public var tallestPlantFrac: Double

        public init(rockCount: Int, coralCount: Int, anemoneCount: Int, plantCount: Int,
                    plantCoveragePct: Double, leftMassPct: Double, rightMassPct: Double,
                    largestGapPx: Int, tallestPlantFrac: Double) {
            self.rockCount = rockCount
            self.coralCount = coralCount
            self.anemoneCount = anemoneCount
            self.plantCount = plantCount
            self.plantCoveragePct = plantCoveragePct
            self.leftMassPct = leftMassPct
            self.rightMassPct = rightMassPct
            self.largestGapPx = largestGapPx
            self.tallestPlantFrac = tallestPlantFrac
        }

        enum CodingKeys: String, CodingKey {
            case rockCount = "rock_count"
            case coralCount = "coral_count"
            case anemoneCount = "anemone_count"
            case plantCount = "plant_count"
            case plantCoveragePct = "plant_coverage_pct"
            case leftMassPct = "left_mass_pct"
            case rightMassPct = "right_mass_pct"
            case largestGapPx = "largest_gap_px"
            case tallestPlantFrac = "tallest_plant_frac"
        }
    }

    public var placements: [Placement]
    public var features: Features

    public init(placements: [Placement], features: Features) {
        self.placements = placements
        self.features = features
    }
}

public extension LayoutSnapshot {
    static let coralColors = ["pink", "orange", "purple", "teal"]

    static func coralColor(_ variant: Int) -> String {
        let i = ((variant % coralColors.count) + coralColors.count) % coralColors.count
        return coralColors[i]
    }

    /// Snapshot the habitat that `sim` generated. Cheap and pure.
    static func extract(from sim: AquariumSim) -> LayoutSnapshot {
        let width = max(1, sim.config.width)
        let w = Double(width)

        var placements: [Placement] = []
        var rocks = 0, corals = 0, anemones = 0
        var occupied = [Bool](repeating: false, count: width)

        for d in sim.decor {
            let x = max(0, min(width - 1, d.x))
            occupied[x] = true
            let xp = Double(x) / w * 100
            switch d.kind {
            case 0: rocks += 1; placements.append(Placement(type: "rock_large", xPct: xp, size: "large"))
            case 1: rocks += 1; placements.append(Placement(type: "rock_small", xPct: xp, size: "small"))
            case 2: corals += 1; placements.append(Placement(type: "branch_coral", xPct: xp, color: coralColor(d.variant)))
            case 3: corals += 1; placements.append(Placement(type: "fan_coral", xPct: xp, color: coralColor(d.variant)))
            case 4: corals += 1; placements.append(Placement(type: "brain_coral", xPct: xp, color: coralColor(d.variant)))
            case 5: anemones += 1; placements.append(Placement(type: "anemone", xPct: xp, color: coralColor(d.variant)))
            case 6: placements.append(Placement(type: "sand_castle", xPct: xp))
            default: break
            }
        }

        var plantColumns = Set<Int>()
        var tallest = 0
        for p in sim.plants {
            let x = max(0, min(width - 1, p.x))
            occupied[x] = true
            plantColumns.insert(x)
            tallest = max(tallest, p.height)
        }

        let items = sim.decor.count + sim.plants.count
        let leftCount = sim.decor.filter { $0.x < width / 2 }.count
            + sim.plants.filter { $0.x < width / 2 }.count
        let leftMass = items == 0 ? 0 : Double(leftCount) / Double(items) * 100

        // The widest stretch of open water with no decor or plant column.
        var largestGap = 0, run = 0
        for i in 0..<width {
            if occupied[i] { run = 0 } else { run += 1; largestGap = max(largestGap, run) }
        }

        let features = Features(
            rockCount: rocks,
            coralCount: corals,
            anemoneCount: anemones,
            plantCount: sim.plants.count,
            plantCoveragePct: Double(plantColumns.count) / w * 100,
            leftMassPct: leftMass,
            rightMassPct: 100 - leftMass,
            largestGapPx: largestGap,
            tallestPlantFrac: sim.floorY <= 0 ? 0 : Double(tallest) / Double(sim.floorY)
        )
        return LayoutSnapshot(placements: placements, features: features)
    }
}
