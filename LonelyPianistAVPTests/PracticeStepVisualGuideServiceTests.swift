@testable import LonelyPianistAVP
import Testing

@Test
func visualGuideServiceUsesCurrentStepNotes() {
    let service = PracticeStepVisualGuideService()
    let step = PracticeStep(tick: 0, notes: [
        PracticeStepNote(midiNote: 60, staff: nil),
        PracticeStepNote(midiNote: 64, staff: nil),
        PracticeStepNote(midiNote: 60, staff: nil),
    ])

    #expect(service.highlightedMIDINotes(for: step) == [60, 64])
}

@Test
func visualGuideServiceReturnsEmptyForNilStep() {
    let service = PracticeStepVisualGuideService()

    #expect(service.highlightedMIDINotes(for: nil).isEmpty)
}
