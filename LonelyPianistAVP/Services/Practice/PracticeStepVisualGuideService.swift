import Foundation

struct PracticeStepVisualGuideService {
    func highlightedMIDINotes(for currentStep: PracticeStep?) -> Set<Int> {
        guard let currentStep else { return [] }
        return Set(currentStep.notes.map(\.midiNote))
    }
}
