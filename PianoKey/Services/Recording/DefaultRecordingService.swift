import Foundation

@MainActor
final class DefaultRecordingService: RecordingServiceProtocol {
    private struct NoteKey: Hashable {
        let note: Int
        let channel: Int
    }

    private struct OpenNote {
        let startedAt: Date
        let velocity: Int
    }

    private let clock: ClockProtocol
    private var openNotes: [NoteKey: OpenNote] = [:]
    private var recordedNotes: [RecordedNote] = []

    private(set) var isRecording = false
    private(set) var startedAt: Date?

    init(clock: ClockProtocol = SystemClock()) {
        self.clock = clock
    }

    func startRecording(at date: Date) {
        startedAt = date
        isRecording = true
        openNotes.removeAll(keepingCapacity: false)
        recordedNotes.removeAll(keepingCapacity: false)
    }

    func append(event: MIDIEvent) {
        guard isRecording, let startedAt else { return }

        let note = max(0, min(127, event.note))
        let channel = max(1, event.channel)
        let velocity = max(0, min(127, event.velocity))
        let key = NoteKey(note: note, channel: channel)

        switch event.type {
        case .noteOn:
            if let openNote = openNotes[key] {
                appendRecordedNote(
                    note: note,
                    velocity: openNote.velocity,
                    channel: channel,
                    startAt: openNote.startedAt,
                    endAt: event.timestamp,
                    recordingStartedAt: startedAt
                )
            }
            openNotes[key] = OpenNote(startedAt: event.timestamp, velocity: velocity)

        case .noteOff:
            guard let openNote = openNotes.removeValue(forKey: key) else { return }
            appendRecordedNote(
                note: note,
                velocity: openNote.velocity,
                channel: channel,
                startAt: openNote.startedAt,
                endAt: event.timestamp,
                recordingStartedAt: startedAt
            )
        }
    }

    func stopRecording(at date: Date, takeID: UUID, name: String) -> RecordingTake? {
        guard isRecording, let startedAt else { return nil }

        for (key, openNote) in openNotes {
            appendRecordedNote(
                note: key.note,
                velocity: openNote.velocity,
                channel: key.channel,
                startAt: openNote.startedAt,
                endAt: date,
                recordingStartedAt: startedAt
            )
        }

        let sanitizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let takeName = sanitizedName.isEmpty ? "Take \(formatted(date: date))" : sanitizedName
        let duration = max(0, date.timeIntervalSince(startedAt))
        let notes = recordedNotes.sorted { lhs, rhs in
            if lhs.startOffsetSec != rhs.startOffsetSec {
                return lhs.startOffsetSec < rhs.startOffsetSec
            }
            return lhs.note < rhs.note
        }

        let take = RecordingTake(
            id: takeID,
            name: takeName,
            createdAt: startedAt,
            updatedAt: date,
            durationSec: duration,
            notes: notes
        )

        cancelRecording()
        return take
    }

    func cancelRecording() {
        isRecording = false
        startedAt = nil
        openNotes.removeAll(keepingCapacity: false)
        recordedNotes.removeAll(keepingCapacity: false)
    }

    private func appendRecordedNote(
        note: Int,
        velocity: Int,
        channel: Int,
        startAt: Date,
        endAt: Date,
        recordingStartedAt: Date
    ) {
        let startOffset = max(0, startAt.timeIntervalSince(recordingStartedAt))
        let duration = max(0.01, endAt.timeIntervalSince(startAt))

        recordedNotes.append(
            RecordedNote(
                id: UUID(),
                note: note,
                velocity: velocity,
                channel: channel,
                startOffsetSec: startOffset,
                durationSec: duration
            )
        )
    }

    private func formatted(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
