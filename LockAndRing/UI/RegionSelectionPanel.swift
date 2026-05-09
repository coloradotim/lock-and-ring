import SwiftUI

struct RegionSelectionPanel: View {
    let take: RecordedTake
    let draftRegion: TakeRegion?
    let analysisRegion: TakeRegion?
    let savedRegions: [TakeRegion]
    let playback: TakePlaybackState
    let onRegionStartChange: (Double) -> Void
    let onRegionEndChange: (Double) -> Void
    let onAnalyzeRegion: () -> Void
    let onClearRegion: () -> Void
    let onSaveRegion: () -> Void
    let onSelectRegion: (TakeRegion?) -> Void
    let onPlayRegion: () -> Void
    let onLoopRegion: () -> Void
    let onStopRegionPlayback: () -> Void

    var body: some View {
        RehearsalPanel(title: "Region Analysis") {
            VStack(alignment: .leading, spacing: 12) {
                Text(scopeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    regionSlider(
                        title: "Start",
                        value: startBinding,
                        time: draftRegion?.startTime ?? 0
                    )
                    regionSlider(
                        title: "End",
                        value: endBinding,
                        time: draftRegion?.endTime ?? take.duration
                    )
                }

                HStack(spacing: 10) {
                    Button("Analyze Region", action: onAnalyzeRegion)
                        .disabled(!canUseRegion)
                    Button("Clear Selection", action: onClearRegion)
                    Button("Save Region", action: onSaveRegion)
                        .disabled(!canUseRegion)
                }

                HStack(spacing: 10) {
                    Button(playLabel, action: onPlayRegion)
                        .disabled(!canPlayRegion)
                    Button(loopLabel, action: onLoopRegion)
                        .disabled(!canPlayRegion)
                    Button("Stop", action: onStopRegionPlayback)
                        .disabled(!playback.isPlaying)
                }

                if !savedRegions.isEmpty {
                    Divider()
                    regionList
                }
            }
        }
    }

    private var scopeText: String {
        guard let analysisRegion else {
            return "Analyzing: Whole take (\(formatRegionTime(0))-\(formatRegionTime(take.duration)))."
        }

        return "Analyzing: \(regionTitle(analysisRegion)) (\(regionRangeText(analysisRegion)))."
    }

    private var canUseRegion: Bool {
        draftRegion?.isValid == true
    }

    private var canPlayRegion: Bool {
        canUseRegion && playback.isAvailable
    }

    private var playLabel: String {
        playback.isPlaying && !playback.isLooping ? "Pause Region" : "Play Region"
    }

    private var loopLabel: String {
        playback.isLooping ? "Looping Region" : "Loop Region"
    }

    private var startBinding: Binding<Double> {
        Binding(
            get: { progress(for: draftRegion?.startTime ?? 0) },
            set: onRegionStartChange
        )
    }

    private var endBinding: Binding<Double> {
        Binding(
            get: { progress(for: draftRegion?.endTime ?? take.duration) },
            set: onRegionEndChange
        )
    }

    private var regionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Saved Regions")
                .font(.caption.weight(.semibold))
            Button("Whole take") {
                onSelectRegion(nil)
            }
            ForEach(savedRegions) { region in
                Button("\(regionTitle(region)) - \(regionRangeText(region))") {
                    onSelectRegion(region)
                }
            }
        }
        .font(.caption)
    }

    private func regionSlider(
        title: String,
        value: Binding<Double>,
        time: TimeInterval
    ) -> some View {
        HStack {
            Text(title)
                .frame(width: 42, alignment: .leading)
            Slider(value: value, in: 0...1)
            Text(formatRegionTime(time))
                .monospacedDigit()
                .frame(width: 54, alignment: .trailing)
        }
        .font(.caption)
    }

    private func progress(for time: TimeInterval) -> Double {
        guard take.duration > 0 else {
            return 0
        }

        return min(max(time / take.duration, 0), 1)
    }

    private func regionTitle(_ region: TakeRegion) -> String {
        region.name ?? "Selected region"
    }

    private func regionRangeText(_ region: TakeRegion) -> String {
        "\(formatRegionTime(region.startTime))-\(formatRegionTime(region.endTime))"
    }
}

func formatRegionTime(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(1))) + "s"
}
