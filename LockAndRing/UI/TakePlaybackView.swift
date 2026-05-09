import SwiftUI

struct CurrentTakePlaybackPanel: View {
    let playback: TakePlaybackState
    let onToggle: () -> Void
    let onScrub: (Double) -> Void

    var body: some View {
        RehearsalPanel(title: "Playback") {
            HStack(spacing: 12) {
                Button {
                    onToggle()
                } label: {
                    Label(playback.isPlaying ? "Pause" : "Play", systemImage: playbackIcon)
                }
                .disabled(!playback.isAvailable)

                Text(timeText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 98, alignment: .leading)

                Slider(
                    value: Binding(
                        get: { playback.progress },
                        set: onScrub
                    ),
                    in: 0...1
                )
                .disabled(!playback.isAvailable)
            }
            .controlSize(.large)
        }
    }

    private var playbackIcon: String {
        playback.isPlaying ? "pause.fill" : "play.fill"
    }

    private var timeText: String {
        "\(formatPlaybackTime(playback.currentTime)) / \(formatPlaybackTime(playback.duration))"
    }
}

struct LiveInputMonitorPanel: View {
    let frame: AudioInputFrame?
    let state: AudioInputState

    var body: some View {
        DisclosureGroup {
            AudioInputMonitorView(frame: frame, state: state)
                .padding(.top, 8)
        } label: {
            Text("Live Input Monitor")
                .font(.headline)
        }
        .padding()
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

private func formatPlaybackTime(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(1))) + "s"
}
