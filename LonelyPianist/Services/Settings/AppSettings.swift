import Foundation

protocol AppSettingsProtocol: AnyObject {
    var rememberLastBluetoothMIDIDevice: Bool { get set }
    var lastBluetoothMIDIPeripheralID: String? { get set }
}

final class UserDefaultsAppSettings: AppSettingsProtocol {
    private enum Keys {
        static let rememberLastBluetoothMIDIDevice = "settings.rememberLastBluetoothMIDIDevice"
        static let lastBluetoothMIDIPeripheralID = "settings.lastBluetoothMIDIPeripheralID"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var rememberLastBluetoothMIDIDevice: Bool {
        get { defaults.bool(forKey: Keys.rememberLastBluetoothMIDIDevice) }
        set { defaults.set(newValue, forKey: Keys.rememberLastBluetoothMIDIDevice) }
    }

    var lastBluetoothMIDIPeripheralID: String? {
        get { defaults.string(forKey: Keys.lastBluetoothMIDIPeripheralID) }
        set { defaults.set(newValue, forKey: Keys.lastBluetoothMIDIPeripheralID) }
    }
}

