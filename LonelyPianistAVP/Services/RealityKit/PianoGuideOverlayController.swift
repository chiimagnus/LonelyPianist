import Foundation
import RealityKit
import SwiftUI

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
        let centerFalloff = pow(sin(.pi * clampedX), 0.72)
        let edgeSoftness = 0.18 + 0.82 * centerFalloff
        let verticalFade = pow(1 - clampedY, 1.65)
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
    private var gradientTextureCache = BeamGradientTextureCache()
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

        let beam = ModelEntity(mesh: .generateBox(size: 1), materials: [])
        let baseGlow = ModelEntity(mesh: .generateBox(size: 1), materials: [])

        root.addChild(beam)
        root.addChild(baseGlow)

        let marker = KeyBeamMarker(root: root, beam: beam, baseGlow: baseGlow)
        applyMaterials(to: marker, tintColor: tintColor)
        return marker
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

    private func gradientBeamMaterial(for tintColor: UIColor) -> Material {
        if let texture = gradientTextureCache.beamTexture(for: tintColor) {
            var material = UnlitMaterial(texture: texture)
            material.blending = .transparent(opacity: .init(floatLiteral: 1.0))
            return material
        }

        var fallback = UnlitMaterial(color: tintColor.withAlphaComponent(0.20))
        fallback.blending = .transparent(opacity: .init(floatLiteral: 0.20))
        return fallback
    }

    private func baseGlowMaterial(for tintColor: UIColor) -> Material {
        var material = UnlitMaterial(color: tintColor.withAlphaComponent(0.42))
        material.blending = .transparent(opacity: .init(floatLiteral: 0.42))
        return material
    }

    private func clearMarkers() {
        for marker in activeMarkersByMIDINote.values {
            marker.root.removeFromParent()
        }
        activeMarkersByMIDINote.removeAll()
        lastTintColor = nil
    }
}

@MainActor
private struct BeamGradientTextureCache {
    private var texturesByKey: [String: TextureResource] = [:]

    mutating func beamTexture(for tintColor: UIColor) -> TextureResource? {
        let key = cacheKey(for: tintColor)
        if let texture = texturesByKey[key] {
            return texture
        }

        guard let image = makeGradientImage(tintColor: tintColor) else {
            return nil
        }

        guard let texture = try? TextureResource(
            image: image,
            options: TextureResource.CreateOptions(semantic: .color)
        ) else {
            return nil
        }

        texturesByKey[key] = texture
        return texture
    }

    private func cacheKey(for tintColor: UIColor) -> String {
        let components = rgbaComponents(for: tintColor)
        return [components.red, components.green, components.blue]
            .map { String(format: "%.4f", Double($0)) }
            .joined(separator: ":")
    }

    private func makeGradientImage(tintColor: UIColor) -> CGImage? {
        let width = 64
        let height = 256
        let components = rgbaComponents(for: tintColor)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0 ..< height {
            for x in 0 ..< width {
                let horizontal = Float(x) / Float(max(width - 1, 1))
                let vertical = Float(y) / Float(max(height - 1, 1))
                let alpha = Float(PianoGuideBeamGeometry.gradientAlpha(horizontal: horizontal, vertical: vertical))
                let offset = (y * width + x) * 4

                pixels[offset] = UInt8(clamping: Int(components.red * alpha * 255))
                pixels[offset + 1] = UInt8(clamping: Int(components.green * alpha * 255))
                pixels[offset + 2] = UInt8(clamping: Int(components.blue * alpha * 255))
                pixels[offset + 3] = UInt8(clamping: Int(alpha * 255))
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else {
            return nil
        }

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    private func rgbaComponents(for color: UIColor) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 1
        var green: CGFloat = 1
        var blue: CGFloat = 1
        var alpha: CGFloat = 1
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue, alpha)
    }
}
