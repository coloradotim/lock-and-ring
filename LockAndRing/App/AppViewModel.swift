import Foundation

@MainActor
@Observable
final class AppViewModel {
    var inputManager: AudioInputManager
    var offlineAnalyzer: OfflineAudioAnalyzer
    var currentFrame: AnalysisFrame
    var takeRecorder: TakeRecorder
    private var takePlaybackTask: Task<Void, Never>?
    private let spectrumAnalyzer: SpectrumAnalyzer
    private let roughnessScorer: RoughnessScorer
    private let ringScorer: RingScorer

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
        self.spectrumAnalyzer = SpectrumAnalyzer()
        self.roughnessScorer = RoughnessScorer()
        self.ringScorer = RingScorer()
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
        let spectrum = spectrumAnalyzer.analyze(
            samples: frame.monoSamples,
            sampleRate: frame.sampleRate
        )
        let roughness = roughnessScorer.score(spectrum: spectrum)
        let ring = ringScorer.score(spectrum: spectrum)
        let analyzedFrame = AnalysisFrame(
            timestamp: Date(),
            meters: currentFrame.meters
                .replacingRoughness(with: roughness.metricSnapshot(signalQuality: signalQuality(for: frame)))
                .replacingRing(with: ring.metricSnapshot(signalQuality: signalQuality(for: frame))),
            spectrum: spectrum,
            spectrogram: currentFrame.spectrogram.appending(spectrum),
            ringHistory: currentFrame.ringHistory.appending(ring)
        )
        currentFrame = analyzedFrame
        takeRecorder.record(analyzedFrame)
    }

    private func signalQuality(for frame: AudioInputFrame) -> SignalQualityState {
        if frame.instrumentation.isClipping {
            return .clipping
        }

        if frame.instrumentation.hasChannelImbalance {
            return .imbalanced
        }

        if !frame.instrumentation.hasSignal {
            return .lowSignal
        }

        return .nominal
    }
}
