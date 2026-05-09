import SwiftUI

struct LiveMetersView: View {
    let snapshot: MeterSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SignalQualityBanner(snapshot: snapshot)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 14) {
                MeterRow(title: "Lock", score: snapshot.lock)
                MeterRow(title: "Ring", score: snapshot.ring)
                MeterRow(title: "Roughness", score: snapshot.roughness)
                MeterRow(title: "Stability", score: snapshot.stability)
            }
        }
    }
}

private struct SignalQualityBanner: View {
    let snapshot: MeterSnapshot

    var body: some View {
        HStack(spacing: 12) {
            Text(snapshot.ring.signalQuality.displayText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)

            ProgressView(value: averageConfidence)
                .progressViewStyle(.linear)
                .frame(width: 180)

            Text(averageConfidence, format: .percent.precision(.fractionLength(0)))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private var averageConfidence: Double {
        let values = [
            snapshot.lock.confidence.value,
            snapshot.ring.confidence.value,
            snapshot.roughness.confidence.value,
            snapshot.stability.confidence.value
        ]

        return values.reduce(0, +) / Double(values.count)
    }

    private var color: Color {
        switch snapshot.ring.signalQuality {
        case .nominal:
            .green
        case .unavailable:
            .secondary
        default:
            .orange
        }
    }
}

private struct MeterRow: View {
    let title: String
    let score: MetricSnapshot

    var body: some View {
        GridRow {
            Text(title)
                .font(.headline)
                .frame(width: 90, alignment: .leading)

            ProgressView(value: score.score.value)
                .progressViewStyle(.linear)
                .opacity(confidenceOpacity)
                .frame(minWidth: 420)

            Text(score.score.value, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .trailing)

            Text(score.confidence.value, format: .percent.precision(.fractionLength(0)))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(confidenceColor)
                .frame(width: 52, alignment: .trailing)
        }
    }

    private var confidenceOpacity: Double {
        0.35 + score.confidence.value * 0.65
    }

    private var confidenceColor: Color {
        score.confidence.value >= 0.55 ? .secondary : .orange
    }
}
