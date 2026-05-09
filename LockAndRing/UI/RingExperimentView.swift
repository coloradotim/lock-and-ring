import SwiftUI

struct RingExperimentView: View {
    let trend: RingTrendSnapshot
    let meters: MeterSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ring Experiment")
                    .font(.headline)

                Spacer()

                Text(confidenceText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 18) {
                ringTrend
                ringRoughnessPlot
                confidenceMeter
            }
        }
        .padding()
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }

    private var ringTrend: some View {
        Canvas { context, size in
            guard trend.scores.count >= 2 else {
                return
            }

            var path = Path()
            for (index, score) in trend.scores.enumerated() {
                let xPosition = Double(index) / Double(max(trend.scores.count - 1, 1)) * size.width
                let yPosition = size.height * (1 - score.value)
                let point = CGPoint(x: xPosition, y: yPosition)

                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            context.stroke(path, with: .color(.mint), lineWidth: 2)
        }
        .frame(height: 86)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
    }

    private var ringRoughnessPlot: some View {
        Canvas { context, size in
            let xPosition = size.width * meters.roughness.score.value
            let yPosition = size.height * (1 - meters.ring.score.value)
            let rect = CGRect(x: xPosition - 4, y: yPosition - 4, width: 8, height: 8)

            context.stroke(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.secondary.opacity(0.4))
            )
            context.fill(Path(ellipseIn: rect), with: .color(.yellow))
        }
        .frame(width: 110, height: 86)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
    }

    private var confidenceMeter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Confidence")
                .font(.caption)
                .foregroundStyle(.secondary)

            ProgressView(value: latestScore?.confidence ?? 0)
                .progressViewStyle(.linear)
                .frame(width: 130)

            Text("Harmonics \(latestScore?.matchedHarmonics ?? 0)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 140, alignment: .leading)
    }

    private var confidenceText: String {
        let confidence = latestScore?.confidence ?? 0
        return "Confidence \(confidence.formatted(.percent.precision(.fractionLength(0))))"
    }

    private var latestScore: RingScore? {
        trend.scores.last
    }
}
