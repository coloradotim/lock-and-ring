import SwiftUI

struct LiveMetersView: View {
    let snapshot: MeterSnapshot

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 14) {
            MeterRow(title: "Lock", score: snapshot.lock)
            MeterRow(title: "Ring", score: snapshot.ring)
            MeterRow(title: "Roughness", score: snapshot.roughness)
            MeterRow(title: "Stability", score: snapshot.stability)
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
                .frame(minWidth: 420)

            Text(score.score.value, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .trailing)
        }
    }
}
