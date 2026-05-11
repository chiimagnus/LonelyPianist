import Foundation
@testable import LonelyPianist

final class AppSettingsMock: AppSettingsProtocol {
    var rememberLastBluetoothMIDIDevice = false
    var lastBluetoothMIDIPeripheralID: String?
}

