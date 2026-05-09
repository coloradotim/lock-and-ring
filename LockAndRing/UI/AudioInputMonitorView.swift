import SwiftUI

struct AudioInputMonitorView: View {
    let frame: AudioInputFrame?
    let state: AudioInputState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Input Monitor")
                    .font(.headline)

                Spacer()

                Text(statusText)
                    .foregroundStyle(statusColor)
            }

            MeterLine(title: "Level", value: Double(frame?.instrumentation.rmsLevel ?? 0))

            if let frame, frame.channelCount >= 2 {
                MeterLine(title: "Left", value: Double(frame.instrumentation.channelRMSLevels[safe: 0] ?? 0))
                MeterLine(title: "Right", value: Double(frame.instrumentation.channelRMSLevels[safe: 1] ?? 0))
            }

            HStack(spacing: 18) {
                Label(channelText, systemImage: "waveform")
                Label(clippingText, systemImage: "exclamationmark.triangle")
                Label(imbalanceText, systemImage: "scale.3d")
            }
            .foregroundStyle(.secondary)
            .font(.caption)
        }
        .padding()
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }

    private var statusText: String {
        switch state {
        case .stopped:
            "Stopped"
        case .requestingPermission:
            "Requesting permission"
        case .running:
            frame?.instrumentation.hasSignal == true ? "Signal present" : "No signal"
        case .permissionDenied:
            "Permission denied"
        case .failed:
            "Input failed"
        }
    }

    private var statusColor: Color {
        switch state {
        case .running where frame?.instrumentation.hasSignal == true:
            .green
        case .permissionDenied, .failed:
            .red
        default:
            .secondary
        }
    }

    private var channelText: String {
        guard let frame else {
            return "No input"
        }

        return frame.channelCount >= 2 ? "Stereo" : "Mono"
    }

    private var clippingText: String {
        frame?.instrumentation.isClipping == true ? "Clipping" : "No clipping"
    }

    private var imbalanceText: String {
        frame?.instrumentation.hasChannelImbalance == true ? "Imbalance" : "Balanced"
    }
}

private struct MeterLine: View {
    let title: String
    let value: Double

    var body: some View {
        HStack {
            Text(title)
                .frame(width: 58, alignment: .leading)

            ProgressView(value: min(max(value, 0), 1))
                .progressViewStyle(.linear)

            Text(value, format: .number.precision(.fractionLength(2)))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
