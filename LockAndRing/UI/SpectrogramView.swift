import SwiftUI

struct SpectrogramView: View {
    var title = "Spectrogram"
    let spectrogram: SpectrogramSnapshot
    var duration: Double?
    var cursorProgress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Text("Frequency (Hz)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(-90))
                        .fixedSize()
                        .frame(width: 24, height: 180)

                    VStack {
                        Text("10k")
                        Spacer()
                        Text("5k")
                        Spacer()
                        Text("0")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 180)

                    Canvas { context, size in
                        drawSpectrogram(context: context, size: size)
                        drawCursor(context: context, size: size)
                    }
                    .frame(height: 180)
                    .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
                }

                HStack {
                    Text("0s")
                    Spacer()
                    Text(endTimeLabel)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 56)

                Text("Time (s)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var endTimeLabel: String {
        guard let duration else {
            return "latest"
        }

        return duration.formatted(.number.precision(.fractionLength(1))) + "s"
    }

    private func drawSpectrogram(context: GraphicsContext, size: CGSize) {
        guard !spectrogram.rows.isEmpty else {
            return
        }

        let rowWidth = size.width / Double(max(spectrogram.maxRows, 1))

        for (rowOffset, row) in spectrogram.rows.enumerated() {
            let xPosition = size.width - Double(spectrogram.rows.count - rowOffset) * rowWidth
            let visibleBins = row.filter { $0.frequency >= minimumFrequency && $0.frequency <= maximumFrequency }
            let binHeight = size.height / Double(max(visibleBins.count, 1))

            for bin in visibleBins where bin.magnitude > 0.03 {
                let yPosition = size.height - yPosition(for: bin.frequency, height: size.height)
                let rect = CGRect(
                    x: xPosition,
                    y: yPosition,
                    width: max(1, rowWidth),
                    height: max(1, binHeight)
                )

                context.fill(
                    Path(rect),
                    with: .color(color(for: bin.magnitude))
                )
            }
        }
    }

    private func drawCursor(context: GraphicsContext, size: CGSize) {
        guard let cursorProgress else {
            return
        }

        let xPosition = size.width * min(max(cursorProgress, 0), 1)
        var path = Path()
        path.move(to: CGPoint(x: xPosition, y: 0))
        path.addLine(to: CGPoint(x: xPosition, y: size.height))
        context.stroke(path, with: .color(.white.opacity(0.9)), lineWidth: 2)
    }

    private func color(for magnitude: Double) -> Color {
        switch magnitude {
        case 0.70...:
            .yellow
        case 0.40..<0.70:
            .mint
        case 0.18..<0.40:
            .teal
        default:
            .blue.opacity(0.55)
        }
    }

    private var minimumFrequency: Double {
        0
    }

    private var maximumFrequency: Double {
        10_000
    }

    private func yPosition(for frequency: Double, height: Double) -> Double {
        let clamped = min(max(frequency, minimumFrequency), maximumFrequency)
        return height * clamped / maximumFrequency
    }
}
