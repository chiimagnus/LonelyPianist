import Foundation
import RealityKit
import SwiftUI
import UIKit

@MainActor
final class PianoGuideFlameOverlayService {
    private struct ActiveFlameRecord {
        let entity: Entity
        var descriptor: PianoGuideFlameDescriptor
        var isFadingOut: Bool
    }

    private enum FlameApplicationMode {
        case base(opacityMultiplier: Float, birthRateMultiplier: Float, sizeMultiplier: Float)
        case boosted
    }

    private static let fadeDuration: Duration = .milliseconds(200)
    private static let boostDuration: Duration = .milliseconds(350)
    private static let emitterBaseOffsetMeters: Float = 0.002
    private static let minimumEmitterThicknessMeters: Float = 0.001

    private var rootEntity = Entity()
    private var keyboardRootEntity = Entity()
    private var hasAttachedRoot = false
    private var activeFlameRecordsByMIDINote: [Int: ActiveFlameRecord] = [:]
    private var fadeTasksByMIDINote: [Int: Task<Void, Never>] = [:]
    private var boostTasksByMIDINote: [Int: Task<Void, Never>] = [:]
    private var processedCorrectEventGeneration: Int?

    private let parameterService = PianoGuideFlameParameterService()
    private let qualityService = PianoGuideFlameQualityService()
    private let lifecycleService = PianoGuideFlameLifecycleService()

    func updateHighlights(
        currentStep: PracticeStep?,
        keyboardGeometry: PianoKeyboardGeometry?,
        stepOccurrenceGeneration: Int,
        correctFeedbackEvent: PracticeCorrectStepFeedbackEvent?,
        content: RealityViewContent
    ) {
        attachRootIfNeeded(to: content)

        guard let keyboardGeometry else {
            clear()
            return
        }

        keyboardRootEntity.transform = Transform(matrix: keyboardGeometry.frame.worldFromKeyboard)

        let descriptors = PianoGuideFlameDescriptor.makeDescriptors(
            currentStep: currentStep,
            keyboardGeometry: keyboardGeometry,
            stepOccurrenceGeneration: stepOccurrenceGeneration
        )

        guard descriptors.isEmpty == false else {
            processCorrectFeedbackEvent(correctFeedbackEvent, tier: .full)
            for midiNote in activeFlameRecordsByMIDINote.keys.sorted() {
                startFadeOut(midiNote: midiNote)
            }
            return
        }

        let tier = qualityService.tier(forVisibleNoteCount: descriptors.count)
        processCorrectFeedbackEvent(correctFeedbackEvent, tier: tier)

        let activeStates = makeLifecycleStates()
        let actions = lifecycleService.transitionActions(activeStates: activeStates, descriptors: descriptors)
        let descriptorsByMIDI = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.midiNote, $0) })

        for action in actions {
            switch action {
                case let .fadeOut(midiNote):
                    startFadeOut(midiNote: midiNote)
                case let .fadeIn(midiNote):
                    guard let descriptor = descriptorsByMIDI[midiNote] else { continue }
                    createOrUpdateFlame(for: descriptor, tier: tier, shouldRestart: true)
                    startFadeIn(midiNote: midiNote)
                case let .retrigger(midiNote):
                    guard let descriptor = descriptorsByMIDI[midiNote] else { continue }
                    createOrUpdateFlame(for: descriptor, tier: tier, shouldRestart: true)
                    startFadeIn(midiNote: midiNote)
                case let .update(midiNote):
                    guard let descriptor = descriptorsByMIDI[midiNote] else { continue }
                    createOrUpdateFlame(for: descriptor, tier: tier, shouldRestart: false)
            }
        }
    }

    func clear() {
        let plan = lifecycleService.clearPlan(
            fadeTaskMIDINotes: Set(fadeTasksByMIDINote.keys),
            boostTaskMIDINotes: Set(boostTasksByMIDINote.keys)
        )
        for midiNote in plan.fadeTaskMIDINotesToCancel {
            fadeTasksByMIDINote[midiNote]?.cancel()
        }
        for midiNote in plan.boostTaskMIDINotesToCancel {
            boostTasksByMIDINote[midiNote]?.cancel()
        }
        fadeTasksByMIDINote.removeAll()
        boostTasksByMIDINote.removeAll()
        for record in activeFlameRecordsByMIDINote.values {
            record.entity.removeFromParent()
        }
        activeFlameRecordsByMIDINote.removeAll()
        if plan.shouldClearProcessedCorrectEventGeneration {
            processedCorrectEventGeneration = nil
        }
    }

    private func attachRootIfNeeded(to content: RealityViewContent) {
        guard hasAttachedRoot == false else { return }
        content.add(rootEntity)
        rootEntity.addChild(keyboardRootEntity)
        hasAttachedRoot = true
    }

    private func createOrUpdateFlame(
        for descriptor: PianoGuideFlameDescriptor,
        tier: PianoGuideFlameQualityTier,
        shouldRestart: Bool
    ) {
        let entity: Entity
        if let record = activeFlameRecordsByMIDINote[descriptor.midiNote] {
            entity = record.entity
            activeFlameRecordsByMIDINote[descriptor.midiNote] = ActiveFlameRecord(
                entity: entity,
                descriptor: descriptor,
                isFadingOut: false
            )
        } else {
            entity = Entity()
            keyboardRootEntity.addChild(entity)
            activeFlameRecordsByMIDINote[descriptor.midiNote] = ActiveFlameRecord(
                entity: entity,
                descriptor: descriptor,
                isFadingOut: false
            )
        }

        fadeTasksByMIDINote[descriptor.midiNote]?.cancel()
        fadeTasksByMIDINote[descriptor.midiNote] = nil
        if shouldRestart {
            boostTasksByMIDINote[descriptor.midiNote]?.cancel()
            boostTasksByMIDINote[descriptor.midiNote] = nil
        }

        entity.position = SIMD3<Float>(
            descriptor.positionLocal.x,
            descriptor.surfaceLocalY + Self.emitterBaseOffsetMeters,
            descriptor.positionLocal.z
        )

        let isBoosting = boostTasksByMIDINote[descriptor.midiNote] != nil
        guard shouldRestart || isBoosting == false else { return }
        applyParameters(
            to: entity,
            descriptor: descriptor,
            tier: tier,
            mode: .base(
                opacityMultiplier: shouldRestart ? 0.2 : 1.0,
                birthRateMultiplier: shouldRestart ? 0.2 : 1.0,
                sizeMultiplier: 1.0
            ),
            restart: shouldRestart
        )
    }

    private func startFadeIn(midiNote: Int) {
        guard let record = activeFlameRecordsByMIDINote[midiNote] else { return }
        let descriptor = record.descriptor
        fadeTasksByMIDINote[midiNote]?.cancel()
        fadeTasksByMIDINote[midiNote] = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: Self.fadeDuration)
            guard Task.isCancelled == false else { return }
            guard let current = activeFlameRecordsByMIDINote[midiNote],
                  current.descriptor.stepOccurrenceGeneration == descriptor.stepOccurrenceGeneration,
                  current.isFadingOut == false
            else { return }
            let tier = qualityService.tier(forVisibleNoteCount: activeFlameRecordsByMIDINote.count)
            applyParameters(
                to: current.entity,
                descriptor: current.descriptor,
                tier: tier,
                mode: .base(opacityMultiplier: 1.0, birthRateMultiplier: 1.0, sizeMultiplier: 1.0),
                restart: false
            )
            fadeTasksByMIDINote[midiNote] = nil
        }
    }

    private func startFadeOut(midiNote: Int) {
        guard var record = activeFlameRecordsByMIDINote[midiNote] else { return }
        record.isFadingOut = true
        activeFlameRecordsByMIDINote[midiNote] = record
        fadeTasksByMIDINote[midiNote]?.cancel()

        let generation = record.descriptor.stepOccurrenceGeneration
        let wasBoosting = boostTasksByMIDINote[midiNote] != nil
        boostTasksByMIDINote[midiNote]?.cancel()
        boostTasksByMIDINote[midiNote] = nil

        fadeTasksByMIDINote[midiNote] = Task { @MainActor [weak self] in
            guard let self else { return }
            if wasBoosting {
                try? await Task.sleep(for: Self.boostDuration)
                guard Task.isCancelled == false else { return }
            }
            guard let current = activeFlameRecordsByMIDINote[midiNote],
                  current.descriptor.stepOccurrenceGeneration == generation,
                  current.isFadingOut
            else { return }
            applyParameters(
                to: current.entity,
                descriptor: current.descriptor,
                tier: .strongReduction,
                mode: .base(opacityMultiplier: 0.05, birthRateMultiplier: 0.05, sizeMultiplier: 0.7),
                restart: false
            )
            try? await Task.sleep(for: Self.fadeDuration)
            guard Task.isCancelled == false else { return }
            guard let latest = activeFlameRecordsByMIDINote[midiNote],
                  latest.descriptor.stepOccurrenceGeneration == generation,
                  latest.isFadingOut
            else { return }
            latest.entity.removeFromParent()
            activeFlameRecordsByMIDINote[midiNote] = nil
            fadeTasksByMIDINote[midiNote] = nil
        }
    }

    private func processCorrectFeedbackEvent(_ event: PracticeCorrectStepFeedbackEvent?, tier: PianoGuideFlameQualityTier) {
        let plan = lifecycleService.boostPlan(
            event: event,
            activeStates: makeLifecycleStates(),
            processedGeneration: processedCorrectEventGeneration
        )
        processedCorrectEventGeneration = plan.processedGeneration
        for midiNote in plan.targetMIDINotes {
            guard let record = activeFlameRecordsByMIDINote[midiNote], record.isFadingOut == false else { continue }
            startBoost(record: record, tier: tier)
        }
    }

    private func startBoost(record: ActiveFlameRecord, tier: PianoGuideFlameQualityTier) {
        let midiNote = record.descriptor.midiNote
        boostTasksByMIDINote[midiNote]?.cancel()
        applyParameters(to: record.entity, descriptor: record.descriptor, tier: tier, mode: .boosted, restart: false)

        let generation = record.descriptor.stepOccurrenceGeneration
        boostTasksByMIDINote[midiNote] = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: Self.boostDuration)
            guard Task.isCancelled == false else { return }
            guard let current = activeFlameRecordsByMIDINote[midiNote],
                  current.descriptor.stepOccurrenceGeneration == generation,
                  current.isFadingOut == false
            else { return }
            let tier = qualityService.tier(forVisibleNoteCount: activeFlameRecordsByMIDINote.count)
            applyParameters(
                to: current.entity,
                descriptor: current.descriptor,
                tier: tier,
                mode: .base(opacityMultiplier: 1.0, birthRateMultiplier: 1.0, sizeMultiplier: 1.0),
                restart: false
            )
            boostTasksByMIDINote[midiNote] = nil
        }
    }

    private func makeLifecycleStates() -> [Int: PianoGuideFlameLifecycleState] {
        Dictionary(uniqueKeysWithValues: activeFlameRecordsByMIDINote.map { midiNote, record in
            (
                midiNote,
                PianoGuideFlameLifecycleState(
                    midiNote: midiNote,
                    stepOccurrenceGeneration: record.descriptor.stepOccurrenceGeneration,
                    isFadingOut: record.isFadingOut
                )
            )
        })
    }

    private func applyParameters(
        to entity: Entity,
        descriptor: PianoGuideFlameDescriptor,
        tier: PianoGuideFlameQualityTier,
        mode: FlameApplicationMode,
        restart: Bool
    ) {
        let baseParameters = qualityService.scale(
            parameterService.parameters(for: descriptor.velocity),
            for: tier
        )
        let parameters: PianoGuideFlameParameters
        let opacityMultiplier: Float
        let birthRateMultiplier: Float
        let sizeMultiplier: Float
        switch mode {
            case let .base(baseOpacityMultiplier, baseBirthRateMultiplier, baseSizeMultiplier):
                parameters = baseParameters
                opacityMultiplier = baseOpacityMultiplier
                birthRateMultiplier = baseBirthRateMultiplier
                sizeMultiplier = baseSizeMultiplier
            case .boosted:
                parameters = parameterService.boostedParameters(baseParameters)
                opacityMultiplier = 1.2
                birthRateMultiplier = 1.0
                sizeMultiplier = 1.0
        }

        var component = entity.components[ParticleEmitterComponent.self] ?? ParticleEmitterComponent()
        component.emitterShape = .box
        component.emitterShapeSize = SIMD3<Float>(
            max(0.001, descriptor.footprintSizeLocal.x * parameters.footprintScale),
            Self.minimumEmitterThicknessMeters,
            max(0.001, descriptor.footprintSizeLocal.y * parameters.footprintScale)
        )
        component.birthDirection = .local
        component.birthLocation = .surface
        component.emissionDirection = SIMD3<Float>(0, 1, 0)
        component.speed = parameters.speed
        component.speedVariation = parameters.speedVariation
        component.isEmitting = true
        component.mainEmitter.birthRate = parameters.birthRate * birthRateMultiplier
        component.mainEmitter.size = parameters.particleSize * sizeMultiplier
        component.mainEmitter.lifeSpan = Double(parameters.lifetime)
        component.mainEmitter.blendMode = .additive
        component.mainEmitter.isLightingEnabled = false
        component.mainEmitter.color = .evolving(
            start: .single(parameters.colorProfile.start.uiColor(opacityMultiplier: opacityMultiplier)),
            end: .single(parameters.colorProfile.end.uiColor(opacityMultiplier: opacityMultiplier))
        )
        if restart {
            component.restart()
        }
        entity.components.set(component)
        entity.components.set(OpacityComponent(opacity: min(1, max(0, parameters.alpha * opacityMultiplier))))
    }
}

private extension FlameRGBA {
    func uiColor(opacityMultiplier: Float) -> UIColor {
        UIColor(
            red: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(min(1, max(0, alpha * opacityMultiplier)))
        )
    }
}
