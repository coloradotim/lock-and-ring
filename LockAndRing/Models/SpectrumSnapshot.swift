import Foundation

struct SpectrumSnapshot: Equatable, Sendable {
    let sampleRate: Double
    let fftSize: Int
    let bins: [SpectrumBin]
    let peaks: [SpectrumPeak]

    init(
        sampleRate: Double,
        fftSize: Int,
        bins: [SpectrumBin],
        peaks: [SpectrumPeak] = []
    ) {
        self.sampleRate = sampleRate
        self.fftSize = fftSize
        self.bins = bins
        self.peaks = peaks
    }

    static let placeholder = SpectrumSnapshot(
        sampleRate: 44_100,
        fftSize: 24,
        bins: [
            0.18, 0.28, 0.42, 0.36,
            0.58, 0.44, 0.72, 0.53,
            0.38, 0.26, 0.19, 0.12
        ].enumerated().map { index, magnitude in
            SpectrumBin(
                frequency: Double(index) * 120,
                magnitude: magnitude
            )
        }
    )
}

struct SpectrumBin: Equatable, Sendable {
    let frequency: Double
    let magnitude: Double

    init(frequency: Double, magnitude: Double) {
        self.frequency = frequency
        self.magnitude = min(max(magnitude, 0), 1)
    }
}

struct SpectrumPeak: Equatable, Sendable {
    let frequency: Double
    let magnitude: Double
    let binIndex: Int
}

struct SpectrogramSnapshot: Equatable, Sendable {
    let rows: [[SpectrumBin]]
    let maxRows: Int

    init(rows: [[SpectrumBin]] = [], maxRows: Int = 80) {
        self.maxRows = maxRows
        self.rows = Array(rows.suffix(maxRows))
    }

    func appending(_ spectrum: SpectrumSnapshot, maxBins: Int = 96) -> SpectrogramSnapshot {
        let binStride = max(spectrum.bins.count / maxBins, 1)
        let reducedBins = Swift.stride(from: 0, to: spectrum.bins.count, by: binStride).map { index in
            spectrum.bins[index]
        }
        return SpectrogramSnapshot(rows: rows + [reducedBins], maxRows: maxRows)
    }

    static let placeholder = SpectrogramSnapshot(
        rows: [
            SpectrumSnapshot.placeholder.bins
        ]
    )
}
