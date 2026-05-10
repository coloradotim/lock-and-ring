import Foundation

@MainActor
extension AppViewModel {
    var canCompareCurrentTake: Bool {
        currentTake != nil && savedTake != nil && currentTake?.id != savedTake?.id
    }

    var recordingReadiness: RecordingReadiness {
        RecordingReadiness(
            inputState: inputManager.state,
            hasKnownInput: !inputManager.devices.isEmpty
        )
    }

    var micSetupReadiness: MicSetupReadinessDisplayState {
        MicSetupReadinessDisplayState(
            inputName: inputManager.selectedInputName,
            inputState: inputManager.state,
            frame: inputManager.latestFrame,
            signal: SignalQualityDisplayState(meters: currentFrame.meters)
        )
    }

    func runMicSetupCheck() {
        micSetupCheckResult = micSetupReadiness
    }
}
