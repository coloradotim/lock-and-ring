import SwiftUI
import UniformTypeIdentifiers

struct OfflineAnalysisView: View {
    let analyzer: OfflineAudioAnalyzer
    @State private var isImporterPresented = false
    @State private var scrubProgress = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Offline Analysis")
                    .font(.headline)

                Spacer()

                Button("Import") {
                    isImporterPresented = true
                }

                Button(playPauseTitle) {
                    analyzer.togglePlayback()
                }
                .disabled(analyzer.duration == 0)
            }

            Text(analyzer.selectedFileName)
                .font(.caption)
                .foregroundStyle(.secondary)

            Slider(
                value: scrubBinding,
                in: 0...1
            )
            .disabled(analyzer.duration == 0)

            HStack {
                Text(timeText)
                    .monospacedDigit()

                Spacer()

                Text(statusText)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.audio, .wav, .aiff, .mpeg4Audio, .mp3],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
    }

    private var scrubBinding: Binding<Double> {
        Binding(
            get: {
                analyzer.progress
            },
            set: { value in
                scrubProgress = value
                analyzer.scrub(to: value)
            }
        )
    }

    private var playPauseTitle: String {
        if case .playing = analyzer.state {
            return "Pause"
        }

        return "Play"
    }

    private var statusText: String {
        switch analyzer.state {
        case .empty:
            "No file"
        case .loading:
            "Loading"
        case .ready:
            "Ready"
        case .playing:
            "Playing"
        case .paused:
            "Paused"
        case let .failed(message):
            message
        }
    }

    private var timeText: String {
        "\(format(analyzer.currentTime)) / \(format(analyzer.duration))"
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let url = urls.first else {
            return
        }

        analyzer.importFile(from: url)
    }

    private func format(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}
