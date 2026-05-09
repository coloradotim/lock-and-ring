import Foundation

enum RecordingReadiness: Equatable, Sendable {
    case unknown(message: String)
    case available
    case unavailable(reason: String)

    init(inputState: AudioInputState, hasKnownInput: Bool) {
        guard hasKnownInput || inputState != .running else {
            self = .unavailable(reason: "No microphone input available.")
            return
        }

        switch inputState {
        case .running:
            self = .available
        case .requestingPermission:
            self = .unknown(message: "Preparing microphone...")
        case .stopped:
            self = .unknown(message: "Preparing microphone...")
        case .permissionDenied:
            self = .unavailable(reason: "Record Take unavailable until microphone permission is granted.")
        case let .failed(message):
            self = .unavailable(reason: "Record Take unavailable: \(message)")
        }
    }

    var isAvailable: Bool {
        self == .available
    }

    var canAttemptRecording: Bool {
        switch self {
        case .available, .unknown:
            true
        case .unavailable:
            false
        }
    }

    var statusMessage: String? {
        switch self {
        case .available:
            nil
        case let .unknown(message):
            message
        case let .unavailable(reason):
            reason
        }
    }
}
