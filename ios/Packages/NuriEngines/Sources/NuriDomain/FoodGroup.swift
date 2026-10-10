/// The six food groups that make up a person's world. Raw values are persisted and must never change.
public enum FoodGroup: String, CaseIterable, Codable, Sendable {
    case vegetables, fruit, grains, protein, legumesAndNuts, dairyAndAlternatives
}
