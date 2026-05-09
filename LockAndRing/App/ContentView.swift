import SwiftUI

struct ContentView: View {
    @State private var viewModel: AppViewModel

    init(viewModel: AppViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HeaderView()

                AudioInputSelectorView(inputManager: viewModel.inputManager)

                AudioInputMonitorView(
                    frame: viewModel.inputManager.latestFrame,
                    state: viewModel.inputManager.state
                )

                OfflineAnalysisView(analyzer: viewModel.offlineAnalyzer)

                TakeComparisonView(
                    recorder: viewModel.takeRecorder,
                    onRecord: viewModel.startTakeRecording,
                    onStop: viewModel.stopTakeRecording,
                    onPlay: viewModel.playTake,
                    onClear: viewModel.clearTake
                )

                LiveMetersView(snapshot: viewModel.currentFrame.meters)

                RingExperimentView(
                    trend: viewModel.currentFrame.ringHistory,
                    meters: viewModel.currentFrame.meters
                )

                SpectrumView(spectrum: viewModel.currentFrame.spectrum)

                SpectrogramView(spectrogram: viewModel.currentFrame.spectrogram)
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
}
