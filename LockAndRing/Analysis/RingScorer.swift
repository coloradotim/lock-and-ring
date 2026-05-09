import Foundation

struct RingScorer {
    private let minimumFundamental: Double
    private let maximumFundamental: Double
    private let harmonicTolerance: Double
    private let maxHarmonic: Int
    private let minimumMagnitude: Double

    init(
        minimumFundamental: Double = 80,
        maximumFundamental: Double = 800,
        harmonicTolerance: Double = 0.035,
        maxHarmonic: Int = 8,
        minimumMagnitude: Double = 0.06
    ) {
        self.minimumFundamental = minimumFundamental
        self.maximumFundamental = maximumFundamental
        self.harmonicTolerance = harmonicTolerance
        self.maxHarmonic = maxHarmonic
        self.minimumMagnitude = minimumMagnitude
    }

    func score(spectrum: SpectrumSnapshot) -> RingScore {
        score(partials: partials(from: spectrum))
    }

    func score(partials: [SpectralPartial]) -> RingScore {
        let usablePartials = partials
            .filter { $0.frequency >= minimumFundamental && $0.magnitude >= minimumMagnitude }
            .sorted { $0.frequency < $1.frequency }

        guard let anchor = anchorPartial(from: usablePartials) else {
            return RingScore(
                value: 0,
                confidence: 0,
                harmonicEnergyRatio: 0,
                matchedHarmonics: 0
            )
        }

        let harmonicMatches = harmonicMatches(for: anchor.frequency, in: usablePartials)
        let upperHarmonics = harmonicMatches.filter { $0.harmonicNumber >= 2 }
        let harmonicEnergy = harmonicMatches.reduce(0) { $0 + $1.partial.magnitude }
        let totalEnergy = usablePartials.reduce(0) { $0 + $1.magnitude }
        let harmonicEnergyRatio = totalEnergy > 0 ? harmonicEnergy / totalEnergy : 0
        let coverage = Double(upperHarmonics.count) / Double(max(maxHarmonic - 1, 1))
        let upperStrength = upperHarmonics.reduce(0) { $0 + $1.partial.magnitude }
        let expectedStrength = Double(max(upperHarmonics.count, 1))
        let upperReinforcement = min(upperStrength / expectedStrength, 1)
        let alignment = averageAlignmentScore(for: harmonicMatches, anchorFrequency: anchor.frequency)
        let confidence = min(harmonicEnergyRatio * 0.65 + coverage * 0.35, 1)
        let score = sqrt(coverage) * upperReinforcement * alignment * confidence

        return RingScore(
            value: score,
            confidence: confidence,
            harmonicEnergyRatio: harmonicEnergyRatio,
            matchedHarmonics: upperHarmonics.count
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

    private func anchorPartial(from partials: [SpectralPartial]) -> SpectralPartial? {
        partials
            .filter { $0.frequency <= maximumFundamental }
            .max { $0.magnitude < $1.magnitude }
    }

    private func harmonicMatches(
        for anchorFrequency: Double,
        in partials: [SpectralPartial]
    ) -> [HarmonicMatch] {
        (1...maxHarmonic).compactMap { harmonicNumber in
            let expectedFrequency = anchorFrequency * Double(harmonicNumber)
            let tolerance = expectedFrequency * harmonicTolerance

            guard let partial = partials
                .filter({ abs($0.frequency - expectedFrequency) <= tolerance })
                .max(by: { $0.magnitude < $1.magnitude }) else {
                return nil
            }

            return HarmonicMatch(harmonicNumber: harmonicNumber, partial: partial)
        }
    }

    private func averageAlignmentScore(
        for matches: [HarmonicMatch],
        anchorFrequency: Double
    ) -> Double {
        guard !matches.isEmpty else {
            return 0
        }

        let scores = matches.map { match in
            let expectedFrequency = anchorFrequency * Double(match.harmonicNumber)
            let distance = abs(match.partial.frequency - expectedFrequency)
            let tolerance = max(expectedFrequency * harmonicTolerance, 1)
            return max(0, 1 - distance / tolerance)
        }

        return scores.reduce(0, +) / Double(scores.count)
    }
}

struct RingScore: Equatable, Sendable {
    let value: Double
    let confidence: Double
    let harmonicEnergyRatio: Double
    let matchedHarmonics: Int

    init(
        value: Double,
        confidence: Double,
        harmonicEnergyRatio: Double,
        matchedHarmonics: Int
    ) {
        self.value = min(max(value, 0), 1)
        self.confidence = min(max(confidence, 0), 1)
        self.harmonicEnergyRatio = min(max(harmonicEnergyRatio, 0), 1)
        self.matchedHarmonics = matchedHarmonics
    }
}

private struct HarmonicMatch {
    let harmonicNumber: Int
    let partial: SpectralPartial
}
