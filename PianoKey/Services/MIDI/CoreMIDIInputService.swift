import CoreMIDI
import Foundation
import OSLog

enum MIDIInputServiceError: LocalizedError {
    case clientCreate(OSStatus)
    case portCreate(OSStatus)
    case sourceRefresh(OSStatus)

    var errorDescription: String? {
        switch self {
        case .clientCreate(let status):
            return "Failed to create MIDI client: \(status)"
        case .portCreate(let status):
            return "Failed to create MIDI input port: \(status)"
        case .sourceRefresh(let status):
            return "Failed to refresh MIDI sources: \(status)"
        }
    }
}

final class CoreMIDIInputService: MIDIInputServiceProtocol {
    var onEvent: (@Sendable (MIDIEvent) -> Void)?
    var onConnectionStateChange: (@Sendable (MIDIInputConnectionState) -> Void)?
    var onSourceNamesChange: (@Sendable ([String]) -> Void)?

    private let logger = Logger(subsystem: "com.chiimagnus.PianoKey", category: "CoreMIDI")

    private var clientRef: MIDIClientRef = 0
    private var inputPortRef: MIDIPortRef = 0
    private var connectedSources: [MIDIEndpointRef] = []
    private var isRunning = false

    deinit {
        stop()
    }

    func start() throws {
        guard !isRunning else { return }

        try createClientIfNeeded()
        try createInputPortIfNeeded()
        try refreshSources()

        isRunning = true
        logger.info("MIDI listening started")
    }

    func stop() {
        disconnectAllSources()

        if inputPortRef != 0 {
            MIDIPortDispose(inputPortRef)
            inputPortRef = 0
        }

        if clientRef != 0 {
            MIDIClientDispose(clientRef)
            clientRef = 0
        }

        isRunning = false
        onConnectionStateChange?(.idle)
        logger.info("MIDI listening stopped")
    }

    func refreshSources() throws {
        guard inputPortRef != 0 else {
            onConnectionStateChange?(.failed("MIDI input port is unavailable"))
            return
        }

        disconnectAllSources()

        var failedStatus: OSStatus?
        let sourceCount = MIDIGetNumberOfSources()

        for index in 0..<sourceCount {
            let source = MIDIGetSource(index)
            guard source != 0 else { continue }

            let status = MIDIPortConnectSource(inputPortRef, source, nil)
            if status == noErr {
                connectedSources.append(source)
            } else {
                failedStatus = status
                logger.error("Failed to connect source \(index, privacy: .public): \(status, privacy: .public)")
            }
        }

        if connectedSources.isEmpty {
            onSourceNamesChange?([])
            if let failedStatus {
                onConnectionStateChange?(.failed("No MIDI source connected (status: \(failedStatus))"))
                throw MIDIInputServiceError.sourceRefresh(failedStatus)
            }
            onConnectionStateChange?(.connected(sourceCount: 0))
            logger.info("MIDI source refresh finished with zero connected source")
            return
        }

        let sourceNames = connectedSources.map(endpointName)
        onSourceNamesChange?(sourceNames)

        onConnectionStateChange?(.connected(sourceCount: connectedSources.count))
        logger.info("MIDI connected source count: \(self.connectedSources.count, privacy: .public)")
    }

    private func createClientIfNeeded() throws {
        guard clientRef == 0 else { return }

        let status = MIDIClientCreate(
            "PianoKeyMIDIClient" as CFString,
            nil,
            nil,
            &clientRef
        )

        guard status == noErr else {
            onConnectionStateChange?(.failed("Create MIDI client failed: \(status)"))
            throw MIDIInputServiceError.clientCreate(status)
        }
    }

    private func createInputPortIfNeeded() throws {
        guard inputPortRef == 0 else { return }

        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let status = MIDIInputPortCreate(
            clientRef,
            "PianoKeyMIDIInput" as CFString,
            midiReadProc,
            context,
            &inputPortRef
        )

        guard status == noErr else {
            onConnectionStateChange?(.failed("Create MIDI input port failed: \(status)"))
            throw MIDIInputServiceError.portCreate(status)
        }
    }

    private func disconnectAllSources() {
        for source in connectedSources {
            MIDIPortDisconnectSource(inputPortRef, source)
        }
        connectedSources.removeAll(keepingCapacity: false)
        onSourceNamesChange?([])
    }

    private func endpointName(_ endpoint: MIDIEndpointRef) -> String {
        var displayName: Unmanaged<CFString>?
        let displayStatus = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &displayName)
        if displayStatus == noErr, let displayName {
            return displayName.takeRetainedValue() as String
        }

        var name: Unmanaged<CFString>?
        let nameStatus = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &name)
        if nameStatus == noErr, let name {
            return name.takeRetainedValue() as String
        }

        return "Unknown MIDI Source"
    }

    fileprivate func handlePacketList(_ packetList: UnsafePointer<MIDIPacketList>) {
        withUnsafePointer(to: packetList.pointee.packet) { firstPacket in
            var packetPointer = firstPacket

            for _ in 0..<packetList.pointee.numPackets {
                let packet = packetPointer.pointee
                let length = Int(packet.length)

                if length > 0 {
                    withUnsafeBytes(of: packet.data) { rawBuffer in
                        let bytes = rawBuffer.prefix(length)
                        parseMIDIBytes(Array(bytes))
                    }
                }

                packetPointer = UnsafePointer(MIDIPacketNext(packetPointer))
            }
        }
    }

    private func parseMIDIBytes(_ bytes: [UInt8]) {
        guard !bytes.isEmpty else { return }

        var index = 0
        while index < bytes.count {
            let status = bytes[index]

            if status < 0x80 {
                index += 1
                continue
            }

            let command = status & 0xF0
            let channel = Int(status & 0x0F) + 1

            switch command {
            case 0x80, 0x90:
                guard index + 2 < bytes.count else {
                    index = bytes.count
                    continue
                }

                let note = Int(bytes[index + 1])
                let velocity = Int(bytes[index + 2])
                let eventType: MIDIEvent.EventType = (command == 0x90 && velocity > 0) ? .noteOn : .noteOff

                let event = MIDIEvent(
                    type: eventType,
                    note: note,
                    velocity: velocity,
                    channel: channel,
                    timestamp: Date()
                )

                onEvent?(event)
                index += 3
            case 0xC0, 0xD0:
                index += 2
            default:
                index += 3
            }
        }
    }
}

private func midiReadProc(
    packetList: UnsafePointer<MIDIPacketList>,
    readProcRefCon: UnsafeMutableRawPointer?,
    srcConnRefCon: UnsafeMutableRawPointer?
) {
    guard let readProcRefCon else { return }

    let service = Unmanaged<CoreMIDIInputService>.fromOpaque(readProcRefCon).takeUnretainedValue()
    service.handlePacketList(packetList)
}
