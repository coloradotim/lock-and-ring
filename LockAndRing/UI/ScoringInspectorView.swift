import SwiftUI

struct ScoringInspectorView: View {
    let frame: AnalysisFrame
    let inputFrame: AudioInputFrame?

    var body: some View {
        DisclosureGroup("Scoring Inspector") {
            VStack(alignment: .leading, spacing: 16) {
                metricsSection
                spectrumSection
                inputSection
            }
            .padding(.top, 12)
        }
        .padding()
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Metrics")
                .font(.subheadline.weight(.semibold))

            ForEach(MetricKind.displayOrder, id: \.self) { kind in
                MetricInspectorRow(
                    metric: frame.meters.metric(for: kind),
                    displayState: MetricDisplayState(snapshot: frame.meters.metric(for: kind))
                )
            }
        }
    }

    private var spectrumSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Spectrum")
                .font(.subheadline.weight(.semibold))

            keyValue("Sample rate", "\(Int(frame.spectrum.sampleRate.rounded())) Hz")
            keyValue("FFT size", frame.spectrum.fftSize.formatted())

            ForEach(topPeaks, id: \.binIndex) { peak in
                keyValue(
                    "\(Int(peak.frequency.rounded())) Hz",
                    peak.magnitude.formatted(.number.precision(.fractionLength(3)))
                )
            }
        }
        .font(.caption)
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Input Frame")
                .font(.subheadline.weight(.semibold))

            if let inputFrame {
                keyValue("Frame size", inputFrame.frameSize.formatted())
                keyValue("Channels", inputFrame.channelCount.formatted())
                keyValue("RMS", format(inputFrame.instrumentation.rmsLevel))
                keyValue("Noise floor", format(inputFrame.instrumentation.noiseFloor))
                keyValue("Clipping", inputFrame.instrumentation.isClipping ? "yes" : "no")
                keyValue("Channel balance", inputFrame.instrumentation.hasChannelImbalance ? "imbalanced" : "balanced")

                if inputFrame.channelCount >= 2 {
                    keyValue("L/R RMS", lRText(for: inputFrame.instrumentation.channelRMSLevels))
                }
            } else {
                Text("No analyzed audio frame yet.")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    private var topPeaks: [SpectrumPeak] {
        Array(frame.spectrum.peaks.sorted { $0.magnitude > $1.magnitude }.prefix(8))
    }

    private func format(_ value: Float) -> String {
        Double(value).formatted(.number.precision(.fractionLength(4)))
    }

    private func lRText(for levels: [Float]) -> String {
        let left = levels[safe: 0].map(format) ?? "--"
        let right = levels[safe: 1].map(format) ?? "--"
        return "\(left) / \(right)"
    }
}

private struct MetricInspectorRow: View {
    let metric: MetricSnapshot
    let displayState: MetricDisplayState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(metric.kind.displayTitle)
                    .font(.caption.weight(.semibold))

                Spacer()

                Text("Score \(percent(metric.score.value))")
                Text("Confidence \(percent(metric.confidence.value))")
            }

            keyValue("Label", displayState.qualityLabel)
            keyValue("Signal quality", metric.signalQuality.displayText)
            keyValue("Reason", metric.confidence.reason.isEmpty ? "--" : metric.confidence.reason)

            if !metric.contributingFactors.isEmpty {
                keyValue("Factors", factorsText)
            }

            if !metric.rawMeasurements.isEmpty {
                keyValue("Raw", rawText)
            }
        }
        .font(.caption)
        .padding(10)
        .background(.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 6))
    }

    private var factorsText: String {
        metric.contributingFactors
            .map { "\($0.name): \(percent($0.value))" }
            .joined(separator: ", ")
    }

    private var rawText: String {
        metric.rawMeasurements
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.formatted(.number.precision(.fractionLength(3))))" }
            .joined(separator: ", ")
    }
}

private func keyValue(_ key: String, _ value: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
        Text(key)
            .foregroundStyle(.secondary)
            .frame(width: 96, alignment: .leading)

        Text(value)
            .textSelection(.enabled)
    }
}

private func percent(_ value: Double) -> String {
    value.formatted(.percent.precision(.fractionLength(0)))
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
