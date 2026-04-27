import Foundation
import simd

struct PianoGuideFlameDescriptor: Equatable, Identifiable {
    var id: Int { midiNote }

    let midiNote: Int
    let velocity: UInt8
    let positionLocal: SIMD3<Float>
    let footprintSizeLocal: SIMD2<Float>
    let surfaceLocalY: Float
    let stepOccurrenceGeneration: Int

    static func makeDescriptors(
        currentStep: PracticeStep?,
        keyboardGeometry: PianoKeyboardGeometry?,
        stepOccurrenceGeneration: Int
    ) -> [PianoGuideFlameDescriptor] {
        guard let currentStep, let keyboardGeometry else { return [] }

        var seenMIDINotes = Set<Int>()
        var descriptors: [PianoGuideFlameDescriptor] = []
        descriptors.reserveCapacity(currentStep.notes.count)

        for note in currentStep.notes {
            guard seenMIDINotes.insert(note.midiNote).inserted else { continue }
            guard let key = keyboardGeometry.key(for: note.midiNote) else { continue }
            let center = key.beamFootprintCenterLocal
            descriptors.append(PianoGuideFlameDescriptor(
                midiNote: note.midiNote,
                velocity: note.velocity,
                positionLocal: SIMD3<Float>(center.x, key.surfaceLocalY, center.z),
                footprintSizeLocal: key.beamFootprintSizeLocal,
                surfaceLocalY: key.surfaceLocalY,
                stepOccurrenceGeneration: stepOccurrenceGeneration
            ))
        }

        return descriptors.sorted { $0.midiNote < $1.midiNote }
    }
}
