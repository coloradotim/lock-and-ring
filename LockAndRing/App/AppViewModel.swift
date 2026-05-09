import Foundation

@MainActor
@Observable
final class AppViewModel {
    var inputManager: AudioInputManager
    var currentFrame: AnalysisFrame
    private let spectrumAnalyzer: SpectrumAnalyzer
    private let roughnessScorer: RoughnessScorer

    init(
        inputManager: AudioInputManager? = nil,
        currentFrame: AnalysisFrame = .placeholder
    ) {
        self.inputManager = inputManager ?? AudioInputManager()
        self.currentFrame = currentFrame
        self.spectrumAnalyzer = SpectrumAnalyzer()
        self.roughnessScorer = RoughnessScorer()
        self.inputManager.onFrame = { [weak self] frame in
            self?.analyze(frame)
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
        currentFrame = AnalysisFrame(
            timestamp: Date(),
            meters: currentFrame.meters.replacingRoughness(with: roughness.value),
            spectrum: spectrum,
            spectrogram: currentFrame.spectrogram.appending(spectrum)
        )
    }
}
