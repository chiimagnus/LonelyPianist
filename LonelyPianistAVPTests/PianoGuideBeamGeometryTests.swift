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
func bodySegmentsStackUpwardAndFadeTowardTop() {
    let footprint = SIMD2<Float>(0.02, 0.12)
    let descriptors = PianoGuideBeamGeometry.bodySegmentDescriptors(footprint: footprint)

    #expect(descriptors.count == PianoGuideBeamGeometry.bodySegmentCount)
    #expect(descriptors[0].position.y < descriptors[1].position.y)
    #expect(descriptors[1].position.y < descriptors[2].position.y)
    #expect(descriptors[0].alpha > descriptors[1].alpha)
    #expect(descriptors[1].alpha > descriptors[2].alpha)

    let expectedHeight = PianoGuideBeamGeometry.beamHeight / Float(PianoGuideBeamGeometry.bodySegmentCount)
    for descriptor in descriptors {
        #expect(abs(descriptor.scale.y - expectedHeight) < 1e-6)
    }
}

@Test
func dustParticleOffsetsAreStableAndInsideBeamVolume() {
    let firstOffsets = PianoGuideBeamGeometry.dustParticleOffsets(for: 60)
    let secondOffsets = PianoGuideBeamGeometry.dustParticleOffsets(for: 60)
    let differentNoteOffsets = PianoGuideBeamGeometry.dustParticleOffsets(for: 61)

    #expect(firstOffsets.count == PianoGuideBeamGeometry.dustParticleCount)
    #expect(firstOffsets == secondOffsets)
    #expect(firstOffsets != differentNoteOffsets)

    for offset in firstOffsets {
        #expect(offset.x >= -0.38)
        #expect(offset.x <= 0.38)
        #expect(offset.y >= 0.14)
        #expect(offset.y <= 0.86)
        #expect(offset.z >= -0.38)
        #expect(offset.z <= 0.38)
    }
}
