import SwiftUI

struct TakeReviewDashboard: View {
    let take: RecordedTake
    let displayState: LiveAnalysisDisplayState
    let frame: AnalysisFrame
    let playback: TakePlaybackState
    let canCompare: Bool
    let liveInputFrame: AudioInputFrame?
    let liveInputState: AudioInputState
    @Binding var isDebugExpanded: Bool
    @Binding var isVisualEvidenceExpanded: Bool
    let onPlaybackToggle: () -> Void
    let onPlaybackScrub: (Double) -> Void
    let onSave: () -> Void
    let onCompare: () -> Void
    let onRecordAgain: () -> Void
    let onDiscard: () -> Void

    @State private var isDiscardConfirmationPresented = false

    var body: some View {
        let takeState = TakeAnalysisDisplayState(take: take)
        let chordAnalysis = ChordLabAnalyzer().analyze(frames: take.frames)
        let phraseState = PhraseSegmentationDisplayState(regionStates: [takeState.confidenceState])

        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: dashboardColumns, alignment: .leading, spacing: 16) {
                TakeSummaryPanel(take: take, state: takeState)
                TakeDecisionPanel(
                    playback: playback,
                    canCompare: canCompare,
                    onListenBack: onPlaybackToggle,
                    onPlaybackScrub: onPlaybackScrub,
                    onSave: onSave,
                    onCompare: onCompare,
                    onRecordAgain: onRecordAgain,
                    onDiscard: {
                        isDiscardConfirmationPresented = true
                    }
                )
            }

            TakeQualityGridPanel(metrics: displayState.metricStates)

            ChordLabView(
                title: "Timing / Chord Behavior",
                analysis: chordAnalysis
            )

            PhrasePlaceholderPanel(state: phraseState)

            SpectrumPanel(
                title: "Advanced Details",
                spectrum: frame.spectrum,
                spectrogram: frame.spectrogram,
                spectrumTitle: "Recorded Take Spectrum",
                spectrogramTitle: "Recorded Take Spectrogram",
                duration: take.duration,
                isCompact: true,
                isExpanded: $isVisualEvidenceExpanded
            )

            LiveInputMonitorPanel(frame: liveInputFrame, state: liveInputState)

            ExperimentalDebugPanel(
                isExpanded: $isDebugExpanded,
                frame: frame,
                inputFrame: liveInputFrame,
                trend: frame.ringHistory,
                meters: frame.meters
            )
        }
        .confirmationDialog(
            "Discard this take?",
            isPresented: $isDiscardConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Discard Take", role: .destructive, action: onDiscard)
            Button("Keep Reviewing", role: .cancel) {}
        } message: {
            Text("This clears the unsaved take from the review screen.")
        }
    }

    private var dashboardColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 330), spacing: 16, alignment: .topLeading)
        ]
    }
}

private struct TakeSummaryPanel: View {
    let take: RecordedTake
    let state: TakeAnalysisDisplayState

    var body: some View {
        RehearsalPanel(title: "Take Summary") {
            VStack(alignment: .leading, spacing: 12) {
                if let warning = state.warningMessage {
                    LowConfidenceActionCallout(message: warning)
                }

                Text(state.lockSummary)
                    .font(.title3.weight(.semibold))

                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                    metricRow("Duration", formatDashboardSeconds(take.duration))
                    metricRow("Frames", take.frames.count.formatted())
                    metricRow("Confidence", formatDashboardPercent(take.summary.averageConfidence))
                }
                .font(.caption)
            }
        }
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)

            Text(value)
                .monospacedDigit()
        }
    }
}

private struct LowConfidenceActionCallout: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Low-confidence take", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Move closer, confirm the selected input, raise input level, sing a little louder, then record again.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct TakeDecisionPanel: View {
    let playback: TakePlaybackState
    let canCompare: Bool
    let onListenBack: () -> Void
    let onPlaybackScrub: (Double) -> Void
    let onSave: () -> Void
    let onCompare: () -> Void
    let onRecordAgain: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        RehearsalPanel(title: "Take Actions") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Button(action: onSave) {
                        Label("Save Take", systemImage: "tray.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: onRecordAgain) {
                        Label("Record Again", systemImage: "record.circle")
                    }
                }

                HStack(spacing: 10) {
                    Button(action: onListenBack) {
                        Label(playback.isPlaying ? "Pause" : "Listen Back", systemImage: playbackIcon)
                    }
                    .disabled(!playback.isAvailable)

                    Button(action: onCompare) {
                        Label("Compare", systemImage: "rectangle.split.2x1")
                    }
                    .disabled(!canCompare)

                    Button(role: .destructive, action: onDiscard) {
                        Label("Discard", systemImage: "trash")
                    }
                }

                Slider(
                    value: Binding(
                        get: { playback.progress },
                        set: onPlaybackScrub
                    ),
                    in: 0...1
                )
                .disabled(!playback.isAvailable)

                Text(helpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .controlSize(.large)
        }
    }

    private var playbackIcon: String {
        playback.isPlaying ? "pause.fill" : "play.fill"
    }

    private var helpText: String {
        if !canCompare {
            return "Save a reference take before comparing. Listening back is available before saving."
        }

        return "Choose whether to keep, retry, compare, or discard this take."
    }
}

private struct TakeQualityGridPanel: View {
    let metrics: [MetricDisplayState]

    var body: some View {
        RehearsalPanel(title: "Take Quality") {
            LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 12) {
                ForEach(metrics) { metric in
                    TakeQualityTile(metric: metric)
                }
            }
        }
    }

    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 170), spacing: 12, alignment: .topLeading)]
    }
}

private struct TakeQualityTile: View {
    let metric: MetricDisplayState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(metric.title)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text(metric.score, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text(metric.qualityLabel)
                .font(.caption)
                .foregroundStyle(metric.isReliable ? Color.primary : Color.orange)

            ProgressView(value: metric.score)
                .progressViewStyle(.linear)
                .opacity(metric.isReliable ? 1 : 0.38)
        }
        .padding(12)
        .background(.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(metric.isReliable ? .clear : .orange.opacity(0.35), lineWidth: 1)
        }
    }
}

private struct PhrasePlaceholderPanel: View {
    let state: PhraseSegmentationDisplayState

    var body: some View {
        RehearsalPanel(title: "Phrase") {
            VStack(alignment: .leading, spacing: 8) {
                if let warning = state.warningMessage {
                    Text(warning)
                        .foregroundStyle(.orange)
                }

                Text(state.summary)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
    }
}

private func formatDashboardPercent(_ value: Double) -> String {
    value.formatted(.percent.precision(.fractionLength(0)))
}

private func formatDashboardSeconds(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(1))) + "s"
}
