import SwiftUI

struct ModePicker: View {
    @Binding var selectedMode: AppMode

    var body: some View {
        Picker("Mode", selection: $selectedMode) {
            ForEach(AppMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 520)
    }
}

struct CompactAudioStatusBar: View {
    let inputManager: AudioInputManager
    let frame: AudioInputFrame?
    let state: AudioInputState
    @State private var isDetailsExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                Text("Mic:")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("Mic", selection: selectedInputBinding) {
                    ForEach(inputManager.availableInputNames, id: \.self) { inputName in
                        Text(inputName).tag(inputName)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 280)

                Label(channelText, systemImage: "waveform")
                Label(levelText, systemImage: "speaker.wave.2")
                Label(clippingText, systemImage: "exclamationmark.triangle")

                if frame?.channelCount ?? 0 >= 2 {
                    Label(balanceText, systemImage: "scale.3d")
                }

                Spacer()

                Button(isDetailsExpanded ? "Hide details" : "Show input details") {
                    isDetailsExpanded.toggle()
                }
                .font(.caption)
            }
            .font(.caption)

            if isDetailsExpanded {
                AudioInputMonitorView(frame: frame, state: state)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private var selectedInputBinding: Binding<String> {
        Binding(
            get: {
                inputManager.selectedInputName
            },
            set: { inputName in
                inputManager.selectInput(named: inputName)
            }
        )
    }

    private var channelText: String {
        guard let frame else {
            return "No input"
        }

        return frame.channelCount >= 2 ? "Stereo" : "Mono"
    }

    private var levelText: String {
        guard let level = frame?.instrumentation.rmsLevel else {
            return "Level: none"
        }

        switch level {
        case ..<0.01:
            return "Level: none"
        case ..<0.05:
            return "Level: low"
        default:
            return "Level: good"
        }
    }

    private var clippingText: String {
        frame?.instrumentation.isClipping == true ? "Clipping" : "No clipping"
    }

    private var balanceText: String {
        frame?.instrumentation.hasChannelImbalance == true ? "L/R imbalance" : "L/R balanced"
    }
}

struct TakesModeView: View {
    let recorder: TakeRecorder
    let onRecord: (TakeSlot) -> Void
    let onStop: () -> Void
    let onPlay: (TakeSlot) -> Void
    let onClear: (TakeSlot) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                Text(AppMode.takes.primaryQuestion)
                    .font(.headline)

                ModeHelpDisclosure(mode: .takes)

                TakeComparisonView(
                    recorder: recorder,
                    onRecord: onRecord,
                    onStop: onStop,
                    onPlay: onPlay,
                    onClear: onClear
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct FileAnalysisModeView: View {
    let analyzer: OfflineAudioAnalyzer
    let displayState: LiveAnalysisDisplayState
    let frame: AnalysisFrame
    let inputFrame: AudioInputFrame?
    let spectrum: SpectrumSnapshot
    let spectrogram: SpectrogramSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(AppMode.file.primaryQuestion)
                .font(.headline)

            ModeHelpDisclosure(mode: .file)

            OfflineAnalysisView(analyzer: analyzer)

            HStack(alignment: .top, spacing: 16) {
                CurrentQualityPanel(metrics: displayState.metricStates)

                RehearsalPanel(title: "File / Signal Status") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(fileSummary)
                        Text(displayState.signal.title)
                            .foregroundStyle(displayState.signal.isReliable ? .green : .orange)
                        Text(displayState.signal.message)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            }

            SpectrumPanel(spectrum: spectrum, spectrogram: spectrogram)

            ScoringInspectorView(frame: frame, inputFrame: inputFrame)
        }
    }

    private var fileSummary: String {
        guard let clip = analyzer.clip else {
            return "No file selected"
        }

        let channels = clip.channelCount >= 2 ? "Stereo" : "Mono"
        let duration = clip.duration.formatted(.number.precision(.fractionLength(1)))
        let rate = Int(clip.sampleRate.rounded())
        return "\(clip.fileName) - \(duration)s - \(rate) Hz - \(channels)"
    }
}
