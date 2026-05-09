import SwiftUI

struct TakeComparisonView: View {
    let recorder: TakeRecorder
    let onRecord: (TakeSlot) -> Void
    let onStop: () -> Void
    let onPlay: (TakeSlot) -> Void
    let onClear: (TakeSlot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Take Comparison")
                    .font(.headline)

                Spacer()

                if let comparison = recorder.comparison {
                    Text(comparison.headline)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(headlineColor(for: comparison))
                }
            }

            HStack(alignment: .top, spacing: 14) {
                takePanel(slot: .takeA)
                takePanel(slot: .takeB)
            }

            if let comparison = recorder.comparison {
                ComparisonDeltaGrid(comparison: comparison)
                TakeOverlayView(takeA: comparison.takeA, takeB: comparison.takeB)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }

    private func takePanel(slot: TakeSlot) -> some View {
        let take = recorder.take(for: slot)
        let isActive = recorder.activeSlot == slot

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(slot.title)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text(take?.name ?? "Not recorded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TakeMetricSummary(summary: take?.summary)

            HStack(spacing: 8) {
                Button(isActive ? "Stop" : "Record") {
                    isActive ? onStop() : onRecord(slot)
                }
                .keyboardShortcut(slot == .takeA ? "1" : "2")

                Button("Play") {
                    onPlay(slot)
                }
                .disabled(take == nil || recorder.isRecording)

                Button("Clear") {
                    onClear(slot)
                }
                .disabled(take == nil && !isActive)
            }
            .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }

    private func headlineColor(for comparison: TakeComparisonSummary) -> Color {
        switch comparison.headline {
        case "Take B improved":
            .green
        case "Take B moved away":
            .red
        default:
            .secondary
        }
    }
}

private struct TakeMetricSummary: View {
    let summary: TakeSummary?

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 5) {
            summaryRow("Frames", summary?.frameCount.formatted() ?? "--")
            summaryRow("Duration", formatSeconds(summary?.duration))
            summaryRow("Lock", formatPercent(summary?.averageLock))
            summaryRow("Ring", formatPercent(summary?.averageRing))
            summaryRow("Roughness", formatPercent(summary?.averageRoughness))
            summaryRow("Stable", formatSeconds(summary?.stabilityDuration))
        }
        .font(.caption)
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)

            Text(value)
                .monospacedDigit()
        }
    }
}

private struct ComparisonDeltaGrid: View {
    let comparison: TakeComparisonSummary

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
            ForEach(comparison.comparisons, id: \.title) { metric in
                GridRow {
                    Text(metric.title)
                        .frame(width: 82, alignment: .leading)

                    Text(formatValue(metric.takeA, unit: metric.unit))
                        .monospacedDigit()
                        .frame(width: 58, alignment: .trailing)

                    Text(formatValue(metric.takeB, unit: metric.unit))
                        .monospacedDigit()
                        .frame(width: 58, alignment: .trailing)

                    Text(deltaText(for: metric))
                        .monospacedDigit()
                        .foregroundStyle(deltaColor(for: metric))
                        .frame(width: 70, alignment: .trailing)

                    Text(metric.directionText)
                        .foregroundStyle(deltaColor(for: metric))
                }
            }
        }
        .font(.caption)
    }

    private func deltaText(for metric: MetricComparison) -> String {
        let prefix = metric.delta >= 0 ? "+" : ""
        return "\(prefix)\(formatValue(metric.delta, unit: metric.unit))"
    }

    private func deltaColor(for metric: MetricComparison) -> Color {
        if metric.isImproved {
            return .green
        }

        if metric.isRegressed {
            return .red
        }

        return .secondary
    }
}

private struct TakeOverlayView: View {
    let takeA: TakeSummary
    let takeB: TakeSummary

    var body: some View {
        Canvas { context, size in
            drawBars(for: takeA, color: .cyan, xOffset: -5, context: &context, size: size)
            drawBars(for: takeB, color: .mint, xOffset: 5, context: &context, size: size)
        }
        .frame(height: 58)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
    }

    private func drawBars(
        for summary: TakeSummary,
        color: Color,
        xOffset: Double,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        let values = [
            summary.averageLock,
            summary.averageRing,
            1 - summary.averageRoughness,
            summary.averageStability
        ]
        let gap = size.width / Double(values.count + 1)

        for (index, value) in values.enumerated() {
            let xPosition = gap * Double(index + 1) + xOffset
            let barHeight = size.height * min(max(value, 0), 1)
            let rect = CGRect(
                x: xPosition - 4,
                y: size.height - barHeight,
                width: 8,
                height: barHeight
            )

            context.fill(Path(rect), with: .color(color.opacity(0.85)))
        }
    }
}

private func formatPercent(_ value: Double?) -> String {
    guard let value else {
        return "--"
    }

    return value.formatted(.percent.precision(.fractionLength(0)))
}

private func formatSeconds(_ value: Double?) -> String {
    guard let value else {
        return "--"
    }

    return value.formatted(.number.precision(.fractionLength(1))) + "s"
}

private func formatValue(_ value: Double, unit: MetricComparison.Unit) -> String {
    switch unit {
    case .percent:
        value.formatted(.percent.precision(.fractionLength(0)))
    case .seconds:
        formatSeconds(value)
    }
}
