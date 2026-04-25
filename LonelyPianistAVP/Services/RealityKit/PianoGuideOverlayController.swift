import Foundation
import RealityKit
import SwiftUI
import UIKit

struct PianoGuideBeamGeometry {
    static let beamHeight: Float = 0.22
    static let beamBaseYOffset: Float = 0.006
    static let baseGlowHeight: Float = 0.004
    static let minimumBeamWidth: Float = 0.006
    static let minimumBeamDepth: Float = 0.018

    private static let whiteKeyWidthScale: Float = 0.90
    private static let whiteKeyDepthScale: Float = 0.88
    private static let blackKeyWidthScale: Float = 0.58
    private static let blackKeyDepthScale: Float = 0.56

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

    static func beamScale(footprint: SIMD2<Float>) -> SIMD3<Float> {
        SIMD3<Float>(footprint.x, beamHeight, footprint.y)
    }

    static func beamPosition() -> SIMD3<Float> {
        SIMD3<Float>(0, baseGlowHeight + beamHeight * 0.5, 0)
    }

    static func baseGlowScale(footprint: SIMD2<Float>) -> SIMD3<Float> {
        SIMD3<Float>(footprint.x * 1.08, baseGlowHeight, footprint.y * 1.08)
    }

    static func baseGlowPosition() -> SIMD3<Float> {
        SIMD3<Float>(0, baseGlowHeight * 0.5, 0)
    }

    static func gradientAlpha(horizontal: Float, vertical: Float) -> CGFloat {
        let clampedX = min(max(horizontal, 0), 1)
        let clampedY = min(max(vertical, 0), 1)
        let centerWave = sin(Double(Float.pi * clampedX))
        let centerFalloff = Float(pow(centerWave, 0.72))
        let edgeSoftness: Float = 0.18 + 0.82 * centerFalloff
        let verticalFade = Float(pow(Double(1 - clampedY), 1.65))
        let baseMist: Float = 0.018
        let beamStrength: Float = 0.34
        return CGFloat((baseMist + beamStrength * verticalFade) * edgeSoftness)
    }
}

@MainActor
final class PianoGuideOverlayController {
    private struct KeyBeamMarker {
        let root: Entity
        let beam: ModelEntity
        let baseGlow: ModelEntity
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

        if lastTintColor?.isEqual(tintColor) != true {
            for marker in activeMarkersByMIDINote.values {
                applyMaterials(to: marker, tintColor: tintColor)
            }
            lastTintColor = tintColor
        }

        let regionByNote = keyRegions.reduce(into: [Int: PianoKeyRegion]()) { partialResult, region in
            partialResult[region.midiNote] = region
        }
        let desiredNotes = Set(currentStep.notes.map(\.midiNote))
        let drawableNotes = desiredNotes.intersection(regionByNote.keys)

        let staleNotes = activeMarkersByMIDINote.keys.filter { drawableNotes.contains($0) == false }
        for midiNote in staleNotes {
            activeMarkersByMIDINote[midiNote]?.root.removeFromParent()
            activeMarkersByMIDINote[midiNote] = nil
        }

        for midiNote in drawableNotes {
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

        let beam = ModelEntity(
            mesh: .generateBox(size: 1),
            materials: [gradientBeamMaterial(for: tintColor)]
        )
        let baseGlow = ModelEntity(
            mesh: .generateBox(size: 1),
            materials: [baseGlowMaterial(for: tintColor)]
        )

        root.addChild(beam)
        root.addChild(baseGlow)

        return KeyBeamMarker(root: root, beam: beam, baseGlow: baseGlow)
    }

    private func update(marker: KeyBeamMarker, region: PianoKeyRegion, centerLocal: SIMD3<Float>) {
        let footprint = PianoGuideBeamGeometry.beamFootprint(for: region)
        marker.root.position = PianoGuideBeamGeometry.rootLocalPosition(centerLocal: centerLocal, region: region)

        marker.beam.scale = PianoGuideBeamGeometry.beamScale(footprint: footprint)
        marker.beam.position = PianoGuideBeamGeometry.beamPosition()

        marker.baseGlow.scale = PianoGuideBeamGeometry.baseGlowScale(footprint: footprint)
        marker.baseGlow.position = PianoGuideBeamGeometry.baseGlowPosition()
    }

    private func applyMaterials(to marker: KeyBeamMarker, tintColor: UIColor) {
        marker.beam.model?.materials = [gradientBeamMaterial(for: tintColor)]
        marker.baseGlow.model?.materials = [baseGlowMaterial(for: tintColor)]
    }

    private func gradientBeamMaterial(for tintColor: UIColor) -> SimpleMaterial {
        SimpleMaterial(color: tintColor.withAlphaComponent(0.20), isMetallic: false)
    }

    private func baseGlowMaterial(for tintColor: UIColor) -> SimpleMaterial {
        SimpleMaterial(color: tintColor.withAlphaComponent(0.42), isMetallic: false)
    }

    private func clearMarkers() {
        for marker in activeMarkersByMIDINote.values {
            marker.root.removeFromParent()
        }
        activeMarkersByMIDINote.removeAll()
        lastTintColor = nil
    }
}
