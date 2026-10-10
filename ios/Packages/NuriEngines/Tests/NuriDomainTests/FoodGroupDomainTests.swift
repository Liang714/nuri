import Foundation
import Testing
@testable import NuriDomain

@Suite struct FoodGroupDomainTests {
    @Test func sixGroups() { #expect(FoodGroup.allCases.count == 6) }

    @Test func rawValuesAreExactlyThePersistedOnes() {
        // Persisted values must never change.
        #expect(FoodGroup.allCases.map(\.rawValue)
                == ["vegetables", "fruit", "grains", "protein", "legumesAndNuts", "dairyAndAlternatives"])
    }

    @Test func sourceRawValuesAreExactlyThePersistedOnes() {
        #expect(FoodSource.allCases.map(\.rawValue)
                == ["verified", "manufacturer", "community", "userCreated", "photoEstimate"])
    }

    @Test func groupsRoundTripThroughCodable() throws {
        for group in FoodGroup.allCases {
            let data = try JSONEncoder().encode(group)
            #expect(try JSONDecoder().decode(FoodGroup.self, from: data) == group)
        }
    }
}
