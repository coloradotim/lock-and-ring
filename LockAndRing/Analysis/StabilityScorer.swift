import Foundation

struct StabilityScorer {
    private var previousSpectrum: SpectrumSnapshot?

    mutating func score(spectrum: SpectrumSnapshot) -> StabilityScore {
        defer {
            previousSpectrum = spectrum
        }

        let evidence = evidence(for: spectrum)

        guard let previousSpectrum else {
            return StabilityScore(
                value: 0.55,
                confidence: evidence * 0.5,
                peakDriftCents: 0,
                peakPersistence: 0.5,
                energyChange: 0.5,
                peaksUsed: usablePeaks(in: spectrum).count
            )
        }

        let currentPeaks = usablePeaks(in: spectrum)
        let previousPeaks = usablePeaks(in: previousSpectrum)
        let persistence = peakPersistence(current: currentPeaks, previous: previousPeaks)
        let drift = peakDriftCents(current: currentPeaks, previous: previousPeaks)
        let energyChange = energyDistributionChange(current: spectrum.bins, previous: previousSpectrum.bins)
        let driftScore = 1 - min(drift / 85, 1)
        let energyScore = 1 - min(energyChange / 0.22, 1)
        let score = persistence * 0.45 + driftScore * 0.35 + energyScore * 0.2
        let confidence = evidence * (0.45 + persistence * 0.35 + driftScore * 0.2)

        return StabilityScore(
            value: score,
            confidence: confidence,
            peakDriftCents: drift,
            peakPersistence: persistence,
            energyChange: energyChange,
            peaksUsed: currentPeaks.count
        )
    }

    private func usablePeaks(in spectrum: SpectrumSnapshot) -> [SpectrumPeak] {
        Array(
            spectrum.peaks
                .filter { $0.frequency >= 80 && $0.frequency <= 5_000 && $0.magnitude >= 0.08 }
                .sorted { $0.magnitude > $1.magnitude }
                .prefix(8)
        )
    }

    private func evidence(for spectrum: SpectrumSnapshot) -> Double {
        let peaks = usablePeaks(in: spectrum)
        let peakEvidence = min(Double(peaks.count) / 5, 1)
        let concentratedEnergy = min(peaks.reduce(0) { $0 + $1.magnitude } / 3, 1)

        return peakEvidence * 0.65 + concentratedEnergy * 0.35
    }

    private func peakPersistence(current: [SpectrumPeak], previous: [SpectrumPeak]) -> Double {
        guard !current.isEmpty, !previous.isEmpty else {
            return 0
        }

        let persisted = current.filter { currentPeak in
            previous.contains { previousPeak in
                relativeDistance(currentPeak.frequency, previousPeak.frequency) <= 0.035
            }
        }

        return Double(persisted.count) / Double(current.count)
    }

    private func peakDriftCents(current: [SpectrumPeak], previous: [SpectrumPeak]) -> Double {
        let drifts = current.compactMap { currentPeak -> Double? in
            guard let nearest = previous.min(by: {
                relativeDistance(currentPeak.frequency, $0.frequency)
                    < relativeDistance(currentPeak.frequency, $1.frequency)
            }) else {
                return nil
            }

            return abs(1_200 * log2(max(currentPeak.frequency, 1) / max(nearest.frequency, 1)))
        }

        guard !drifts.isEmpty else {
            return 120
        }

        return drifts.reduce(0, +) / Double(drifts.count)
    }

    private func energyDistributionChange(current: [SpectrumBin], previous: [SpectrumBin]) -> Double {
        let count = min(current.count, previous.count, 128)
        guard count > 0 else {
            return 1
        }

        let changes = zip(current.prefix(count), previous.prefix(count)).map { currentBin, previousBin in
            abs(currentBin.magnitude - previousBin.magnitude)
        }

        return changes.reduce(0, +) / Double(count)
    }

    private func relativeDistance(_ first: Double, _ second: Double) -> Double {
        abs(first - second) / max(first, 1)
    }
}

struct StabilityScore: Equatable, Sendable {
    let value: Double
    let confidence: Double
    let peakDriftCents: Double
    let peakPersistence: Double
    let energyChange: Double
    let peaksUsed: Int

    init(
        value: Double,
        confidence: Double,
        peakDriftCents: Double,
        peakPersistence: Double,
        energyChange: Double,
        peaksUsed: Int
    ) {
        self.value = min(max(value, 0), 1)
        self.confidence = min(max(confidence, 0), 1)
        self.peakDriftCents = max(peakDriftCents, 0)
        self.peakPersistence = min(max(peakPersistence, 0), 1)
        self.energyChange = max(energyChange, 0)
        self.peaksUsed = peaksUsed
    }

    func metricSnapshot(signalQuality: SignalQualityState = .nominal) -> MetricSnapshot {
        MetricSnapshot(
            kind: .stability,
            score: MetricScore(value: value),
            confidence: MetricConfidence(
                value: confidence,
                reason: "Based on peak persistence, peak drift, and spectral energy change."
            ),
            contributingFactors: [
                MetricFactor(name: "Peak persistence", value: peakPersistence, weight: 0.45),
                MetricFactor(name: "Low peak drift", value: 1 - min(peakDriftCents / 85, 1), weight: 0.35),
                MetricFactor(name: "Energy consistency", value: 1 - min(energyChange / 0.22, 1), weight: 0.2)
            ],
            rawMeasurements: [
                "peakDriftCents": peakDriftCents,
                "peakPersistence": peakPersistence,
                "energyChange": energyChange,
                "peaksUsed": Double(peaksUsed)
            ],
            signalQuality: signalQuality
        )
    }
}
