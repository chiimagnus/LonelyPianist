@testable import LonelyPianistAVP
import simd
import Testing

@Test
func rectangularBeamFootprintUsesKeyShapeAndKeepsBlackKeysNarrower() {
    let whiteRegion = PianoKeyRegion(
        midiNote: 60,
        center: .zero,
        size: SIMD3<Float>(0.02, 0.03, 0.14)
    )
    let blackRegion = PianoKeyRegion(
        midiNote: 61,
        center: .zero,
        size: SIMD3<Float>(0.02, 0.03, 0.14)
    )

    let whiteFootprint = PianoGuideBeamGeometry.beamFootprint(for: whiteRegion)
    let blackFootprint = PianoGuideBeamGeometry.beamFootprint(for: blackRegion)

    #expect(PianoGuideBeamGeometry.isBlackKey(midiNote: 60) == false)
    #expect(PianoGuideBeamGeometry.isBlackKey(midiNote: 61) == true)
    #expect(abs(whiteFootprint.x - 0.018) < 1e-6)
    #expect(abs(whiteFootprint.y - 0.1232) < 1e-6)
    #expect(blackFootprint.x < whiteFootprint.x)
    #expect(blackFootprint.y < whiteFootprint.y)
    #expect(abs(blackFootprint.x - 0.0116) < 1e-6)
    #expect(abs(blackFootprint.y - 0.0784) < 1e-6)
}

@Test
func rectangularBeamRootStartsAboveKeyTop() {
    let centerLocal = SIMD3<Float>(1.0, 2.0, 3.0)
    let region = PianoKeyRegion(
        midiNote: 60,
        center: .zero,
        size: SIMD3<Float>(0.02, 0.03, 0.14)
    )

    let rootPosition = PianoGuideBeamGeometry.rootLocalPosition(centerLocal: centerLocal, region: region)

    #expect(abs(rootPosition.x - centerLocal.x) < 1e-6)
    #expect(abs(rootPosition.y - 2.021) < 1e-6)
    #expect(abs(rootPosition.z - centerLocal.z) < 1e-6)
}

@Test
func singleGradientBeamUsesOneCuboidScaleAndPosition() {
    let footprint = SIMD2<Float>(0.02, 0.12)

    let scale = PianoGuideBeamGeometry.beamScale(footprint: footprint)
    let position = PianoGuideBeamGeometry.beamPosition()

    #expect(abs(scale.x - 0.02) < 1e-6)
    #expect(abs(scale.y - PianoGuideBeamGeometry.beamHeight) < 1e-6)
    #expect(abs(scale.z - 0.12) < 1e-6)
    #expect(abs(position.x) < 1e-6)
    #expect(abs(position.y - (PianoGuideBeamGeometry.baseGlowHeight + PianoGuideBeamGeometry.beamHeight * 0.5)) < 1e-6)
    #expect(abs(position.z) < 1e-6)
}

@Test
func baseGlowMatchesBeamFootprint() {
    let footprint = SIMD2<Float>(0.02, 0.12)

    let scale = PianoGuideBeamGeometry.baseGlowScale(footprint: footprint)
    let position = PianoGuideBeamGeometry.baseGlowPosition()

    #expect(abs(scale.x - 0.0216) < 1e-6)
    #expect(abs(scale.y - PianoGuideBeamGeometry.baseGlowHeight) < 1e-6)
    #expect(abs(scale.z - 0.1296) < 1e-6)
    #expect(abs(position.y - PianoGuideBeamGeometry.baseGlowHeight * 0.5) < 1e-6)
}

@Test
func gradientAlphaFadesTowardTopAndEdges() {
    let bottomCenter = PianoGuideBeamGeometry.gradientAlpha(horizontal: 0.5, vertical: 0)
    let topCenter = PianoGuideBeamGeometry.gradientAlpha(horizontal: 0.5, vertical: 1)
    let bottomEdge = PianoGuideBeamGeometry.gradientAlpha(horizontal: 0, vertical: 0)

    #expect(bottomCenter > topCenter)
    #expect(bottomCenter > bottomEdge)
    #expect(topCenter > 0)
    #expect(bottomCenter <= 0.36)
}
