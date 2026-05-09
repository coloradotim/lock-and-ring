import Foundation

enum MicSetupReadinessKind: Equatable, Sendable {
    case ready
    case preparing
    case needsPermission
    case noInputDevice
    case tooQuiet
    case clipping
    case noisyRoom
    case stereoImbalance
    case unstableSignal
}

struct MicSetupReadinessDisplayState: Equatable, Sendable {
    let kind: MicSetupReadinessKind
    let title: String
    let compactItems: [String]
    let summary: String
    let recommendation: String

    init(
        inputName: String,
        inputState: AudioInputState,
        frame: AudioInputFrame?,
        signal: SignalQualityDisplayState?
    ) {
        let kind = Self.kind(inputState: inputState, frame: frame, signal: signal)
        self.kind = kind
        self.title = Self.title(for: kind)
        self.compactItems = Self.compactItems(inputName: inputName, frame: frame, kind: kind)
        self.summary = Self.summary(for: kind)
        self.recommendation = Self.recommendation(for: kind)
    }

    var isUsable: Bool {
        kind == .ready
    }

    var setupCheckResult: String {
        isUsable ? "Setup looks usable." : recommendation
    }

    private static func kind(
        inputState: AudioInputState,
        frame: AudioInputFrame?,
        signal: SignalQualityDisplayState?
    ) -> MicSetupReadinessKind {
        switch inputState {
        case .permissionDenied:
            return .needsPermission
        case .failed:
            return .noInputDevice
        case .requestingPermission, .stopped:
            return .preparing
        case .running:
            break
        }

        guard let frame else {
            return .preparing
        }

        if frame.instrumentation.isClipping {
            return .clipping
        }

        if frame.instrumentation.hasChannelImbalance {
            return .stereoImbalance
        }

        if !frame.instrumentation.hasSignal || frame.instrumentation.rmsLevel < 0.03 {
            return .tooQuiet
        }

        if isNoisy(frame.instrumentation) {
            return .noisyRoom
        }

        if signal?.isReliable == false {
            return .unstableSignal
        }

        return .ready
    }

    private static func isNoisy(_ instrumentation: AudioInputInstrumentation) -> Bool {
        guard instrumentation.rmsLevel > 0 else {
            return false
        }

        return instrumentation.noiseFloor > 0.03
            && instrumentation.noiseFloor / instrumentation.rmsLevel > 0.45
    }

    private static func title(for kind: MicSetupReadinessKind) -> String {
        switch kind {
        case .ready:
            "Mic setup ready"
        case .preparing:
            "Preparing microphone"
        case .needsPermission:
            "Microphone permission needed"
        case .noInputDevice:
            "No microphone input"
        case .tooQuiet:
            "Signal too quiet"
        case .clipping:
            "Input clipping"
        case .noisyRoom:
            "Room too noisy"
        case .stereoImbalance:
            "Stereo balance warning"
        case .unstableSignal:
            "Signal unstable"
        }
    }

    private static func summary(for kind: MicSetupReadinessKind) -> String {
        switch kind {
        case .ready:
            "The recording should be technically usable for Take Analysis."
        case .preparing:
            "Sing or speak at rehearsal volume for a few seconds."
        case .needsPermission:
            "Lock & Ring needs microphone permission before recording."
        case .noInputDevice:
            "The app cannot use a microphone input right now."
        case .tooQuiet:
            "The app may not have enough signal to trust lock and ring analysis."
        case .clipping:
            "The input is distorting before analysis can be trusted."
        case .noisyRoom:
            "Background noise may hide harmonic evidence."
        case .stereoImbalance:
            "One stereo channel is much stronger than the other."
        case .unstableSignal:
            "The signal is present, but confidence is still low."
        }
    }

    private static func recommendation(for kind: MicSetupReadinessKind) -> String {
        switch kind {
        case .ready:
            "Record when the quartet is ready."
        case .preparing:
            "Use Check Mic Setup after singing or speaking for 3 seconds."
        case .needsPermission:
            "Grant microphone permission in macOS settings, then try again."
        case .noInputDevice:
            "Choose a microphone or reconnect the selected input."
        case .tooQuiet:
            "Move closer to the mic or sing slightly louder."
        case .clipping:
            "Lower input gain or move the mic farther away."
        case .noisyRoom:
            "Move away from fans or HVAC, or choose a quieter room."
        case .stereoImbalance:
            "Reposition the XY mic or singers so the stereo image is centered."
        case .unstableSignal:
            "Try a steadier sung tone and check mic placement."
        }
    }

    private static func compactItems(
        inputName: String,
        frame: AudioInputFrame?,
        kind: MicSetupReadinessKind
    ) -> [String] {
        [
            "Mic: \(inputName)",
            channelText(frame),
            levelText(frame),
            clippingText(frame),
            balanceText(frame),
            roomText(kind)
        ]
    }

    private static func channelText(_ frame: AudioInputFrame?) -> String {
        guard let frame else {
            return "Input: preparing"
        }

        return frame.channelCount >= 2 ? "Stereo" : "Mono"
    }

    private static func levelText(_ frame: AudioInputFrame?) -> String {
        guard let level = frame?.instrumentation.rmsLevel else {
            return "Level: waiting"
        }

        switch level {
        case ..<0.03:
            return "Level: too quiet"
        case 0.8...:
            return "Level: hot"
        default:
            return "Level: good"
        }
    }

    private static func clippingText(_ frame: AudioInputFrame?) -> String {
        frame?.instrumentation.isClipping == true ? "Clipping" : "No clipping"
    }

    private static func balanceText(_ frame: AudioInputFrame?) -> String {
        guard let frame, frame.channelCount >= 2 else {
            return "Balance: n/a"
        }

        return frame.instrumentation.hasChannelImbalance ? "Balance: uneven" : "Balance: good"
    }

    private static func roomText(_ kind: MicSetupReadinessKind) -> String {
        kind == .noisyRoom ? "Room: noisy" : "Room: quiet enough"
    }
}
