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

    init(bufferSize: AVAudioFrameCount = 1_024) {
        self.bufferSize = bufferSize
        self.devices = Self.discoverDevices()
        self.selectedDevice = devices.first
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

        selectedDevice = devices.first
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
