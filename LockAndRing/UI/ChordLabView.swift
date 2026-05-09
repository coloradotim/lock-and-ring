import SwiftUI

struct ChordLabView: View {
    let title: String
    let analysis: ChordLabAnalysis?
    var showsPanelChrome = true

    var body: some View {
        if showsPanelChrome {
            RehearsalPanel(title: title) {
                content
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let analysis, analysis.summary.soundOnsetTime != nil {
            let displayState = ChordTimingDisplayState(analysis: analysis)

            VStack(alignment: .leading, spacing: 12) {
                Text(displayState.lockSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                if let warning = displayState.warningMessage {
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                ChordLabSummaryGrid(summary: analysis.summary)
                ChordTimelineView(analysis: analysis)
                VisualizationLegend(entries: visibleLegendEntries(for: analysis))
                ChordLabMarkerList(markers: analysis.eventMarkers)
            }
        } else {
            Text("No chord analysis yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func visibleLegendEntries(for analysis: ChordLabAnalysis) -> [VisualizationLegendEntry] {
        let visibleKinds = Set(analysis.timelineSegments.map(\.kind))
        return VisualizationHelpCopy.legendEntries.filter { visibleKinds.contains($0.kind) }
    }
}

private struct ChordLabSummaryGrid: View {
    let summary: ChordTimingSummary

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
            row("Consonants/onset", seconds(summary.consonantOnsetDuration))
            row("Vowel start", seconds(summary.analyzableVowelStartTime))
            row("Vowel to stable", seconds(summary.timeFromVowelToStability))
            row("Vowel to lock", seconds(summary.timeFromVowelToLock))
            row("Vowel to ring", seconds(summary.timeFromVowelToRing))
            row("Best locked vowel", peak(score: summary.bestLockScore, time: summary.bestLockTime))
            row("Best ringing vowel", peak(score: summary.bestRingScore, time: summary.bestRingTime))
            row("Held lock", seconds(summary.heldLockDuration))
            row("Held ring", seconds(summary.heldRingDuration))
            row("Main delay", summary.largestDelayContributor.title)
        }
        .font(.caption)
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 138, alignment: .leading)

            Text(value)
                .monospacedDigit()
        }
    }

    private func seconds(_ value: Double?) -> String {
        guard let value else {
            return "--"
        }

        return value.formatted(.number.precision(.fractionLength(2))) + "s"
    }

    private func peak(score: Double?, time: Double?) -> String {
        guard let score, let time else {
            return "--"
        }

        return "\(score.formatted(.percent.precision(.fractionLength(0)))) at \(seconds(time))"
    }
}

private struct ChordTimelineView: View {
    let analysis: ChordLabAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Canvas { context, size in
                drawSegments(context: &context, size: size)
                drawMarkers(context: &context, size: size)
            }
            .frame(height: 38)
            .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))

            Text("Colored regions are app interpretation, not raw spectrogram data.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var duration: Double {
        analysis.timelineSegments.map(\.endTime).max() ?? 0
    }

    private func drawSegments(context: inout GraphicsContext, size: CGSize) {
        guard duration > 0 else {
            return
        }

        for segment in analysis.timelineSegments {
            let startX = size.width * segment.startTime / duration
            let endX = size.width * segment.endTime / duration
            let rect = CGRect(
                x: startX,
                y: 0,
                width: max(endX - startX, 1),
                height: size.height
            )
            context.fill(Path(rect), with: .color(color(for: segment.kind).opacity(0.82)))
        }
    }

    private func drawMarkers(context: inout GraphicsContext, size: CGSize) {
        guard duration > 0 else {
            return
        }

        for marker in analysis.eventMarkers {
            let xPosition = size.width * marker.time / duration
            let path = Path { path in
                path.move(to: CGPoint(x: xPosition, y: 0))
                path.addLine(to: CGPoint(x: xPosition, y: size.height))
            }
            context.stroke(path, with: .color(.white.opacity(0.88)), lineWidth: 1)
        }
    }

    private func color(for kind: ChordTimelineSegmentKind) -> Color {
        switch kind.paletteToken {
        case .neutralGray:
            .gray
        case .orange:
            .orange
        case .amber:
            .yellow
        case .blue:
            .blue
        case .green:
            .green
        case .purple:
            .purple
        case .red:
            .red
        }
    }
}

private struct ChordLabMarkerList: View {
    let markers: [ChordEventMarker]

    var body: some View {
        let labels = [TimelineMarkerLabel](markers: markers)

        VStack(alignment: .leading, spacing: 6) {
            Text("Markers")
                .font(.caption.weight(.semibold))

            if labels.isEmpty {
                Text("No reliable marker times were available for this take.")
            } else {
                HStack(spacing: 12) {
                    ForEach(labels) { label in
                        Text("\(label.title): \(label.timeText)")
                    }
                }
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}
