import SwiftUI

struct PhraseSegmentationPanel: View {
    let analysis: PhraseSegmentationAnalysis

    var body: some View {
        RehearsalPanel(title: "Phrase Segmentation") {
            if analysis.timelineSegments.isEmpty {
                Text("Phrase segmentation is not available for this take yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text(summaryText)
                        .font(.caption.weight(.semibold))

                    PhraseTimelineView(segments: analysis.timelineSegments)
                    phraseLegend
                    summaryGrid
                }
            }
        }
    }

    private var summaryText: String {
        let summary = analysis.summary
        return """
        Locked vowel time: \(formatSeconds(summary.lockedVowelTime)) of \
        \(formatSeconds(summary.analyzableVowelTime)) analyzable vowel time \
        (\(formatPercent(summary.lockedVowelRatio))). Ringing vowel time: \
        \(formatSeconds(summary.ringingVowelTime)) (\(formatPercent(summary.ringingVowelRatio))).
        """
    }

    private var phraseLegend: some View {
        HStack(spacing: 10) {
            ForEach(PhraseTimelineSegmentKind.legendOrder, id: \.self) { kind in
                Label(kind.title, systemImage: "square.fill")
                    .foregroundStyle(color(for: kind))
            }
        }
        .font(.caption2)
    }

    private var summaryGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            metricRow("Phrase duration", analysis.summary.phraseDuration)
            metricRow("Consonant/onset time", analysis.summary.consonantOnsetTime)
            metricRow("Analyzable vowel time", analysis.summary.analyzableVowelTime)
            metricRow("Locked vowel time", analysis.summary.lockedVowelTime)
            metricRow("Ringing vowel time", analysis.summary.ringingVowelTime)
            metricRow("Tuning/searching time", analysis.summary.tuningSearchingTime)
            metricRow("Stable, not ringing time", analysis.summary.stableButNotRingingTime)
            metricRow("Breath/silence time", analysis.summary.silenceBreathTime)
            metricRow("Low-confidence time", analysis.summary.lowConfidenceTime)
        }
        .font(.caption)
    }

    private func metricRow(_ title: String, _ value: TimeInterval) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(formatSeconds(value))
                .monospacedDigit()
        }
    }
}

private struct PhraseTimelineView: View {
    let segments: [PhraseTimelineSegment]

    var body: some View {
        Canvas { context, size in
            guard duration > 0 else {
                return
            }

            for segment in segments {
                let startX = size.width * segment.startTime / duration
                let endX = size.width * segment.endTime / duration
                let rect = CGRect(
                    x: startX,
                    y: 0,
                    width: max(endX - startX, 1),
                    height: size.height
                )
                context.fill(Path(rect), with: .color(color(for: segment.kind).opacity(0.84)))
            }
        }
        .frame(height: 42)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }

    private var duration: Double {
        segments.map(\.endTime).max() ?? 0
    }
}

private func color(for kind: PhraseTimelineSegmentKind) -> Color {
    switch kind {
    case .silenceOrBreath:
        .gray
    case .lowConfidence:
        .red
    case .consonantOrOnset:
        .orange
    case .transition:
        .yellow
    case .tuningOrSearching:
        .teal
    case .stableButNotRinging:
        .blue
    case .locked:
        .green
    case .ringing:
        .purple
    }
}

private func formatSeconds(_ value: TimeInterval) -> String {
    value.formatted(.number.precision(.fractionLength(1))) + "s"
}

private func formatPercent(_ value: Double) -> String {
    value.formatted(.percent.precision(.fractionLength(0)))
}
