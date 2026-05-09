import SwiftUI

struct LiveAnalysisView: View {
    let state: LiveAnalysisDisplayState
    let spectrum: SpectrumSnapshot
    let spectrogram: SpectrogramSnapshot
    let ringTrend: RingTrendSnapshot

    @State private var isDebugExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SignalStatusBanner(state: state.signal)
            WhatJustHappenedPanel(summary: state.trendSummary)
            CurrentQualityPanel(metrics: state.metricStates)
            BaselineComparisonPanel(state: state.baselineComparison)
            SpectrumPanel(spectrum: spectrum, spectrogram: spectrogram)
            ExperimentalDebugPanel(
                isExpanded: $isDebugExpanded,
                trend: ringTrend,
                meters: state.meters
            )
        }
    }
}

private struct SignalStatusBanner: View {
    let state: SignalQualityDisplayState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Signal Status")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(state.confidence, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Text(state.title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(statusColor)

            Text(state.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(statusColor.opacity(0.35), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        state.isReliable ? .green : .orange
    }
}

private struct WhatJustHappenedPanel: View {
    let summary: TrendSummary

    var body: some View {
        RehearsalPanel(title: "What Just Happened") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(summary.items) { item in
                    HStack(spacing: 10) {
                        Text(symbol(for: item.direction))
                            .font(.headline)
                            .foregroundStyle(color(for: item))
                            .frame(width: 22)

                        Text(item.summaryText)
                            .foregroundStyle(color(for: item))
                    }
                }
            }
        }
    }

    private func symbol(for direction: MetricTrendItem.Direction) -> String {
        switch direction {
        case .increased:
            "↑"
        case .decreased:
            "↓"
        case .unchanged:
            "→"
        case .notEnoughConfidence:
            "!"
        }
    }

    private func color(for item: MetricTrendItem) -> Color {
        switch item.direction {
        case .increased where item.kind != .roughness:
            .green
        case .decreased where item.kind == .roughness:
            .green
        case .increased, .decreased:
            .orange
        case .unchanged:
            .secondary
        case .notEnoughConfidence:
            .orange
        }
    }
}

private struct CurrentQualityPanel: View {
    let metrics: [MetricDisplayState]

    var body: some View {
        RehearsalPanel(title: "Current Quality") {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
                ForEach(metrics) { metric in
                    MetricQualityRow(metric: metric)
                }
            }
        }
    }
}

private struct MetricQualityRow: View {
    let metric: MetricDisplayState

    var body: some View {
        GridRow {
            Text(metric.title)
                .font(.subheadline.weight(.semibold))
                .frame(width: 86, alignment: .leading)

            ProgressView(value: metric.score)
                .progressViewStyle(.linear)
                .opacity(metric.isReliable ? 1 : 0.42)
                .frame(minWidth: 300)

            Text(metric.qualityLabel)
                .frame(width: 140, alignment: .leading)

            Text(metric.score, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .trailing)
        }
        .foregroundStyle(metric.isReliable ? .primary : .secondary)
    }
}

private struct BaselineComparisonPanel: View {
    let state: BaselineComparisonState

    var body: some View {
        RehearsalPanel(title: "Compared To Baseline") {
            if state.hasBaseline {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(state.items) { item in
                        Text(item.summaryText)
                            .foregroundStyle(item.improvement >= 0 ? .green : .orange)
                    }
                }
            } else {
                Text("No baseline yet. Record Take A to compare changes against a reference chord.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SpectrumPanel: View {
    let spectrum: SpectrumSnapshot
    let spectrogram: SpectrogramSnapshot

    var body: some View {
        RehearsalPanel(title: "Spectrum / Spectrogram") {
            VStack(alignment: .leading, spacing: 14) {
                Text(spectrumHelpText)
                .font(.caption)
                .foregroundStyle(.secondary)

                SpectrumView(spectrum: spectrum)
                SpectrogramView(spectrogram: spectrogram)
            }
        }
    }

    private var spectrumHelpText: String {
        "Spectrum shows where acoustic energy is concentrated. Stable peaks usually support clearer lock and ring."
    }
}

private struct ExperimentalDebugPanel: View {
    @Binding var isExpanded: Bool
    let trend: RingTrendSnapshot
    let meters: MeterSnapshot

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            RingExperimentView(trend: trend, meters: meters)
                .padding(.top, 12)
        } label: {
            Text("Experimental / Debug")
                .font(.headline)
        }
        .padding()
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct RehearsalPanel<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}
