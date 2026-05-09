import Foundation

@MainActor
@Observable
final class AppViewModel {
    var inputManager: AudioInputManager
    var offlineAnalyzer: OfflineAudioAnalyzer
    var currentFrame: AnalysisFrame
    var takeRecorder: TakeRecorder
    var meterHistory: [MeterSnapshot]
    var latestAnalysisInputFrame: AudioInputFrame?
    private var takePlaybackTask: Task<Void, Never>?
    private var analysisScorer: CompositeAnalysisScorer

    init(
        inputManager: AudioInputManager? = nil,
        offlineAnalyzer: OfflineAudioAnalyzer? = nil,
        currentFrame: AnalysisFrame = .placeholder,
        takeRecorder: TakeRecorder? = nil
    ) {
        self.inputManager = inputManager ?? AudioInputManager()
        self.offlineAnalyzer = offlineAnalyzer ?? OfflineAudioAnalyzer()
        self.currentFrame = currentFrame
        self.takeRecorder = takeRecorder ?? TakeRecorder()
        self.meterHistory = [currentFrame.meters]
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
        inputManager.stop()
    }

    func startTakeRecording(slot: TakeSlot) {
        takePlaybackTask?.cancel()
        takePlaybackTask = nil
        startAudio()
        takeRecorder.startRecording(slot: slot)
    }

    func stopTakeRecording() {
        takeRecorder.finishRecording()
    }

    func clearTake(slot: TakeSlot) {
        takeRecorder.clear(slot: slot)
    }

    func playTake(slot: TakeSlot) {
        guard let take = takeRecorder.take(for: slot), !take.frames.isEmpty else {
            return
        }

        takePlaybackTask?.cancel()
        inputManager.stop()
        takePlaybackTask = Task { [weak self] in
            for frame in take.frames {
                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    self?.currentFrame = frame
                }

                try? await Task.sleep(nanoseconds: 50_000_000)
            }

            await MainActor.run {
                self?.takePlaybackTask = nil
                self?.startAudio()
            }
        }
    }

    private func analyze(_ frame: AudioInputFrame) {
        let result = analysisScorer.score(frame: frame)
        let analyzedFrame = AnalysisFrame(
            timestamp: Date(),
            meters: result.meters,
            spectrum: result.spectrum,
            spectrogram: currentFrame.spectrogram.appending(result.spectrum),
            ringHistory: currentFrame.ringHistory.appending(result.ring)
        )
        currentFrame = analyzedFrame
        latestAnalysisInputFrame = frame
        meterHistory = Array((meterHistory + [result.meters]).suffix(64))
        takeRecorder.record(analyzedFrame)
    }
}
