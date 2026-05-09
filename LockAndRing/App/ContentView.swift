import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var viewModel: AppViewModel
    @State private var isImporterPresented = false
    @State private var isDebugExpanded = false
    @State private var isVisualEvidenceExpanded = false

    init(viewModel: AppViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeaderView()
                CompactAudioStatusBar(
                    inputManager: viewModel.inputManager,
                    frame: viewModel.inputManager.latestFrame,
                    state: viewModel.inputManager.state
                )
                workflowContent
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 760, minHeight: 920)
        .background(Color(nsColor: .windowBackgroundColor))
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.audio, .wav, .aiff, .mpeg4Audio, .mp3],
            allowsMultipleSelection: false,
            onCompletion: handleImport
        )
        .onAppear {
            viewModel.startAudio()
        }
        .onDisappear {
            viewModel.stopAudio()
        }
    }

    @ViewBuilder
    private var workflowContent: some View {
        switch viewModel.workflowState {
        case .ready:
            readyView
        case let .recording(startedAt):
            recordingView(startedAt: startedAt)
        case .analyzing:
            analyzingView
        case .reviewingTake:
            takeAnalysisView
        case .comparing:
            comparingView
        }
    }

    private var readyView: some View {
        let recordingReadiness = viewModel.recordingReadiness

        return VStack(alignment: .leading, spacing: 16) {
            workflowHeader(
                title: "Ready",
                subtitle: "Record or import a take, then review what happened."
            )

            if let statusMessage = recordingReadiness.statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button {
                    viewModel.startPrimaryTakeRecording()
                } label: {
                    Label("Record Take", systemImage: "record.circle")
                }
                .keyboardShortcut(.space, modifiers: [])
                .buttonStyle(.borderedProminent)
                .disabled(!recordingReadiness.isAvailable)
                .help(recordingReadiness.statusMessage ?? "Record a take from the selected microphone.")

                Button {
                    isImporterPresented = true
                } label: {
                    Label("Import Take", systemImage: "square.and.arrow.down")
                }
            }
            .controlSize(.large)

            if let savedTake = viewModel.savedTake {
                SavedTakeSummary(take: savedTake)
            }

            if let message = viewModel.libraryErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            SavedTakeLibraryView(
                savedTakes: viewModel.savedTakes,
                onPlay: viewModel.playSavedTake,
                onAnalyze: viewModel.analyzeSavedTake,
                onCompare: viewModel.useSavedTakeForComparison,
                onRename: viewModel.renameSavedTake,
                onDelete: viewModel.deleteSavedTake
            )
        }
    }

    private func recordingView(startedAt: Date) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            workflowHeader(
                title: "Recording...",
                subtitle: "Keep singing. The screen is only watching input quality right now."
            )

            RecordingStatusPanel(
                startedAt: startedAt,
                signal: displayState.signal
            )

            Button {
                viewModel.stopTakeRecording()
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.space, modifiers: [])
        }
    }

    private var analyzingView: some View {
        RehearsalPanel(title: "Analyzing Take") {
            HStack(spacing: 12) {
                ProgressView()
                Text("Preparing Take Analysis...")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var takeAnalysisView: some View {
        VStack(alignment: .leading, spacing: 16) {
            workflowHeader(
                title: "Take Analysis",
                subtitle: "Use this take to decide whether to save, compare, try again, or discard."
            )

            if let take = viewModel.currentTake {
                TakeReviewDashboard(
                    take: take,
                    displayState: displayState(for: take),
                    frame: take.analysisFrame,
                    playback: viewModel.currentTakePlayback,
                    canCompare: viewModel.canCompareCurrentTake,
                    liveInputFrame: viewModel.inputManager.latestFrame,
                    liveInputState: viewModel.inputManager.state,
                    isDebugExpanded: $isDebugExpanded,
                    isVisualEvidenceExpanded: $isVisualEvidenceExpanded,
                    onPlaybackToggle: viewModel.toggleCurrentTakePlayback,
                    onPlaybackScrub: viewModel.scrubCurrentTakePlayback,
                    onSave: viewModel.saveCurrentTake,
                    onCompare: viewModel.compareCurrentTake,
                    onRecordAgain: viewModel.startPrimaryTakeRecording,
                    onDiscard: viewModel.discardCurrentTake
                )
            } else {
                EmptyTakeAnalysisActions(
                    onRecord: viewModel.startPrimaryTakeRecording,
                    onImport: {
                        isImporterPresented = true
                    }
                )
            }
        }
    }

    private var comparingView: some View {
        VStack(alignment: .leading, spacing: 16) {
            workflowHeader(
                title: "Comparison",
                subtitle: "Current take compared with the saved take."
            )

            if let savedTake = viewModel.savedTake, let currentTake = viewModel.currentTake {
                UnifiedComparisonView(
                    comparison: TakeComparisonSummary(
                        takeA: savedTake,
                        takeB: currentTake
                    )
                )
            }

            HStack(spacing: 10) {
                Button {
                    viewModel.reviewCurrentTake()
                } label: {
                    Label("Back to Take Analysis", systemImage: "chevron.left")
                }

                Button {
                    viewModel.startPrimaryTakeRecording()
                } label: {
                    Label("Record Again", systemImage: "record.circle")
                }
            }
            .controlSize(.large)
        }
    }

    private func workflowHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.largeTitle.weight(.bold))

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var displayState: LiveAnalysisDisplayState {
        LiveAnalysisDisplayState(
            meters: viewModel.currentFrame.meters,
            history: viewModel.meterHistory,
            baseline: viewModel.savedTake?.summary
        )
    }

    private func displayState(for take: RecordedTake) -> LiveAnalysisDisplayState {
        LiveAnalysisDisplayState(
            meters: take.analysisFrame.meters,
            history: take.frames.map(\.meters),
            baseline: viewModel.savedTake?.summary
        )
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let url = urls.first else {
            return
        }

        viewModel.importTake(from: url)
    }
}

private struct RecordingStatusPanel: View {
    let startedAt: Date
    let signal: SignalQualityDisplayState

    var body: some View {
        RehearsalPanel(title: "Recording") {
            VStack(alignment: .leading, spacing: 10) {
                Text(startedAt, style: .timer)
                    .font(.system(.title, design: .monospaced).weight(.semibold))

                HStack {
                    Text("Signal:")
                        .foregroundStyle(.secondary)

                    Text(signal.title)
                        .foregroundStyle(signal.isReliable ? .green : .orange)
                        .fontWeight(.semibold)
                }

                Text(signal.message)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct EmptyTakeAnalysisActions: View {
    let onRecord: () -> Void
    let onImport: () -> Void

    var body: some View {
        RehearsalPanel(title: "No Take Yet") {
            HStack(spacing: 12) {
                Button("Record Take", action: onRecord)
                    .buttonStyle(.borderedProminent)

                Button("Import Take", action: onImport)
            }
        }
    }
}

private struct SavedTakeSummary: View {
    let take: RecordedTake

    var body: some View {
        RehearsalPanel(title: "Saved Take") {
            Text("\(take.name) - \(formatSeconds(take.duration))")
                .foregroundStyle(.secondary)
        }
    }
}

private struct UnifiedComparisonView: View {
    let comparison: TakeComparisonSummary

    var body: some View {
        RehearsalPanel(title: comparison.headline) {
            VStack(alignment: .leading, spacing: 12) {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    ForEach(comparison.comparisons, id: \.title) { metric in
                        GridRow {
                            Text(metric.title)
                            Text(formatValue(metric.takeA, unit: metric.unit))
                                .monospacedDigit()
                            Text(formatValue(metric.takeB, unit: metric.unit))
                                .monospacedDigit()
                            Text(metric.directionText)
                                .foregroundStyle(metric.isRegressed ? .orange : .green)
                        }
                    }
                }
                .font(.caption)

                if let warning = comparison.confidenceWarning {
                    Text(warning)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

private func formatPercent(_ value: Double) -> String {
    value.formatted(.percent.precision(.fractionLength(0)))
}

private func formatSeconds(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(1))) + "s"
}

private func formatValue(_ value: Double, unit: MetricComparison.Unit) -> String {
    switch unit {
    case .percent:
        formatPercent(value)
    case .seconds:
        formatSeconds(value)
    }
}
