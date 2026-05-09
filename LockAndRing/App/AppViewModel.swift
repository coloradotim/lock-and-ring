import Foundation

@MainActor
@Observable
final class AppViewModel {
    var inputManager: AudioInputManager
    var offlineAnalyzer: OfflineAudioAnalyzer
    var currentFrame: AnalysisFrame
    private let spectrumAnalyzer: SpectrumAnalyzer
    private let roughnessScorer: RoughnessScorer
    private let ringScorer: RingScorer

    init(
        inputManager: AudioInputManager? = nil,
        offlineAnalyzer: OfflineAudioAnalyzer? = nil,
        currentFrame: AnalysisFrame = .placeholder
    ) {
        self.inputManager = inputManager ?? AudioInputManager()
        self.offlineAnalyzer = offlineAnalyzer ?? OfflineAudioAnalyzer()
        self.currentFrame = currentFrame
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
        inputManager.stop()
    }

    private func analyze(_ frame: AudioInputFrame) {
        let spectrum = spectrumAnalyzer.analyze(
            samples: frame.monoSamples,
            sampleRate: frame.sampleRate
        )
        let roughness = roughnessScorer.score(spectrum: spectrum)
        let ring = ringScorer.score(spectrum: spectrum)
        currentFrame = AnalysisFrame(
            timestamp: Date(),
            meters: currentFrame.meters
                .replacingRoughness(with: roughness.value)
                .replacingRing(with: ring.value),
            spectrum: spectrum,
            spectrogram: currentFrame.spectrogram.appending(spectrum),
            ringHistory: currentFrame.ringHistory.appending(ring)
        )
    }
}
