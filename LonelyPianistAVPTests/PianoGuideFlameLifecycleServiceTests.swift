@testable import LonelyPianistAVP
import simd
import Testing

@Test
func lifecyclePlansFadeInForAddedNotes() {
    let service = PianoGuideFlameLifecycleService()
    let actions = service.transitionActions(activeStates: [:], descriptors: [descriptor(midiNote: 60, generation: 1)])

    #expect(actions == [.fadeIn(midiNote: 60)])
}

@Test
func lifecyclePlansFadeOutForRemovedNotes() {
    let service = PianoGuideFlameLifecycleService()
    let active = [60: PianoGuideFlameLifecycleState(midiNote: 60, stepOccurrenceGeneration: 1, isFadingOut: false)]

    let actions = service.transitionActions(activeStates: active, descriptors: [])

    #expect(actions == [.fadeOut(midiNote: 60)])
}

@Test
func lifecycleRetriggersSameMIDINoteForNewGeneration() {
    let service = PianoGuideFlameLifecycleService()
    let active = [60: PianoGuideFlameLifecycleState(midiNote: 60, stepOccurrenceGeneration: 1, isFadingOut: false)]

    let actions = service.transitionActions(activeStates: active, descriptors: [descriptor(midiNote: 60, generation: 2)])

    #expect(actions == [.retrigger(midiNote: 60)])
}

@Test
func lifecycleUpdatesSameMIDINoteForSameGeneration() {
    let service = PianoGuideFlameLifecycleService()
    let active = [60: PianoGuideFlameLifecycleState(midiNote: 60, stepOccurrenceGeneration: 1, isFadingOut: false)]

    let actions = service.transitionActions(activeStates: active, descriptors: [descriptor(midiNote: 60, generation: 1)])

    #expect(actions == [.update(midiNote: 60)])
}

@Test
func boostPlanIgnoresFadingOrAlreadyProcessedEvents() {
    let service = PianoGuideFlameLifecycleService()
    let event = PracticeCorrectStepFeedbackEvent(generation: 4, midiNotes: [60, 64])
    let active = [
        60: PianoGuideFlameLifecycleState(midiNote: 60, stepOccurrenceGeneration: 1, isFadingOut: false),
        64: PianoGuideFlameLifecycleState(midiNote: 64, stepOccurrenceGeneration: 1, isFadingOut: true),
    ]

    let first = service.boostPlan(event: event, activeStates: active, processedGeneration: nil)
    let second = service.boostPlan(event: event, activeStates: active, processedGeneration: first.processedGeneration)

    #expect(first.processedGeneration == 4)
    #expect(first.targetMIDINotes == [60])
    #expect(second.targetMIDINotes.isEmpty)
}

@Test
func clearPlanCancelsFadeAndBoostTasks() {
    let service = PianoGuideFlameLifecycleService()
    let plan = service.clearPlan(fadeTaskMIDINotes: [60], boostTaskMIDINotes: [64])

    #expect(plan.fadeTaskMIDINotesToCancel == [60])
    #expect(plan.boostTaskMIDINotesToCancel == [64])
    #expect(plan.shouldClearProcessedCorrectEventGeneration)
}

private func descriptor(midiNote: Int, generation: Int) -> PianoGuideFlameDescriptor {
    PianoGuideFlameDescriptor(
        midiNote: midiNote,
        velocity: 88,
        positionLocal: SIMD3<Float>(0, 0, 0),
        footprintSizeLocal: SIMD2<Float>(0.02, 0.04),
        surfaceLocalY: 0,
        stepOccurrenceGeneration: generation
    )
}
