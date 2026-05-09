import SwiftUI

struct ContentView: View {
    @State private var viewModel: AppViewModel

    init(viewModel: AppViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HeaderView()

            AudioInputSelectorView(inputManager: viewModel.inputManager)

            AudioInputMonitorView(
                frame: viewModel.inputManager.latestFrame,
                state: viewModel.inputManager.state
            )

            LiveMetersView(snapshot: viewModel.currentFrame.meters)

            SpectrumView(spectrum: viewModel.currentFrame.spectrum)

            SpectrogramView(spectrogram: viewModel.currentFrame.spectrogram)
        }
        .padding(28)
        .frame(minWidth: 760, minHeight: 820)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            viewModel.startAudio()
        }
        .onDisappear {
            viewModel.stopAudio()
        }
    }
}
