@testable import LonelyPianistAVP
import simd
import Testing

@Test
func flameDescriptorsAreEmptyWhenCurrentStepIsNil() {
    let result = PianoGuideFlameDescriptor.makeDescriptors(
        currentStep: nil,
        keyboardGeometry: makeGeometry(),
        stepOccurrenceGeneration: 7
    )

    #expect(result.isEmpty)
}

@Test
func flameDescriptorsAreEmptyWhenKeyboardGeometryIsNil() {
    let step = PracticeStep(tick: 0, notes: [PracticeStepNote(midiNote: 60, staff: nil)])
    let result = PianoGuideFlameDescriptor.makeDescriptors(
        currentStep: step,
        keyboardGeometry: nil,
        stepOccurrenceGeneration: 7
    )

    #expect(result.isEmpty)
}

@Test
func flameDescriptorUsesVelocityAndFootprint() {
    let step = PracticeStep(tick: 0, notes: [PracticeStepNote(midiNote: 60, staff: nil, velocity: 88)])
    let geometry = makeGeometry(footprintWidth: 0.04, footprintDepth: 0.06)

    let result = PianoGuideFlameDescriptor.makeDescriptors(
        currentStep: step,
        keyboardGeometry: geometry,
        stepOccurrenceGeneration: 3
    )

    #expect(result.count == 1)
    #expect(result.first?.midiNote == 60)
    #expect(result.first?.velocity == 88)
    #expect(result.first?.footprintSizeLocal == SIMD2<Float>(0.04, 0.06))
    #expect(result.first?.surfaceLocalY == 0)
    #expect(result.first?.stepOccurrenceGeneration == 3)
}

@Test
func flameDescriptorsDeduplicateSameMIDINote() {
    let step = PracticeStep(tick: 0, notes: [
        PracticeStepNote(midiNote: 60, staff: nil, velocity: 64),
        PracticeStepNote(midiNote: 60, staff: nil, velocity: 100),
    ])

    let result = PianoGuideFlameDescriptor.makeDescriptors(
        currentStep: step,
        keyboardGeometry: makeGeometry(),
        stepOccurrenceGeneration: 1
    )

    #expect(result.count == 1)
    #expect(result.first?.velocity == 64)
}

private func makeGeometry(footprintWidth: Float = 0.04, footprintDepth: Float = 0.06) -> PianoKeyboardGeometry {
    let frame = KeyboardFrame(
        a0World: SIMD3<Float>(0.0, 0.5, 0.0),
        c8World: SIMD3<Float>(1.0, 0.5, 0.0),
        planeHeight: 0.5
    )!

    let key = PianoKeyGeometry(
        midiNote: 60,
        kind: .white,
        localCenter: SIMD3<Float>(0.0, -0.015, -0.07),
        localSize: SIMD3<Float>(0.02, 0.03, 0.14),
        surfaceLocalY: 0.0,
        hitCenterLocal: SIMD3<Float>(0.0, -0.015, -0.07),
        hitSizeLocal: SIMD3<Float>(0.02, 0.03, 0.14),
        beamFootprintCenterLocal: SIMD3<Float>(0.0, 0.0, -0.07),
        beamFootprintSizeLocal: SIMD2<Float>(footprintWidth, footprintDepth)
    )

    return PianoKeyboardGeometry(frame: frame, keys: [key])
}
