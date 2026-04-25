import Foundation
import RealityKit
import SwiftUI

struct PianoGuideBeamGeometry {
    struct BodySegmentDescriptor {
        let scale: SIMD3<Float>
        let position: SIMD3<Float>
        let alpha: CGFloat
    }

    static let beamHeight: Float = 0.22
    static let beamBaseYOffset: Float = 0.006
    static let baseGlowHeight: Float = 0.004
    static let minimumBeamWidth: Float = 0.006
    static let minimumBeamDepth: Float = 0.018
    static let bodySegmentCount = 3
    static let dustParticleCount = 8

    private static let whiteKeyWidthScale: Float = 0.90
    private static let whiteKeyDepthScale: Float = 0.88
    private static let blackKeyWidthScale: Float = 0.58
    private static let blackKeyDepthScale: Float = 0.56
    private static let bodySegmentAlphas: [CGFloat] = [0.24, 0.13, 0.055]
    private static let bodySegmentFootprintScales: [SIMD2<Float>] = [
        SIMD2<Float>(1.04, 1.04),
        SIMD2<Float>(0.92, 0.90),
        SIMD2<Float>(0.74, 0.70)
    ]

    static func isBlackKey(midiNote: Int) -> Bool {
        switch midiNote % 12 {
            case 1, 3, 6, 8, 10:
                return true
            default:
                return false
        }
    }

    static func beamFootprint(for region: PianoKeyRegion) -> SIMD2<Float> {
        let widthScale = isBlackKey(midiNote: region.midiNote) ? blackKeyWidthScale : whiteKeyWidthScale
        let depthScale = isBlackKey(midiNote: region.midiNote) ? blackKeyDepthScale : whiteKeyDepthScale

        return SIMD2<Float>(
            max(region.size.x * widthScale, minimumBeamWidth),
            max(region.size.z * depthScale, minimumBeamDepth)
        )
    }

    static func rootLocalPosition(centerLocal: SIMD3<Float>, region: PianoKeyRegion) -> SIMD3<Float> {
        let keyTopY = centerLocal.y + region.size.y * 0.5
        return SIMD3<Float>(centerLocal.x, keyTopY + beamBaseYOffset, centerLocal.z)
    }

    static func baseGlowScale(footprint: SIMD2<Float>) -> SIMD3<Float> {
        SIMD3<Float>(footprint.x * 1.08, baseGlowHeight, footprint.y * 1.08)
    }

    static func baseGlowPosition() -> SIMD3<Float> {
        SIMD3<Float>(0, baseGlowHeight * 0.5, 0)
    }

    static func bodySegmentDescriptors(footprint: SIMD2<Float>) -> [BodySegmentDescriptor] {
        let segmentHeight = beamHeight / Float(bodySegmentCount)

        return (0 ..< bodySegmentCount).map { index in
            let footprintScale = bodySegmentFootprintScales[index]
            let scale = SIMD3<Float>(
                footprint.x * footprintScale.x,
                segmentHeight,
                footprint.y * footprintScale.y
            )
            let position = SIMD3<Float>(
                0,
                baseGlowHeight + segmentHeight * (Float(index) + 0.5),
                0
            )

            return BodySegmentDescriptor(
                scale: scale,
                position: position,
                alpha: bodySegmentAlphas[index]
            )
        }
    }

    static func dustParticleOffsets(for midiNote: Int) -> [SIMD3<Float>] {
        (0 ..< dustParticleCount).map { index in
            let seed = Double(midiNote * 31 + index * 17)
            let x = (unitNoise(seed * 12.9898) - 0.5) * 0.76
            let y = 0.14 + unitNoise(seed * 78.233) * 0.72
            let z = (unitNoise(seed * 37.719) - 0.5) * 0.76
            return SIMD3<Float>(x, y, z)
        }
    }

    static func dustParticlePosition(offset: SIMD3<Float>, footprint: SIMD2<Float>) -> SIMD3<Float> {
        SIMD3<Float>(
            offset.x * footprint.x,
            baseGlowHeight + offset.y * beamHeight,
            offset.z * footprint.y
        )
    }

    private static func unitNoise(_ value: Double) -> Float {
        Float((sin(value) + 1) * 0.5)
    }
}

@MainActor
final class PianoGuideOverlayController {
    private struct KeyBeamParticle {
        let entity: ModelEntity
        let normalizedOffset: SIMD3<Float>
    }

    private struct KeyBeamMarker {
        let root: Entity
        let bodySegments: [ModelEntity]
        let baseGlow: ModelEntity
        let particles: [KeyBeamParticle]
    }

    private var rootEntity = Entity()
    private var keyboardRootEntity = Entity()
    private var hasAttachedRoot = false
    private var activeMarkersByMIDINote: [Int: KeyBeamMarker] = [:]
    private var lastTintColor: UIColor?

    func updateHighlights(
        currentStep: PracticeStep?,
        keyboardFrame: KeyboardFrame?,
        keyRegions: [PianoKeyRegion],
        feedbackState: PracticeSessionViewModel.VisualFeedbackState,
        content: RealityViewContent
    ) {
        if hasAttachedRoot == false {
            content.add(rootEntity)
            rootEntity.addChild(keyboardRootEntity)
            hasAttachedRoot = true
        }

        guard let currentStep, let keyboardFrame else {
            clearMarkers()
            return
        }

        keyboardRootEntity.transform = Transform(matrix: keyboardFrame.worldFromKeyboard)

        let tintColor: UIColor = switch feedbackState {
            case .none:
                AVPOverlayPalette.feedbackNoneColor
            case .correct:
                AVPOverlayPalette.feedbackCorrectColor
            case .wrong:
                AVPOverlayPalette.feedbackWrongColor
        }

        if lastTintColor != tintColor {
            for marker in activeMarkersByMIDINote.values {
                applyMaterials(to: marker, tintColor: tintColor)
            }
            lastTintColor = tintColor
        }

        let regionByNote = Dictionary(uniqueKeysWithValues: keyRegions.map { ($0.midiNote, $0) })
        let desiredNotes: Set<Int> = Set(currentStep.notes.map(\.midiNote))

        let staleNotes = activeMarkersByMIDINote.keys.filter { desiredNotes.contains($0) == false }
        for midiNote in staleNotes {
            activeMarkersByMIDINote[midiNote]?.root.removeFromParent()
            activeMarkersByMIDINote[midiNote] = nil
        }

        for midiNote in desiredNotes {
            guard let region = regionByNote[midiNote] else { continue }

            let centerWorld = SIMD4<Float>(region.center, 1)
            let centerLocal4 = simd_mul(keyboardFrame.keyboardFromWorld, centerWorld)
            let centerLocal = SIMD3<Float>(centerLocal4.x, centerLocal4.y, centerLocal4.z)

            let marker: KeyBeamMarker
            if let existing = activeMarkersByMIDINote[midiNote] {
                marker = existing
            } else {
                marker = makeKeyBeamMarker(midiNote: midiNote, tintColor: tintColor)
                activeMarkersByMIDINote[midiNote] = marker
                keyboardRootEntity.addChild(marker.root)
            }

            update(marker: marker, region: region, centerLocal: centerLocal)
        }
    }

    private func makeKeyBeamMarker(midiNote: Int, tintColor: UIColor) -> KeyBeamMarker {
        let root = Entity()
        root.name = "key-beam-\(midiNote)"

        let bodySegments = (0 ..< PianoGuideBeamGeometry.bodySegmentCount).map { _ in
            ModelEntity(mesh: .generateBox(size: 1), materials: [])
        }
        let baseGlow = ModelEntity(mesh: .generateBox(size: 1), materials: [])
        let particles = PianoGuideBeamGeometry.dustParticleOffsets(for: midiNote).map { offset in
            KeyBeamParticle(
                entity: ModelEntity(mesh: .generateSphere(radius: 0.0012), materials: []),
                normalizedOffset: offset
            )
        }

        for segment in bodySegments {
            root.addChild(segment)
        }
        root.addChild(baseGlow)
        for particle in particles {
            root.addChild(particle.entity)
        }

        let marker = KeyBeamMarker(root: root, bodySegments: bodySegments, baseGlow: baseGlow, particles: particles)
        applyMaterials(to: marker, tintColor: tintColor)
        return marker
    }

    private func update(marker: KeyBeamMarker, region: PianoKeyRegion, centerLocal: SIMD3<Float>) {
        let footprint = PianoGuideBeamGeometry.beamFootprint(for: region)
        marker.root.position = PianoGuideBeamGeometry.rootLocalPosition(centerLocal: centerLocal, region: region)

        marker.baseGlow.scale = PianoGuideBeamGeometry.baseGlowScale(footprint: footprint)
        marker.baseGlow.position = PianoGuideBeamGeometry.baseGlowPosition()

        let segmentDescriptors = PianoGuideBeamGeometry.bodySegmentDescriptors(footprint: footprint)
        for (segment, descriptor) in zip(marker.bodySegments, segmentDescriptors) {
            segment.scale = descriptor.scale
            segment.position = descriptor.position
        }

        for particle in marker.particles {
            particle.entity.position = PianoGuideBeamGeometry.dustParticlePosition(
                offset: particle.normalizedOffset,
                footprint: footprint
            )
        }
    }

    private func applyMaterials(to marker: KeyBeamMarker, tintColor: UIColor) {
        let descriptors = PianoGuideBeamGeometry.bodySegmentDescriptors(footprint: SIMD2<Float>(1, 1))
        for (segment, descriptor) in zip(marker.bodySegments, descriptors) {
            segment.model?.materials = [lightBeamMaterial(for: tintColor, alpha: descriptor.alpha)]
        }
        marker.baseGlow.model?.materials = [lightBeamMaterial(for: tintColor, alpha: 0.46)]
        for particle in marker.particles {
            particle.entity.model?.materials = [lightBeamMaterial(for: tintColor, alpha: 0.34)]
        }
    }

    private func lightBeamMaterial(for tintColor: UIColor, alpha: CGFloat) -> SimpleMaterial {
        SimpleMaterial(color: tintColor.withAlphaComponent(alpha), isMetallic: false)
    }

    private func clearMarkers() {
        for marker in activeMarkersByMIDINote.values {
            marker.root.removeFromParent()
        }
        activeMarkersByMIDINote.removeAll()
        lastTintColor = nil
    }
}
