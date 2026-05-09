import Foundation

struct SignalQualityAnalyzer {
    private var previousSpectrum: SpectrumSnapshot?

    mutating func analyze(frame: AudioInputFrame, spectrum: SpectrumSnapshot) -> SignalQualityAssessment {
        defer {
            previousSpectrum = spectrum
        }

        let level = levelAdequacy(for: frame.instrumentation.rmsLevel)
        let signalNoise = signalToNoise(for: frame.instrumentation)
        let stability = spectralStability(current: spectrum, previous: previousSpectrum)
        let transient = transientCleanliness(samples: frame.monoSamples, rmsLevel: frame.instrumentation.rmsLevel)
        let confidence = confidenceMultiplier(
            frame: frame,
            level: level,
            signalNoise: signalNoise,
            stability: stability,
            transient: transient
        )

        return SignalQualityAssessment(
            state: state(
                frame: frame,
                level: level,
                signalNoise: signalNoise,
                stability: stability,
                transient: transient
            ),
            confidenceMultiplier: confidence,
            levelAdequacy: level,
            signalToNoiseRatio: signalNoise,
            spectralStability: stability,
            transientCleanliness: transient,
            reasons: reasons(
                frame: frame,
                level: level,
                signalNoise: signalNoise,
                stability: stability,
                transient: transient
            )
        )
    }

    private func levelAdequacy(for rmsLevel: Float) -> Double {
        let rms = Double(rmsLevel)
        return clamp((rms - 0.005) / 0.045)
    }

    private func signalToNoise(for instrumentation: AudioInputInstrumentation) -> Double {
        let rms = max(Double(instrumentation.rmsLevel), 0.000_001)
        let noise = max(Double(instrumentation.noiseFloor), 0.000_001)
        let decibels = 20 * log10(rms / noise)

        return clamp((decibels - 8) / 24)
    }

    private func spectralStability(
        current: SpectrumSnapshot,
        previous: SpectrumSnapshot?
    ) -> Double {
        guard let previous, !current.peaks.isEmpty, !previous.peaks.isEmpty else {
            return 0.7
        }

        let currentFrequencies = current.peaks.prefix(5).map(\.frequency)
        let previousFrequencies = previous.peaks.prefix(5).map(\.frequency)
        let distances = currentFrequencies.compactMap { frequency in
            previousFrequencies
                .map { abs($0 - frequency) / max(frequency, 1) }
                .min()
        }

        guard !distances.isEmpty else {
            return 0.7
        }

        let averageDistance = distances.reduce(0, +) / Double(distances.count)
        return clamp(1 - averageDistance / 0.08)
    }

    private func transientCleanliness(samples: [Float], rmsLevel: Float) -> Double {
        guard let peak = samples.map({ abs($0) }).max(), rmsLevel > 0 else {
            return 0
        }

        let crestFactor = Double(peak / rmsLevel)
        return clamp(1 - (crestFactor - 6) / 10)
    }

    private func confidenceMultiplier(
        frame: AudioInputFrame,
        level: Double,
        signalNoise: Double,
        stability: Double,
        transient: Double
    ) -> Double {
        var confidence = level * 0.3 + signalNoise * 0.25 + stability * 0.25 + transient * 0.2

        if frame.instrumentation.isClipping {
            confidence = min(confidence, 0.2)
        }

        if !frame.instrumentation.hasSignal {
            confidence = min(confidence, 0.15)
        }

        if frame.instrumentation.hasChannelImbalance {
            confidence *= 0.75
        }

        return clamp(confidence)
    }

    private func state(
        frame: AudioInputFrame,
        level: Double,
        signalNoise: Double,
        stability: Double,
        transient: Double
    ) -> SignalQualityState {
        if frame.instrumentation.isClipping {
            return .clipping
        }

        if level < 0.25 || !frame.instrumentation.hasSignal {
            return .lowSignal
        }

        if signalNoise < 0.3 {
            return .noisy
        }

        if frame.instrumentation.hasChannelImbalance {
            return .imbalanced
        }

        if stability < 0.25 || transient < 0.25 {
            return .unstable
        }

        return .nominal
    }

    private func reasons(
        frame: AudioInputFrame,
        level: Double,
        signalNoise: Double,
        stability: Double,
        transient: Double
    ) -> [String] {
        var reasons: [String] = []

        if frame.instrumentation.isClipping {
            reasons.append("Input clipping")
        }

        if level < 0.25 || !frame.instrumentation.hasSignal {
            reasons.append("Signal too quiet")
        }

        if signalNoise < 0.3 {
            reasons.append("Excessive background noise")
        }

        if frame.instrumentation.hasChannelImbalance {
            reasons.append("Channel imbalance")
        }

        if stability < 0.25 || transient < 0.25 {
            reasons.append("Low confidence")
        }

        return reasons
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

struct SignalQualityAssessment: Equatable, Sendable {
    let state: SignalQualityState
    let confidenceMultiplier: Double
    let levelAdequacy: Double
    let signalToNoiseRatio: Double
    let spectralStability: Double
    let transientCleanliness: Double
    let reasons: [String]

    static let unavailable = SignalQualityAssessment(
        state: .unavailable,
        confidenceMultiplier: 0,
        levelAdequacy: 0,
        signalToNoiseRatio: 0,
        spectralStability: 0,
        transientCleanliness: 0,
        reasons: ["No analysis yet"]
    )

    var displayText: String {
        reasons.first ?? state.displayText
    }

    var isLowConfidence: Bool {
        confidenceMultiplier < 0.55 || state != .nominal
    }
}
