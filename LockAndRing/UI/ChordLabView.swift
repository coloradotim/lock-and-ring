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
            VStack(alignment: .leading, spacing: 12) {
                if let warning = ChordTimingDisplayState(analysis: analysis).warningMessage {
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                ChordLabSummaryGrid(summary: analysis.summary)
                ChordTimelineView(analysis: analysis)
                ChordLabMarkerList(markers: analysis.eventMarkers)
            }
        } else {
            Text("No chord analysis yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ChordLabSummaryGrid: View {
    let summary: ChordTimingSummary

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
            row("Consonants/onset", seconds(summary.consonantOnsetDuration))
            row("Vowel to lock", seconds(summary.timeFromVowelToLock))
            row("Vowel to ring", seconds(summary.timeFromVowelToRing))
            row("Best lock", peak(score: summary.bestLockScore, time: summary.bestLockTime))
            row("Best ring", peak(score: summary.bestRingScore, time: summary.bestRingTime))
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
                .frame(width: 118, alignment: .leading)

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

            HStack(spacing: 10) {
                ForEach(ChordTimelineSegmentKind.legendOrder, id: \.self) { kind in
                    Label(kind.title, systemImage: "square.fill")
                        .foregroundStyle(color(for: kind))
                }
            }
            .font(.caption2)
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
        switch kind {
        case .silence:
            .gray
        case .consonantOrOnset:
            .orange
        case .searching:
            .yellow
        case .stable:
            .teal
        case .locked:
            .green
        case .ringing:
            .mint
        case .lowConfidence:
            .red
        }
    }
}

private struct ChordLabMarkerList: View {
    let markers: [ChordEventMarker]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(markers) { marker in
                Text("\(marker.kind.title): \(marker.time.formatted(.number.precision(.fractionLength(2))))s")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}

private extension ChordTimelineSegmentKind {
    static let legendOrder: [ChordTimelineSegmentKind] = [
        .silence,
        .consonantOrOnset,
        .searching,
        .stable,
        .locked,
        .ringing,
        .lowConfidence
    ]
}
