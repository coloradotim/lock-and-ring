import SwiftUI

struct SpectrumView: View {
    var title = "Spectrum"
    let spectrum: SpectrumSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)

                Spacer()

                Text(peakSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Text("Level (dB)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(-90))
                        .fixedSize()
                        .frame(width: 24, height: 160)

                    VStack {
                        Text("70")
                        Spacer()
                        Text("35")
                        Spacer()
                        Text("0")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 160)

                    Canvas { context, size in
                        drawGrid(context: context, size: size)
                        drawSpectrum(context: context, size: size)
                        drawPeaks(context: context, size: size)
                    }
                    .frame(height: 160)
                }

                HStack {
                    ForEach(frequencyTicks, id: \.self) { tick in
                        Text(tickLabel(tick))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                Text("Frequency (Hz)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var displayBins: [SpectrumBin] {
        spectrum.bins.filter { bin in
            bin.frequency >= minimumFrequency && bin.frequency <= maximumFrequency
        }
    }

    private var peakSummary: String {
        guard let strongestPeak = spectrum.peaks.max(by: { $0.magnitude < $1.magnitude }) else {
            return "No peaks"
        }

        return "\(Int(strongestPeak.frequency.rounded())) Hz peak"
    }

    private func binColor(for bin: SpectrumBin) -> Color {
        if isNearPeak(bin) {
            return .mint
        }

        if bin.frequency < 400 {
            return .teal
        }

        if bin.frequency < 2_000 {
            return .cyan
        }

        return .blue
    }

    private func isNearPeak(_ bin: SpectrumBin) -> Bool {
        spectrum.peaks.contains { peak in
            abs(peak.frequency - bin.frequency) < frequencyResolution * 1.5
        }
    }

    private var frequencyResolution: Double {
        spectrum.sampleRate / Double(max(spectrum.fftSize, 1))
    }

    private var minimumFrequency: Double {
        25
    }

    private var maximumFrequency: Double {
        min(10_000, spectrum.sampleRate / 2)
    }

    private var maximumDecibels: Double {
        70
    }

    private var frequencyTicks: [Double] {
        [25, 50, 100, 200, 500, 1_000, 2_000, 5_000, 10_000]
            .filter { $0 <= maximumFrequency }
    }

    private func tickLabel(_ frequency: Double) -> String {
        if frequency >= 1_000 {
            return "\(Int(frequency / 1_000))k"
        }

        return "\(Int(frequency))"
    }

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        for tick in frequencyTicks {
            let xPosition = xPosition(for: tick, width: size.width)
            let path = Path(CGRect(x: xPosition, y: 0, width: 1, height: size.height))
            context.fill(path, with: .color(.secondary.opacity(0.16)))
        }
    }

    private func drawSpectrum(context: GraphicsContext, size: CGSize) {
        let barWidth = max(1, size.width / Double(max(displayBins.count, 1)))

        for bin in displayBins {
            let decibels = decibels(for: bin.magnitude)
            let height = max(2, size.height * decibels / maximumDecibels)
            let xPosition = xPosition(for: bin.frequency, width: size.width)
            let rect = CGRect(
                x: xPosition - barWidth / 2,
                y: size.height - height,
                width: barWidth,
                height: height
            )
            context.fill(Path(rect), with: .color(binColor(for: bin)))
        }
    }

    private func drawPeaks(context: GraphicsContext, size: CGSize) {
        for peak in spectrum.peaks where peak.frequency >= minimumFrequency && peak.frequency <= maximumFrequency {
            let xPosition = xPosition(for: peak.frequency, width: size.width)
            let rect = CGRect(x: xPosition, y: 0, width: 2, height: size.height)
            context.fill(Path(rect), with: .color(.white.opacity(0.85)))
        }
    }

    private func xPosition(for frequency: Double, width: Double) -> Double {
        let clamped = min(max(frequency, minimumFrequency), maximumFrequency)
        let minLog = log10(minimumFrequency)
        let maxLog = log10(maximumFrequency)
        let position = (log10(clamped) - minLog) / (maxLog - minLog)
        return width * min(max(position, 0), 1)
    }

    private func decibels(for magnitude: Double) -> Double {
        let normalized = max(magnitude, 0.000_1)
        let decibels = maximumDecibels + 20 * log10(normalized)
        return min(max(decibels, 0), maximumDecibels)
    }
}
