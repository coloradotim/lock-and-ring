import AVFoundation
import Foundation

@MainActor
protocol AudioInputManaging {
    var selectedInputName: String { get }
    var availableInputNames: [String] { get }
    var latestFrame: AudioInputFrame? { get }
    var state: AudioInputState { get }

    func start()
    func stop()
    func selectInput(named inputName: String)
}

@MainActor
@Observable
final class AudioInputManager: AudioInputManaging {
    private let engine = AVAudioEngine()
    private let bufferSize: AVAudioFrameCount
    private let preferenceStore: AudioInputDevicePreferenceStoring
    private var selectedDevice: AudioInputDevice?

    private(set) var devices: [AudioInputDevice]
    private(set) var latestFrame: AudioInputFrame?
    private(set) var state: AudioInputState = .stopped
    var onFrame: ((AudioInputFrame) -> Void)?

    var selectedInputName: String {
        selectedDevice?.name ?? devices.first?.name ?? "Default Microphone"
    }

    var availableInputNames: [String] {
        let names = devices.map(\.name)
        return names.isEmpty ? ["Default Microphone"] : names
    }

    init(
        bufferSize: AVAudioFrameCount = 1_024,
        preferenceStore: AudioInputDevicePreferenceStoring = UserDefaultsAudioInputStore()
    ) {
        self.bufferSize = bufferSize
        self.preferenceStore = preferenceStore
        self.devices = Self.discoverDevices()
        self.selectedDevice = AudioInputDeviceSelector.choosePreferredDevice(
            from: devices,
            savedPreference: preferenceStore.load()
        )
    }

    func start() {
        guard state != .running else {
            return
        }

        state = .requestingPermission
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] isGranted in
            Task { @MainActor in
                guard let self else {
                    return
                }

                guard isGranted else {
                    self.state = .permissionDenied
                    return
                }

                self.configureAndStartEngine()
            }
        }
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        state = .stopped
    }

    func selectInput(named inputName: String) {
        selectedDevice = devices.first { $0.name == inputName }
        if let selectedDevice {
            preferenceStore.save(AudioInputDevicePreference(device: selectedDevice))
        }

        if state == .running {
            stop()
            start()
        }
    }

    func refreshDevices() {
        devices = Self.discoverDevices()
        if let selectedDevice, devices.contains(selectedDevice) {
            return
        }

        selectedDevice = AudioInputDeviceSelector.choosePreferredDevice(
            from: devices,
            savedPreference: preferenceStore.load()
        )
    }

    private func configureAndStartEngine() {
        do {
            try applySelectedDeviceIfPossible()

            let inputNode = engine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)

            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
                guard let frame = AudioFrameNormalizer.makeFrame(from: buffer, time: time) else {
                    return
                }

                Task { @MainActor in
                    self?.latestFrame = frame
                    self?.onFrame?(frame)
                }
            }

            engine.prepare()
            try engine.start()
            state = .running
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func applySelectedDeviceIfPossible() throws {
        guard let selectedDevice, selectedDevice.audioDeviceID != kAudioObjectUnknown else {
            return
        }

        guard let audioUnit = engine.inputNode.audioUnit else {
            return
        }

        var deviceID = selectedDevice.audioDeviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        if status != noErr {
            throw AudioInputError.deviceSelectionFailed(status)
        }
    }

    private static func discoverDevices() -> [AudioInputDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )

        return discoverySession.devices.map { device in
            AudioInputDevice(
                id: device.uniqueID,
                name: device.localizedName,
                audioDeviceID: Self.audioDeviceID(forUID: device.uniqueID)
            )
        }
    }

    private static func audioDeviceID(forUID uid: String) -> AudioDeviceID {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        guard status == noErr else {
            return kAudioObjectUnknown
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = Array(repeating: AudioDeviceID(), count: deviceCount)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )
        guard status == noErr else {
            return kAudioObjectUnknown
        }

        return deviceIDs.first { deviceID in
            audioDeviceUID(for: deviceID) == uid
        } ?? kAudioObjectUnknown
    }

    private static func audioDeviceUID(for deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &uid
        )

        guard status == noErr else {
            return nil
        }

        return uid as String
    }
}

enum AudioInputState: Equatable {
    case stopped
    case requestingPermission
    case running
    case permissionDenied
    case failed(String)
}

enum AudioInputError: LocalizedError {
    case deviceSelectionFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .deviceSelectionFailed(status):
            "Unable to select audio input device. CoreAudio status: \(status)."
        }
    }
}

struct AudioInputDevice: Equatable, Identifiable {
    let id: String
    let name: String
    let audioDeviceID: AudioDeviceID
}

struct AudioInputDevicePreference: Codable, Equatable, Sendable {
    let deviceID: String
    let label: String
    let savedAt: Date

    init(deviceID: String, label: String, savedAt: Date = Date()) {
        self.deviceID = deviceID
        self.label = label
        self.savedAt = savedAt
    }

    init(device: AudioInputDevice, savedAt: Date = Date()) {
        self.init(deviceID: device.id, label: device.name, savedAt: savedAt)
    }
}

protocol AudioInputDevicePreferenceStoring {
    func load() -> AudioInputDevicePreference?
    func save(_ preference: AudioInputDevicePreference)
}

struct UserDefaultsAudioInputStore: AudioInputDevicePreferenceStoring {
    private let key = "LockAndRing.AudioInputDevicePreference"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> AudioInputDevicePreference? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }

        return try? JSONDecoder().decode(AudioInputDevicePreference.self, from: data)
    }

    func save(_ preference: AudioInputDevicePreference) {
        guard let data = try? JSONEncoder().encode(preference) else {
            return
        }

        userDefaults.set(data, forKey: key)
    }
}

enum AudioInputDeviceSelector {
    static func choosePreferredDevice(
        from devices: [AudioInputDevice],
        savedPreference: AudioInputDevicePreference?
    ) -> AudioInputDevice? {
        if let savedPreference,
           let savedDevice = devices.first(where: { $0.id == savedPreference.deviceID }) {
            return savedDevice
        }

        if let savedPreference,
           let labelMatch = devices.first(where: { normalized($0.name) == normalized(savedPreference.label) }) {
            return labelMatch
        }

        if let builtInDevice = devices.first(where: isBuiltInOrLocalMacMicrophone) {
            return builtInDevice
        }

        if let nonContinuityDevice = devices.first(where: { !isContinuityDevice($0) }) {
            return nonContinuityDevice
        }

        return devices.first
    }

    private static func isBuiltInOrLocalMacMicrophone(_ device: AudioInputDevice) -> Bool {
        let label = normalized(device.name)
        return label.contains("macbook")
            || label.contains("built in")
            || label.contains("builtin")
            || label.contains("internal")
    }

    private static func isContinuityDevice(_ device: AudioInputDevice) -> Bool {
        normalized(device.name).contains("iphone")
    }

    private static func normalized(_ label: String) -> String {
        label
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
    }
}
