@testable import LonelyPianistAVP
import Testing

@Test
func qualityTierUsesFullQualityForUpToSixNotes() {
    let service = PianoGuideFlameQualityService()

    #expect(service.tier(forVisibleNoteCount: 1) == .full)
    #expect(service.tier(forVisibleNoteCount: 6) == .full)
}

@Test
func qualityTierReducesForSevenOrMoreNotes() {
    let service = PianoGuideFlameQualityService()

    #expect(service.tier(forVisibleNoteCount: 7) == .mildReduction)
    #expect(service.tier(forVisibleNoteCount: 10) == .mildReduction)
    #expect(service.tier(forVisibleNoteCount: 11) == .strongReduction)
}

@Test
func qualityScalingNeverHidesFlameCompletely() {
    let parameterService = PianoGuideFlameParameterService()
    let qualityService = PianoGuideFlameQualityService()
    let base = parameterService.parameters(for: 100)
    let scaled = qualityService.scale(base, for: .strongReduction)

    #expect(scaled.birthRate > 0)
    #expect(scaled.particleSize > 0)
    #expect(scaled.birthRate < base.birthRate)
    #expect(scaled.particleSize < base.particleSize)
}
