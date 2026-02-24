import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class PianoKeyViewModel {
    enum EditorTab: String, CaseIterable, Identifiable {
        case singleKey = "Single Key"
        case chord = "Chord"
        case melody = "Melody"

        var id: String { rawValue }
    }

    struct EventLogItem: Identifiable {
        let id = UUID()
        let timestamp: Date
        let title: String
        let detail: String
    }

    var isListening = false
    var connectionState: MIDIInputConnectionState = .idle
    var hasAccessibilityPermission = false
    var statusMessage = "Ready"

    var profiles: [MappingProfile] = []
    var activeProfileID: UUID?

    var selectedTab: EditorTab = .singleKey
    var previewText = ""
    var pressedNotes: [Int] = []
    var recentLogs: [EventLogItem] = []

    private let logger = Logger(subsystem: "com.chiimagnus.PianoKey", category: "ViewModel")

    private let midiInputService: MIDIInputServiceProtocol
    private let keyboardEventService: KeyboardEventServiceProtocol
    private let permissionService: PermissionServiceProtocol
    private let repository: MappingProfileRepositoryProtocol
    private let mappingEngine: MappingEngineProtocol
    private let shortcutService: ShortcutServiceProtocol

    init(
        midiInputService: MIDIInputServiceProtocol,
        keyboardEventService: KeyboardEventServiceProtocol,
        permissionService: PermissionServiceProtocol,
        repository: MappingProfileRepositoryProtocol,
        mappingEngine: MappingEngineProtocol,
        shortcutService: ShortcutServiceProtocol
    ) {
        self.midiInputService = midiInputService
        self.keyboardEventService = keyboardEventService
        self.permissionService = permissionService
        self.repository = repository
        self.mappingEngine = mappingEngine
        self.shortcutService = shortcutService

        bindServiceCallbacks()
    }

    var activeProfile: MappingProfile? {
        guard let activeProfileID else { return nil }
        return profiles.first(where: { $0.id == activeProfileID })
    }

    var connectionDescription: String {
        switch connectionState {
        case .idle:
            return "Not Listening"
        case .connected(let sourceCount):
            return sourceCount > 0 ? "Connected (\(sourceCount) source)" : "Listening (no source)"
        case .failed(let message):
            return "Error: \(message)"
        }
    }

    func bootstrap() {
        hasAccessibilityPermission = permissionService.hasAccessibilityPermission()

        do {
            try repository.ensureSeedProfilesIfNeeded()
            try reloadProfiles(preserveActiveID: nil)
        } catch {
            statusMessage = "Init failed: \(error.localizedDescription)"
            log(title: "Init Failed", detail: error.localizedDescription)
        }
    }

    func toggleListening() {
        isListening ? stopListening() : startListening()
    }

    func startListening() {
        hasAccessibilityPermission = permissionService.hasAccessibilityPermission()

        guard hasAccessibilityPermission else {
            statusMessage = "Accessibility permission is required"
            log(title: "Permission", detail: "Accessibility permission missing")
            return
        }

        do {
            try midiInputService.start()
            isListening = true
            statusMessage = "Listening MIDI"
        } catch {
            isListening = false
            statusMessage = "Start failed: \(error.localizedDescription)"
            log(title: "Start Failed", detail: error.localizedDescription)
        }
    }

    func stopListening() {
        midiInputService.stop()
        mappingEngine.reset()
        isListening = false
        pressedNotes.removeAll(keepingCapacity: false)
        statusMessage = "Stopped"
    }

    func requestAccessibilityPermission() {
        hasAccessibilityPermission = permissionService.requestAccessibilityPermission()
        statusMessage = hasAccessibilityPermission ? "Accessibility enabled" : "Grant permission in System Settings"
    }

    func refreshMIDISources() {
        do {
            try midiInputService.refreshSources()
            statusMessage = "MIDI sources refreshed"
        } catch {
            statusMessage = "Refresh failed: \(error.localizedDescription)"
            log(title: "MIDI Refresh Failed", detail: error.localizedDescription)
        }
    }

    func setActiveProfile(_ id: UUID) {
        do {
            try repository.setActiveProfile(id: id)
            try reloadProfiles(preserveActiveID: id)
            statusMessage = "Profile switched"
        } catch {
            statusMessage = "Switch failed: \(error.localizedDescription)"
            log(title: "Switch Failed", detail: error.localizedDescription)
        }
    }

    func createProfile(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let now = Date()
        let templatePayload = activeProfile?.payload ?? .empty
        let profile = MappingProfile(
            id: UUID(),
            name: trimmed,
            isBuiltIn: false,
            isActive: true,
            createdAt: now,
            updatedAt: now,
            payload: templatePayload
        )

        do {
            try repository.saveProfile(profile)
            try repository.setActiveProfile(id: profile.id)
            try reloadProfiles(preserveActiveID: profile.id)
            statusMessage = "Profile created"
        } catch {
            statusMessage = "Create failed: \(error.localizedDescription)"
            log(title: "Create Profile Failed", detail: error.localizedDescription)
        }
    }

    func duplicateActiveProfile() {
        guard let source = activeProfile else { return }

        let now = Date()
        let clone = MappingProfile(
            id: UUID(),
            name: "\(source.name) Copy",
            isBuiltIn: false,
            isActive: true,
            createdAt: now,
            updatedAt: now,
            payload: source.payload
        )

        do {
            try repository.saveProfile(clone)
            try repository.setActiveProfile(id: clone.id)
            try reloadProfiles(preserveActiveID: clone.id)
            statusMessage = "Profile duplicated"
        } catch {
            statusMessage = "Duplicate failed: \(error.localizedDescription)"
            log(title: "Duplicate Failed", detail: error.localizedDescription)
        }
    }

    func deleteProfile(_ id: UUID) {
        do {
            try repository.deleteProfile(id: id)
            try reloadProfiles(preserveActiveID: nil)
            statusMessage = "Profile deleted"
        } catch {
            statusMessage = "Delete failed: \(error.localizedDescription)"
            log(title: "Delete Failed", detail: error.localizedDescription)
        }
    }

    func updateProfileName(_ name: String) {
        mutateActiveProfile { profile in
            profile.name = name
        }
    }

    func setVelocityEnabled(_ enabled: Bool) {
        mutateActiveProfile { profile in
            profile.payload.velocityEnabled = enabled
        }
    }

    func setVelocityThreshold(_ value: Int) {
        mutateActiveProfile { profile in
            profile.payload.defaultVelocityThreshold = max(1, min(127, value))
        }
    }

    func addSingleRule(note: Int = 60) {
        mutateActiveProfile { profile in
            let newRule = SingleKeyMappingRule(
                note: max(0, min(127, note)),
                normalOutput: "a",
                velocityThreshold: profile.payload.defaultVelocityThreshold,
                highVelocityOutput: "A"
            )
            profile.payload.singleKeyRules.append(newRule)
        }
    }

    func updateSingleRule(_ rule: SingleKeyMappingRule) {
        mutateActiveProfile { profile in
            guard let index = profile.payload.singleKeyRules.firstIndex(where: { $0.id == rule.id }) else { return }
            profile.payload.singleKeyRules[index] = rule
        }
    }

    func removeSingleRule(_ ruleID: UUID) {
        mutateActiveProfile { profile in
            profile.payload.singleKeyRules.removeAll { $0.id == ruleID }
        }
    }

    func addChordRule() {
        mutateActiveProfile { profile in
            profile.payload.chordRules.append(
                ChordMappingRule(notes: [60, 64, 67], action: .keyCombo("cmd+c"))
            )
        }
    }

    func updateChordRule(_ rule: ChordMappingRule) {
        mutateActiveProfile { profile in
            guard let index = profile.payload.chordRules.firstIndex(where: { $0.id == rule.id }) else { return }
            profile.payload.chordRules[index] = rule
        }
    }

    func removeChordRule(_ ruleID: UUID) {
        mutateActiveProfile { profile in
            profile.payload.chordRules.removeAll { $0.id == ruleID }
        }
    }

    func addMelodyRule() {
        mutateActiveProfile { profile in
            profile.payload.melodyRules.append(
                MelodyMappingRule(notes: [60, 62, 64], maxIntervalMilliseconds: 500, action: .text("hello "))
            )
        }
    }

    func updateMelodyRule(_ rule: MelodyMappingRule) {
        mutateActiveProfile { profile in
            guard let index = profile.payload.melodyRules.firstIndex(where: { $0.id == rule.id }) else { return }
            profile.payload.melodyRules[index] = rule
        }
    }

    func removeMelodyRule(_ ruleID: UUID) {
        mutateActiveProfile { profile in
            profile.payload.melodyRules.removeAll { $0.id == ruleID }
        }
    }

    private func bindServiceCallbacks() {
        midiInputService.onConnectionStateChange = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.connectionState = state
            }
        }

        midiInputService.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleMIDIEvent(event)
            }
        }
    }

    private func handleMIDIEvent(_ event: MIDIEvent) {
        updatePressedNotes(for: event)

        guard let activeProfile else { return }

        let resolvedActions = mappingEngine.process(event: event, profile: activeProfile)

        for resolvedAction in resolvedActions {
            do {
                try execute(resolvedAction.action)
                switch resolvedAction.action.type {
                case .text:
                    appendPreview(resolvedAction.action.value)
                case .keyCombo, .shortcut:
                    appendPreview("[\(resolvedAction.action.value)]")
                }

                log(
                    title: "\(resolvedAction.triggerType)",
                    detail: "\(resolvedAction.sourceDescription) -> \(resolvedAction.action.type.rawValue): \(resolvedAction.action.value)"
                )
            } catch {
                statusMessage = "Action failed: \(error.localizedDescription)"
                log(title: "Action Failed", detail: error.localizedDescription)
            }
        }

        if resolvedActions.isEmpty {
            let noteName = MIDINote(event.note).name
            log(title: "MIDI", detail: "\(event.type) \(noteName) velocity \(event.velocity)")
        }
    }

    private func execute(_ action: MappingAction) throws {
        switch action.type {
        case .text:
            try keyboardEventService.typeText(action.value)
        case .keyCombo:
            let parsed = try KeyComboParser.parse(action.value)
            try keyboardEventService.sendKeyCombo(keyCode: parsed.keyCode, modifiers: parsed.modifiers)
        case .shortcut:
            try shortcutService.runShortcut(named: action.value)
        }
    }

    private func updatePressedNotes(for event: MIDIEvent) {
        switch event.type {
        case .noteOn:
            if !pressedNotes.contains(event.note) {
                pressedNotes.append(event.note)
                pressedNotes.sort()
            }
        case .noteOff:
            pressedNotes.removeAll { $0 == event.note }
        }
    }

    private func appendPreview(_ text: String) {
        previewText += text
        if previewText.count > 120 {
            previewText = String(previewText.suffix(120))
        }
    }

    private func mutateActiveProfile(_ mutation: (inout MappingProfile) -> Void) {
        guard var profile = activeProfile else { return }

        mutation(&profile)
        profile.updatedAt = .now

        do {
            try repository.saveProfile(profile)
            try reloadProfiles(preserveActiveID: profile.id)
        } catch {
            statusMessage = "Update failed: \(error.localizedDescription)"
            log(title: "Update Failed", detail: error.localizedDescription)
        }
    }

    private func reloadProfiles(preserveActiveID: UUID?) throws {
        profiles = try repository.fetchProfiles()

        let preferredID = preserveActiveID ?? activeProfileID
        if let preferredID, profiles.contains(where: { $0.id == preferredID }) {
            activeProfileID = preferredID
        } else {
            activeProfileID = profiles.first(where: { $0.isActive })?.id ?? profiles.first?.id
        }

        if let activeProfileID,
           let active = profiles.first(where: { $0.id == activeProfileID }),
           !active.isActive {
            try repository.setActiveProfile(id: activeProfileID)
            profiles = try repository.fetchProfiles()
        }
    }

    private func log(title: String, detail: String) {
        logger.info("\(title, privacy: .public): \(detail, privacy: .public)")

        recentLogs.insert(
            EventLogItem(timestamp: .now, title: title, detail: detail),
            at: 0
        )

        let maxLogCount = 50
        if recentLogs.count > maxLogCount {
            recentLogs.removeLast(recentLogs.count - maxLogCount)
        }
    }
}
