import AVFoundation
import Foundation

@MainActor
@Observable
final class AppViewModel {
    var inputManager: AudioInputManager
    var offlineAnalyzer: OfflineAudioAnalyzer
    var currentFrame: AnalysisFrame
    var takeRecorder: TakeRecorder
    var takeLibrary: SavedTakeLibrary
    var workflowState: MainWorkflowState = .ready
    var currentTake: RecordedTake?
    var selectedRegion: TakeRegion?
    var analysisRegion: TakeRegion?
    var regionDraftStart: TimeInterval = 0
    var regionDraftEnd: TimeInterval = 0
    var savedTake: RecordedTake?
    var savedTakes: [SavedTake]
    var libraryErrorMessage: String?
    var micSetupCheckResult: MicSetupReadinessDisplayState?
    var meterHistory: [MeterSnapshot]
    var latestAnalysisInputFrame: AudioInputFrame?
    var currentTakePlayback = TakePlaybackState()
    var takePlaybackTask: Task<Void, Never>?
    var audioPlayer: AVAudioPlayer?
    var temporaryPlaybackURL: URL?
    var currentTakePlayer: AVAudioPlayer?
    var currentTakePlaybackURL: URL?
    var currentTakePlaybackTask: Task<Void, Never>?
    var analysisScorer: CompositeAnalysisScorer
    let offlineFrameSize = 2_048

    init(
        inputManager: AudioInputManager? = nil,
        offlineAnalyzer: OfflineAudioAnalyzer? = nil,
        currentFrame: AnalysisFrame = .placeholder,
        takeRecorder: TakeRecorder? = nil,
        takeLibrary: SavedTakeLibrary = SavedTakeLibrary()
    ) {
        self.inputManager = inputManager ?? AudioInputManager()
        self.offlineAnalyzer = offlineAnalyzer ?? OfflineAudioAnalyzer()
        self.currentFrame = currentFrame
        self.takeRecorder = takeRecorder ?? TakeRecorder()
        self.takeLibrary = takeLibrary
        self.meterHistory = [currentFrame.meters]
        self.savedTakes = (try? takeLibrary.load()) ?? []
        self.analysisScorer = CompositeAnalysisScorer()
        self.inputManager.onFrame = { [weak self] frame in
            self?.analyze(frame)
        }
        self.offlineAnalyzer.onFrame = { [weak self] frame in
            self?.analyze(frame)
        }
        self.offlineAnalyzer.onPlaybackStarted = { [weak self] in
            self?.stopAudio()
        }
        self.offlineAnalyzer.onPlaybackStopped = { [weak self] in
            self?.startAudio()
        }
    }

    func startAudio() {
        inputManager.start()
    }

    func stopAudio() {
        takePlaybackTask?.cancel()
        takePlaybackTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        cleanupTemporaryPlaybackFile()
        stopCurrentTakePlayback(resetTime: false, restartInput: false)
        cleanupCurrentTakePlaybackFile()
        inputManager.stop()
    }

    func startPrimaryTakeRecording() {
        startTakeRecording(slot: .takeA)
    }

    func startTakeRecording(slot: TakeSlot = .takeA) {
        takePlaybackTask?.cancel()
        takePlaybackTask = nil
        replaceCurrentTake(nil)
        startAudio()
        takeRecorder.startRecording(slot: slot)
        workflowState = .recording(startedAt: takeRecorder.recordingStartedAt ?? Date())
    }

    func stopTakeRecording() {
        takeRecorder.finishRecording()
        replaceCurrentTake(takeRecorder.take(for: .takeA))
        inputManager.stop()
        workflowState = currentTake == nil ? .ready : .reviewingTake
    }

    func clearTake(slot: TakeSlot) {
        takeRecorder.clear(slot: slot)
        if slot == .takeA {
            replaceCurrentTake(nil)
        }
    }

    func saveCurrentTake() {
        guard let currentTake else {
            return
        }

        do {
            _ = try takeLibrary.save(currentTake)
            savedTake = currentTake
            reloadSavedTakes()
        } catch {
            libraryErrorMessage = error.localizedDescription
        }
    }

    func discardCurrentTake() {
        replaceCurrentTake(nil)
        takeRecorder.clear(slot: .takeA)
        workflowState = .ready
        startAudio()
    }

    func reviewCurrentTake() {
        workflowState = currentTake == nil ? .ready : .reviewingTake
    }

    func compareCurrentTake() {
        workflowState = canCompareCurrentTake ? .comparing : .reviewingTake
    }

}
