import Foundation
@testable import LonelyPianist
import Testing

@MainActor
@Test
func bootstrapAttemptsBluetoothMIDIAutoConnect() {
    let midi = MIDIInputServiceMock()
    let repository = RecordingTakeRepositoryMock()
    let recordingService = RecordingServiceMock()
    let playback = MIDIPlaybackServiceMock()
    let bluetooth = BluetoothMIDIConnectionServiceMock()
    let settings = AppSettingsMock()

    let viewModel = LonelyPianistViewModel(
        midiInputService: midi,
        recordingRepository: repository,
        recordingService: recordingService,
        playbackService: playback,
        bluetoothMIDIConnectionService: bluetooth,
        settings: settings
    )

    viewModel.bootstrap()

    #expect(bluetooth.attemptAutoConnectCallCount == 1)
}

@MainActor
@Test
func rememberLastBluetoothMIDIDevicePersistsToSettings() {
    let midi = MIDIInputServiceMock()
    let repository = RecordingTakeRepositoryMock()
    let recordingService = RecordingServiceMock()
    let playback = MIDIPlaybackServiceMock()
    let bluetooth = BluetoothMIDIConnectionServiceMock()
    let settings = AppSettingsMock()

    let viewModel = LonelyPianistViewModel(
        midiInputService: midi,
        recordingRepository: repository,
        recordingService: recordingService,
        playbackService: playback,
        bluetoothMIDIConnectionService: bluetooth,
        settings: settings
    )

    viewModel.setRememberLastBluetoothMIDIDevice(true)

    #expect(viewModel.rememberLastBluetoothMIDIDevice)
    #expect(settings.rememberLastBluetoothMIDIDevice)
}

