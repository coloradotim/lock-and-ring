import SwiftUI

struct LiveAnalysisView: View {
    let state: LiveAnalysisDisplayState
    let frame: AnalysisFrame
    let spectrum: SpectrumSnapshot
    let spectrogram: SpectrogramSnapshot
    let ringTrend: RingTrendSnapshot
    let inputFrame: AudioInputFrame?
    let takeRecorder: TakeRecorder
    let onRecordTake: (TakeSlot) -> Void
    let onSwitchMode: (AppMode) -> Void

    @State private var isDebugExpanded = false
    @State private var isSpectrumExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SignalStatusBanner(state: state.signal)
            HStack(alignment: .top, spacing: 16) {
                WhatJustHappenedPanel(summary: state.trendSummary)
                CurrentQualityPanel(metrics: state.metricStates)
            }
            QuickTakePrompt(
                recorder: takeRecorder,
                onRecordTake: onRecordTake,
                onSwitchMode: onSwitchMode
            )
            SpectrumPanel(
                spectrum: spectrum,
                spectrogram: spectrogram,
                isCompact: true,
                isExpanded: $isSpectrumExpanded
            )
            ExperimentalDebugPanel(
                isExpanded: $isDebugExpanded,
                frame: frame,
                inputFrame: inputFrame,
                trend: ringTrend,
                meters: state.meters
            )
        }
    }
}

struct SignalStatusBanner: View {
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
            if summary.hasUsableChanges {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(summary.items.filter { $0.direction != .notEnoughConfidence }) { item in
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
            } else {
                Text(summary.lowConfidenceMessage)
                    .foregroundStyle(.secondary)
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

struct CurrentQualityPanel: View {
    var title = "Current Quality"
    let metrics: [MetricDisplayState]

    var body: some View {
        RehearsalPanel(title: title) {
            VStack(alignment: .leading, spacing: 12) {
                MetricHelpDisclosure()

                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
                    ForEach(metrics) { metric in
                        MetricQualityRow(metric: metric)
                    }
                }
            }
        }
    }
}

private struct QuickTakePrompt: View {
    let recorder: TakeRecorder
    let onRecordTake: (TakeSlot) -> Void
    let onSwitchMode: (AppMode) -> Void

    var body: some View {
        RehearsalPanel(title: "Quick Take") {
            HStack(spacing: 12) {
                Text(prompt)
                    .foregroundStyle(.secondary)

                Spacer()

                ForEach(buttons, id: \.title) { button in
                    Button(button.title) {
                        button.action()
                    }
                    .disabled(recorder.isRecording && !button.allowsRecording)
                }
            }
        }
    }

    private var prompt: String {
        if recorder.take(for: .takeA) == nil {
            return "No baseline yet. Record Take 1 to compare changes."
        }

        if recorder.take(for: .takeB) == nil {
            return "Take 1 recorded. Make one adjustment, then record Take 2."
        }

        return "Take comparison ready."
    }

    private var buttons: [QuickTakeButton] {
        if recorder.take(for: .takeA) == nil {
            return [
                QuickTakeButton(title: "Record Take 1", allowsRecording: true) {
                    onRecordTake(.takeA)
                }
            ]
        }

        if recorder.take(for: .takeB) == nil {
            return [
                QuickTakeButton(title: "Record Take 2", allowsRecording: true) {
                    onRecordTake(.takeB)
                },
                QuickTakeButton(title: "Go to Take 1 / Take 2") {
                    onSwitchMode(.takes)
                }
            ]
        }

        return [
            QuickTakeButton(title: "View Take 1 / Take 2") {
                onSwitchMode(.takes)
            }
        ]
    }
}

private struct QuickTakeButton {
    let title: String
    let allowsRecording: Bool
    let action: () -> Void

    init(title: String, allowsRecording: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.allowsRecording = allowsRecording
        self.action = action
    }
}

private struct MetricQualityRow: View {
    let metric: MetricDisplayState

    var body: some View {
        GridRow {
            Text(metric.title)
                .font(.subheadline.weight(.semibold))
                .frame(width: 86, alignment: .leading)

            Text(metric.qualityLabel)
                .frame(width: 150, alignment: .leading)

            ProgressView(value: metric.score)
                .progressViewStyle(.linear)
                .opacity(metric.isReliable ? 1 : 0.42)
                .frame(minWidth: 210)

            Text(metric.score, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .trailing)
        }
        .foregroundStyle(metric.isReliable ? .primary : .secondary)
    }
}

struct BaselineComparisonPanel: View {
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
                Text("No baseline yet. Record Take 1 to compare changes against a reference chord.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SpectrumPanel: View {
    let title: String
    let spectrum: SpectrumSnapshot
    let spectrogram: SpectrogramSnapshot
    let spectrumTitle: String
    let spectrogramTitle: String
    let duration: Double?
    var isCompact = false
    @Binding var isExpanded: Bool

    init(
        title: String = "Spectrum / Spectrogram",
        spectrum: SpectrumSnapshot,
        spectrogram: SpectrogramSnapshot,
        spectrumTitle: String = "Live Spectrum",
        spectrogramTitle: String = "Live Spectrogram",
        duration: Double? = nil,
        isCompact: Bool = false,
        isExpanded: Binding<Bool> = .constant(false)
    ) {
        self.title = title
        self.spectrum = spectrum
        self.spectrogram = spectrogram
        self.spectrumTitle = spectrumTitle
        self.spectrogramTitle = spectrogramTitle
        self.duration = duration
        self.isCompact = isCompact
        _isExpanded = isExpanded
    }

    var body: some View {
        RehearsalPanel(title: title) {
            VStack(alignment: .leading, spacing: 14) {
                Text(spectrumHelpText)
                .font(.caption)
                .foregroundStyle(.secondary)

                if isCompact {
                    DisclosureGroup("Show experimental visual detail", isExpanded: $isExpanded) {
                        sharedVisualDetail
                    }
                } else {
                    sharedVisualDetail
                }
            }
        }
    }

    private var sharedVisualDetail: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 14) {
                SpectrumView(title: spectrumTitle, spectrum: spectrum)
                SpectrogramView(
                    title: spectrogramTitle,
                    spectrogram: spectrogram,
                    duration: duration
                )
            }
            .frame(minWidth: 920)
            .padding(.top, 8)
        }
    }

    private var spectrumHelpText: String {
        "Spectrum shows where acoustic energy is concentrated. Stable peaks usually support clearer lock and ring."
    }
}

struct ExperimentalDebugPanel: View {
    @Binding var isExpanded: Bool
    let frame: AnalysisFrame
    let inputFrame: AudioInputFrame?
    let trend: RingTrendSnapshot
    let meters: MeterSnapshot

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                RingExperimentView(trend: trend, meters: meters)
                ScoringInspectorView(frame: frame, inputFrame: inputFrame)
            }
            .padding(.top, 12)
        } label: {
            Text("Experimental / Debug")
                .font(.headline)
        }
        .padding()
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct RehearsalPanel<Content: View>: View {
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
