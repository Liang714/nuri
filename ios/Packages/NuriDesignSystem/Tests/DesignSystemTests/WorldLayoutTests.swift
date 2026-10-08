import CoreGraphics
import Testing
@testable import DesignSystem

@Suite struct WorldLayoutTests {
    @Test(arguments: FoodGroup.allCases)
    func slotCenterSitsInsideTheGlobe(group: FoodGroup) {
        let r = WorldLayout.slot(for: group)
        let dx = r.midX - 0.5, dy = r.midY - 0.5
        #expect((dx * dx + dy * dy).squareRoot() <= 0.5 * 0.82, "\(group)")
        #expect(r.width > 0 && r.height > 0)
    }

    @Test func placesBarelyOverlap() {
        let groups = FoodGroup.allCases
        for i in groups.indices {
            for j in groups.indices where j > i {
                let a = WorldLayout.slot(for: groups[i]), b = WorldLayout.slot(for: groups[j])
                let overlap = a.intersection(b)
                let area = overlap.isNull ? 0 : overlap.width * overlap.height
                let smaller = min(a.width * a.height, b.width * b.height)
                #expect(area <= smaller * 0.15, "\(groups[i]) vs \(groups[j])")
            }
        }
    }

    @Test func eachGroupHasItsOwnPlace() {
        let centers = Set(FoodGroup.allCases.map { "\(WorldLayout.slot(for: $0).midX)-\(WorldLayout.slot(for: $0).midY)" })
        #expect(centers.count == 6)
    }
}
