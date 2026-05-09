import SwiftUI

struct SpectrumView: View {
    let spectrum: SpectrumSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Spectrum")
                    .font(.headline)

                Spacer()

                Text(peakSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .bottomLeading) {
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(Array(displayBins.enumerated()), id: \.offset) { _, bin in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(binColor(for: bin))
                                .frame(
                                    width: barWidth(in: geometry.size.width),
                                    height: max(3, geometry.size.height * bin.magnitude)
                                )
                        }
                    }

                    ForEach(spectrum.peaks, id: \.binIndex) { peak in
                        peakMarker(for: peak, in: geometry.size)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .frame(height: 160)
            .padding()
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var displayBins: [SpectrumBin] {
        let maxBins = 120
        let binStride = max(spectrum.bins.count / maxBins, 1)
        return Swift.stride(from: 0, to: spectrum.bins.count, by: binStride).map { index in
            spectrum.bins[index]
        }
    }

    private var peakSummary: String {
        guard let strongestPeak = spectrum.peaks.max(by: { $0.magnitude < $1.magnitude }) else {
            return "No peaks"
        }

        return "\(Int(strongestPeak.frequency.rounded())) Hz peak"
    }

    private func barWidth(in availableWidth: Double) -> Double {
        let spacingWidth = Double(max(displayBins.count - 1, 0)) * 2
        let rawWidth = (availableWidth - spacingWidth) / Double(max(displayBins.count, 1))
        return max(2, rawWidth)
    }

    private func binColor(for bin: SpectrumBin) -> LinearGradient {
        if isNearPeak(bin) {
            return LinearGradient(colors: [.mint, .teal], startPoint: .top, endPoint: .bottom)
        }

        if bin.frequency < 400 {
            return LinearGradient(colors: [.blue, .teal], startPoint: .top, endPoint: .bottom)
        }

        if bin.frequency < 2_000 {
            return LinearGradient(colors: [.teal, .cyan], startPoint: .top, endPoint: .bottom)
        }

        return LinearGradient(colors: [.indigo, .blue], startPoint: .top, endPoint: .bottom)
    }

    private func isNearPeak(_ bin: SpectrumBin) -> Bool {
        spectrum.peaks.contains { peak in
            abs(peak.frequency - bin.frequency) < frequencyResolution * 1.5
        }
    }

    private var frequencyResolution: Double {
        spectrum.sampleRate / Double(max(spectrum.fftSize, 1))
    }

    private func peakMarker(for peak: SpectrumPeak, in size: CGSize) -> some View {
        let maxFrequency = spectrum.sampleRate / 2
        let xPosition = size.width * min(max(peak.frequency / maxFrequency, 0), 1)

        return Rectangle()
            .fill(.white.opacity(0.85))
            .frame(width: 2, height: size.height)
            .offset(x: xPosition)
    }
}
