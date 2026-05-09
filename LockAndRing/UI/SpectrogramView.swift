import SwiftUI

struct SpectrogramView: View {
    let spectrogram: SpectrogramSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spectrogram")
                .font(.headline)

            Canvas { context, size in
                drawSpectrogram(context: context, size: size)
            }
            .frame(height: 180)
            .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func drawSpectrogram(context: GraphicsContext, size: CGSize) {
        guard !spectrogram.rows.isEmpty else {
            return
        }

        let rowWidth = size.width / Double(max(spectrogram.maxRows, 1))

        for (rowOffset, row) in spectrogram.rows.enumerated() {
            let xPosition = size.width - Double(spectrogram.rows.count - rowOffset) * rowWidth
            let binHeight = size.height / Double(max(row.count, 1))

            for (binIndex, bin) in row.enumerated() where bin.magnitude > 0.03 {
                let yPosition = size.height - Double(binIndex + 1) * binHeight
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
}
