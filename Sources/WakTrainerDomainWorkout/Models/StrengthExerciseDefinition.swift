import WakTrainerCoreModels

public struct StrengthExerciseDefinition:
    Identifiable,
    Codable,
    Sendable,
    Equatable,
    Hashable {

    public let id: String
    public let name: String
    public let supportedEquipment:
        [StrengthEquipment]

    public init(
        id: String,
        name: String,
        supportedEquipment:
            [StrengthEquipment]
    ) {
        self.id = id
        self.name = name
        self.supportedEquipment =
            supportedEquipment
    }
}
