import SwiftUI

struct ContentView: View {
    @State private var viewModel: AppViewModel
    @State private var selectedMode: AppMode = .live

    init(viewModel: AppViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                appHeader
                modeContent
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 760, minHeight: 920)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            viewModel.startAudio()
        }
        .onDisappear {
            viewModel.stopAudio()
        }
    }

    private var appHeader: some View {
        HStack(alignment: .top, spacing: 24) {
            HeaderView()

            Spacer()

            ModePicker(selectedMode: $selectedMode)
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        switch selectedMode {
        case .live:
            liveMode
        case .takes:
            takesMode
        case .file:
            fileMode
        }
    }

    private var liveMode: some View {
        VStack(alignment: .leading, spacing: 16) {
            ModeHelpDisclosure(mode: .live)

            CompactAudioStatusBar(
                inputManager: viewModel.inputManager,
                frame: viewModel.inputManager.latestFrame,
                state: viewModel.inputManager.state
            )

            LiveAnalysisView(
                state: displayState,
                frame: viewModel.currentFrame,
                spectrum: viewModel.currentFrame.spectrum,
                spectrogram: viewModel.currentFrame.spectrogram,
                ringTrend: viewModel.currentFrame.ringHistory,
                inputFrame: viewModel.latestAnalysisInputFrame,
                takeRecorder: viewModel.takeRecorder,
                onRecordTake: viewModel.startTakeRecording
            ) { mode in
                selectedMode = mode
            }
        }
    }

    private var takesMode: some View {
        VStack(alignment: .leading, spacing: 16) {
            CompactAudioStatusBar(
                inputManager: viewModel.inputManager,
                frame: viewModel.inputManager.latestFrame,
                state: viewModel.inputManager.state
            )

            TakesModeView(
                recorder: viewModel.takeRecorder,
                onRecord: viewModel.startTakeRecording,
                onStop: viewModel.stopTakeRecording,
                onPlay: viewModel.playTake,
                onClear: viewModel.clearTake
            )
        }
    }

    private var fileMode: some View {
            FileAnalysisModeView(
                analyzer: viewModel.offlineAnalyzer,
                displayState: displayState,
                frame: viewModel.currentFrame,
                inputFrame: viewModel.latestAnalysisInputFrame,
                spectrum: viewModel.currentFrame.spectrum,
                spectrogram: viewModel.currentFrame.spectrogram
            )
    }

    private var displayState: LiveAnalysisDisplayState {
        LiveAnalysisDisplayState(
            meters: viewModel.currentFrame.meters,
            history: viewModel.meterHistory,
            baseline: viewModel.takeRecorder.take(for: .takeA)?.summary
        )
    }
}
