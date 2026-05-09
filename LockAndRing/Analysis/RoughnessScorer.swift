import Foundation

struct RoughnessScorer {
    private let maxPartials: Int
    private let minimumFrequency: Double
    private let maximumFrequency: Double
    private let minimumMagnitude: Double
    private let normalizationGain: Double

    init(
        maxPartials: Int = 10,
        minimumFrequency: Double = 80,
        maximumFrequency: Double = 5_000,
        minimumMagnitude: Double = 0.08,
        normalizationGain: Double = 0.18
    ) {
        self.maxPartials = maxPartials
        self.minimumFrequency = minimumFrequency
        self.maximumFrequency = maximumFrequency
        self.minimumMagnitude = minimumMagnitude
        self.normalizationGain = normalizationGain
    }

    func score(spectrum: SpectrumSnapshot) -> RoughnessScore {
        score(partials: partials(from: spectrum))
    }

    func score(partials: [SpectralPartial]) -> RoughnessScore {
        let usablePartials = partials
            .filter { partial in
                partial.frequency >= minimumFrequency
                    && partial.frequency <= maximumFrequency
                    && partial.magnitude >= minimumMagnitude
            }
            .sorted { $0.magnitude > $1.magnitude }
            .prefix(maxPartials)
            .sorted { $0.frequency < $1.frequency }

        guard usablePartials.count >= 2 else {
            return RoughnessScore(value: 0, rawPairInteraction: 0, partialsUsed: usablePartials.count)
        }

        let rawRoughness = pairInteractions(for: Array(usablePartials))
        let normalizedScore = 1 - exp(-rawRoughness * normalizationGain)

        return RoughnessScore(
            value: normalizedScore,
            rawPairInteraction: rawRoughness,
            partialsUsed: usablePartials.count
        )
    }

    private func partials(from spectrum: SpectrumSnapshot) -> [SpectralPartial] {
        spectrum.peaks.map { peak in
            SpectralPartial(
                frequency: peak.frequency,
                magnitude: peak.magnitude
            )
        }
    }

    private func pairInteractions(for partials: [SpectralPartial]) -> Double {
        var roughness = 0.0

        for firstIndex in partials.indices {
            for secondIndex in partials.indices where secondIndex > firstIndex {
                roughness += interaction(
                    first: partials[firstIndex],
                    second: partials[secondIndex]
                )
            }
        }

        return roughness
    }

    private func interaction(first: SpectralPartial, second: SpectralPartial) -> Double {
        let lowerFrequency = min(first.frequency, second.frequency)
        let frequencyDistance = abs(first.frequency - second.frequency)
        let criticalBandwidthScale = 0.24 / (0.021 * lowerFrequency + 19)
        let scaledDistance = criticalBandwidthScale * frequencyDistance
        let curve = exp(-3.5 * scaledDistance) - exp(-5.75 * scaledDistance)

        return max(curve, 0) * first.magnitude * second.magnitude
    }
}

struct SpectralPartial: Equatable, Sendable {
    let frequency: Double
    let magnitude: Double

    init(frequency: Double, magnitude: Double) {
        self.frequency = frequency
        self.magnitude = min(max(magnitude, 0), 1)
    }
}

struct RoughnessScore: Equatable, Sendable {
    let value: Double
    let rawPairInteraction: Double
    let partialsUsed: Int

    init(value: Double, rawPairInteraction: Double, partialsUsed: Int) {
        self.value = min(max(value, 0), 1)
        self.rawPairInteraction = max(rawPairInteraction, 0)
        self.partialsUsed = partialsUsed
    }

    func metricSnapshot(signalQuality: SignalQualityState = .nominal) -> MetricSnapshot {
        let confidenceValue = partialsUsed >= 2 ? min(Double(partialsUsed) / 6, 1) : 0

        return MetricSnapshot(
            kind: .roughness,
            score: MetricScore(value: value),
            confidence: MetricConfidence(
                value: confidenceValue,
                reason: confidenceValue > 0 ? "Based on pairwise partial interactions." : "Not enough partials."
            ),
            contributingFactors: [
                MetricFactor(name: "Pair interaction", value: min(rawPairInteraction, 1)),
                MetricFactor(name: "Partials used", value: min(Double(partialsUsed) / 10, 1))
            ],
            rawMeasurements: [
                "rawPairInteraction": rawPairInteraction,
                "partialsUsed": Double(partialsUsed)
            ],
            signalQuality: signalQuality
        )
    }
}
