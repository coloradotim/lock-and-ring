import Foundation

struct LockScorer {
    private let maxPartials: Int
    private let minimumFrequency: Double
    private let maximumFrequency: Double
    private let minimumMagnitude: Double
    private let harmonicToleranceCents: Double
    private let ratioToleranceCents: Double

    init(
        maxPartials: Int = 10,
        minimumFrequency: Double = 80,
        maximumFrequency: Double = 5_000,
        minimumMagnitude: Double = 0.08,
        harmonicToleranceCents: Double = 55,
        ratioToleranceCents: Double = 45
    ) {
        self.maxPartials = maxPartials
        self.minimumFrequency = minimumFrequency
        self.maximumFrequency = maximumFrequency
        self.minimumMagnitude = minimumMagnitude
        self.harmonicToleranceCents = harmonicToleranceCents
        self.ratioToleranceCents = ratioToleranceCents
    }

    func score(
        spectrum: SpectrumSnapshot,
        roughness: RoughnessScore,
        stability: StabilityScore
    ) -> LockScore {
        score(
            partials: spectrum.peaks.map {
                SpectralPartial(frequency: $0.frequency, magnitude: $0.magnitude)
            },
            roughness: roughness,
            stability: stability
        )
    }

    func score(
        partials: [SpectralPartial],
        roughness: RoughnessScore,
        stability: StabilityScore
    ) -> LockScore {
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
            return LockScore(
                value: 0,
                confidence: 0,
                harmonicFit: 0,
                simpleRatioFit: 0,
                roughnessPenalty: 1 - roughness.value,
                stabilityContribution: stability.value,
                partialsUsed: usablePartials.count
            )
        }

        let harmonicFit = harmonicFit(for: Array(usablePartials))
        let ratioFit = simpleRatioFit(for: Array(usablePartials))
        let roughnessPenalty = 1 - roughness.value
        let stabilityContribution = stability.value
        let value = harmonicFit * 0.25
            + ratioFit * 0.4
            + roughnessPenalty * 0.2
            + stabilityContribution * 0.15
        let evidence = min(Double(usablePartials.count) / 5, 1)
        let confidence = evidence * (0.45 + stability.confidence * 0.35 + ratioFit * 0.2)

        return LockScore(
            value: value,
            confidence: confidence,
            harmonicFit: harmonicFit,
            simpleRatioFit: ratioFit,
            roughnessPenalty: roughnessPenalty,
            stabilityContribution: stabilityContribution,
            partialsUsed: usablePartials.count
        )
    }

    private func harmonicFit(for partials: [SpectralPartial]) -> Double {
        guard let anchor = partials.first?.frequency else {
            return 0
        }

        let weightedScores = partials.map { partial in
            let multiple = max((partial.frequency / anchor).rounded(), 1)
            let expected = anchor * multiple
            let cents = abs(centsBetween(partial.frequency, expected))
            let score = max(0, 1 - cents / harmonicToleranceCents)
            return (score: score, weight: partial.magnitude)
        }

        return weightedAverage(weightedScores)
    }

    private func simpleRatioFit(for partials: [SpectralPartial]) -> Double {
        let simpleRatios = [
            1.0,
            6.0 / 5.0,
            5.0 / 4.0,
            4.0 / 3.0,
            3.0 / 2.0,
            5.0 / 3.0,
            7.0 / 4.0,
            2.0
        ]
        var pairScores: [(score: Double, weight: Double)] = []

        for firstIndex in partials.indices {
            for secondIndex in partials.indices where secondIndex > firstIndex {
                let lower = partials[firstIndex]
                let upper = partials[secondIndex]
                var ratio = upper.frequency / max(lower.frequency, 1)

                while ratio > 2 {
                    ratio /= 2
                }

                guard let nearest = simpleRatios.min(by: {
                    abs(centsBetween(ratio, $0)) < abs(centsBetween(ratio, $1))
                }) else {
                    continue
                }

                let distance = abs(centsBetween(ratio, nearest))
                let score = max(0, 1 - distance / ratioToleranceCents)
                pairScores.append((score: score, weight: lower.magnitude * upper.magnitude))
            }
        }

        return weightedAverage(pairScores)
    }

    private func centsBetween(_ first: Double, _ second: Double) -> Double {
        1_200 * log2(max(first, 0.000_001) / max(second, 0.000_001))
    }

    private func weightedAverage(_ values: [(score: Double, weight: Double)]) -> Double {
        let totalWeight = values.reduce(0) { $0 + $1.weight }

        guard totalWeight > 0 else {
            return 0
        }

        return values.reduce(0) { $0 + $1.score * $1.weight } / totalWeight
    }
}

struct LockScore: Equatable, Sendable {
    let value: Double
    let confidence: Double
    let harmonicFit: Double
    let simpleRatioFit: Double
    let roughnessPenalty: Double
    let stabilityContribution: Double
    let partialsUsed: Int

    init(
        value: Double,
        confidence: Double,
        harmonicFit: Double,
        simpleRatioFit: Double,
        roughnessPenalty: Double,
        stabilityContribution: Double,
        partialsUsed: Int
    ) {
        self.value = min(max(value, 0), 1)
        self.confidence = min(max(confidence, 0), 1)
        self.harmonicFit = min(max(harmonicFit, 0), 1)
        self.simpleRatioFit = min(max(simpleRatioFit, 0), 1)
        self.roughnessPenalty = min(max(roughnessPenalty, 0), 1)
        self.stabilityContribution = min(max(stabilityContribution, 0), 1)
        self.partialsUsed = partialsUsed
    }

    func metricSnapshot(signalQuality: SignalQualityState = .nominal) -> MetricSnapshot {
        MetricSnapshot(
            kind: .lock,
            score: MetricScore(value: value),
            confidence: MetricConfidence(
                value: confidence,
                reason: confidence > 0 ? "Based on simple-ratio fit, harmonic organization, roughness, and stability." : "Not enough partials."
            ),
            contributingFactors: [
                MetricFactor(name: "Harmonic fit", value: harmonicFit, weight: 0.25),
                MetricFactor(name: "Simple ratio fit", value: simpleRatioFit, weight: 0.4),
                MetricFactor(name: "Low roughness", value: roughnessPenalty, weight: 0.2),
                MetricFactor(name: "Stability", value: stabilityContribution, weight: 0.15)
            ],
            rawMeasurements: [
                "harmonicFit": harmonicFit,
                "simpleRatioFit": simpleRatioFit,
                "roughnessPenalty": roughnessPenalty,
                "stabilityContribution": stabilityContribution,
                "partialsUsed": Double(partialsUsed)
            ],
            signalQuality: signalQuality
        )
    }
}
