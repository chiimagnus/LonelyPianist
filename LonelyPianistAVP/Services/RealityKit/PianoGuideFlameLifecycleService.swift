import Foundation

struct PianoGuideFlameLifecycleState: Equatable {
    let midiNote: Int
    let stepOccurrenceGeneration: Int
    let isFadingOut: Bool
}

enum PianoGuideFlameLifecycleAction: Equatable {
    case fadeIn(midiNote: Int)
    case fadeOut(midiNote: Int)
    case retrigger(midiNote: Int)
    case update(midiNote: Int)
}

struct PianoGuideFlameBoostPlan: Equatable {
    let processedGeneration: Int?
    let targetMIDINotes: Set<Int>
}

struct PianoGuideFlameClearPlan: Equatable {
    let fadeTaskMIDINotesToCancel: Set<Int>
    let boostTaskMIDINotesToCancel: Set<Int>
    let shouldClearProcessedCorrectEventGeneration: Bool
}

struct PianoGuideFlameLifecycleService {
    func transitionActions(
        activeStates: [Int: PianoGuideFlameLifecycleState],
        descriptors: [PianoGuideFlameDescriptor]
    ) -> [PianoGuideFlameLifecycleAction] {
        let desiredByMIDI = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.midiNote, $0) })
        var actions: [PianoGuideFlameLifecycleAction] = []

        for midiNote in activeStates.keys.sorted() where desiredByMIDI[midiNote] == nil {
            actions.append(.fadeOut(midiNote: midiNote))
        }

        for descriptor in descriptors.sorted(by: { $0.midiNote < $1.midiNote }) {
            if let active = activeStates[descriptor.midiNote] {
                if active.stepOccurrenceGeneration != descriptor.stepOccurrenceGeneration || active.isFadingOut {
                    actions.append(.retrigger(midiNote: descriptor.midiNote))
                } else {
                    actions.append(.update(midiNote: descriptor.midiNote))
                }
            } else {
                actions.append(.fadeIn(midiNote: descriptor.midiNote))
            }
        }

        return actions
    }

    func boostPlan(
        event: PracticeCorrectStepFeedbackEvent?,
        activeStates: [Int: PianoGuideFlameLifecycleState],
        processedGeneration: Int?
    ) -> PianoGuideFlameBoostPlan {
        guard let event else {
            return PianoGuideFlameBoostPlan(processedGeneration: processedGeneration, targetMIDINotes: [])
        }
        guard event.generation != processedGeneration else {
            return PianoGuideFlameBoostPlan(processedGeneration: processedGeneration, targetMIDINotes: [])
        }

        let targets = event.midiNotes.filter { midiNote in
            guard let state = activeStates[midiNote] else { return false }
            return state.isFadingOut == false
        }
        return PianoGuideFlameBoostPlan(processedGeneration: event.generation, targetMIDINotes: Set(targets))
    }

    func clearPlan(fadeTaskMIDINotes: Set<Int>, boostTaskMIDINotes: Set<Int>) -> PianoGuideFlameClearPlan {
        PianoGuideFlameClearPlan(
            fadeTaskMIDINotesToCancel: fadeTaskMIDINotes,
            boostTaskMIDINotesToCancel: boostTaskMIDINotes,
            shouldClearProcessedCorrectEventGeneration: true
        )
    }
}
