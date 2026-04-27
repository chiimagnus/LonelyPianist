@testable import LonelyPianistAVP
import Testing

@Test
@MainActor
func velocityMapsToExpectedIntensityBands() {
    let service = PianoGuideFlameParameterService()

    #expect(service.intensityBand(for: 1) == .soft)
    #expect(service.intensityBand(for: 40) == .soft)
    #expect(service.intensityBand(for: 41) == .mediumSoft)
    #expect(service.intensityBand(for: 70) == .mediumSoft)
    #expect(service.intensityBand(for: 71) == .medium)
    #expect(service.intensityBand(for: 95) == .medium)
    #expect(service.intensityBand(for: 96) == .strong)
    #expect(service.intensityBand(for: 112) == .strong)
    #expect(service.intensityBand(for: 113) == .veryStrong)
}

@Test
@MainActor
func strongerVelocityProducesStrongerFlameParameters() {
    let service = PianoGuideFlameParameterService()
    let soft = service.parameters(for: 30)
    let medium = service.parameters(for: 88)
    let strong = service.parameters(for: 120)

    #expect(soft.birthRate < medium.birthRate)
    #expect(medium.birthRate < strong.birthRate)
    #expect(soft.speed < medium.speed)
    #expect(medium.speed < strong.speed)
    #expect(soft.particleSize < medium.particleSize)
    #expect(medium.particleSize < strong.particleSize)
}

@Test
@MainActor
func bandInternalVelocityTuningIsMonotonic() {
    let service = PianoGuideFlameParameterService()
    let lower = service.parameters(for: 72)
    let upper = service.parameters(for: 94)

    #expect(lower.intensityBand == .medium)
    #expect(upper.intensityBand == .medium)
    #expect(lower.birthRate < upper.birthRate)
    #expect(lower.speed < upper.speed)
}

@Test
@MainActor
func correctBoostRaisesActivityWithoutChangingBand() {
    let service = PianoGuideFlameParameterService()
    let base = service.parameters(for: 88)
    let boosted = service.boostedParameters(base)

    #expect(boosted.intensityBand == base.intensityBand)
    #expect(boosted.birthRate > base.birthRate)
    #expect(boosted.speed > base.speed)
    #expect(boosted.particleSize > base.particleSize)
}
