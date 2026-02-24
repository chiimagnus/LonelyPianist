import Foundation

struct MappingProfilePayload: Codable, Hashable, Sendable {
    var velocityEnabled: Bool
    var defaultVelocityThreshold: Int
    var singleKeyRules: [SingleKeyMappingRule]
    var chordRules: [ChordMappingRule]
    var melodyRules: [MelodyMappingRule]

    static let empty = MappingProfilePayload(
        velocityEnabled: false,
        defaultVelocityThreshold: 90,
        singleKeyRules: [],
        chordRules: [],
        melodyRules: []
    )
}

struct MappingProfile: Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var isBuiltIn: Bool
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    var payload: MappingProfilePayload
}

extension MappingProfile {
    func noteOutput(for note: Int, velocity: Int) -> String? {
        guard let rule = payload.singleKeyRules.first(where: { $0.note == note }) else {
            return nil
        }

        guard payload.velocityEnabled else {
            return rule.normalOutput
        }

        let threshold = rule.velocityThreshold ?? payload.defaultVelocityThreshold
        if velocity >= threshold,
           let highOutput = rule.highVelocityOutput,
           !highOutput.isEmpty {
            return highOutput
        }

        return rule.normalOutput
    }
}
