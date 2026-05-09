import SwiftUI

struct TimelineComparisonPanel: View {
    let comparison: TakeTimelineComparison
    @Binding var mode: TakeTimelineComparison.DisplayMode

    var body: some View {
        RehearsalPanel(title: "Timeline Comparison") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Comparison view", selection: $mode) {
                    Text("Side-by-side").tag(TakeTimelineComparison.DisplayMode.sideBySide)
                    Text("Overlay").tag(TakeTimelineComparison.DisplayMode.overlay)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)

                if let warning = comparison.warning {
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                ForEach(comparison.summaryLines, id: \.self) { line in
                    Text(line)
                        .font(.caption.weight(.semibold))
                }

                switch mode {
                case .sideBySide:
                    VStack(alignment: .leading, spacing: 10) {
                        alignedRow(comparison.reference)
                        alignedRow(comparison.current)
                    }
                case .overlay:
                    TimelineOverlayCanvas(
                        reference: comparison.reference.metricSeries,
                        current: comparison.current.metricSeries
                    )
                }
            }
        }
    }

    private func alignedRow(_ timeline: AlignedTakeTimeline) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(timeline.role)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("Aligned at \(formatSeconds(timeline.alignmentOffset))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            PhraseTimelineStrip(segments: timeline.phraseAnalysis.timelineSegments)

            if !timeline.markers.isEmpty {
                Text(markerText(timeline.markers))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func markerText(_ markers: [TimelineMarker]) -> String {
        markers.map { "\($0.title): \(formatSeconds($0.time))" }
            .joined(separator: "  ")
    }
}

private struct PhraseTimelineStrip: View {
    let segments: [PhraseTimelineSegment]

    var body: some View {
        Canvas { context, size in
            guard let duration = segments.map(\.endTime).max(), duration > 0 else {
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
                context.fill(Path(rect), with: .color(phraseColor(for: segment.kind).opacity(0.84)))
            }
        }
        .frame(height: 28)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct TimelineOverlayCanvas: View {
    let reference: [TimelineMetricSeries]
    let current: [TimelineMetricSeries]

    var body: some View {
        Canvas { context, size in
            draw(series: reference, color: .cyan, context: &context, size: size)
            draw(series: current, color: .mint, context: &context, size: size)
        }
        .frame(height: 130)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
        .overlay(alignment: .topLeading) {
            Text("Reference cyan | Current mint")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(6)
        }
    }

    private func draw(
        series: [TimelineMetricSeries],
        color: Color,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        for (index, metricSeries) in series.enumerated() {
            let points = metricSeries.points
            guard let minTime = points.map(\.time).min(),
                  let maxTime = points.map(\.time).max(),
                  maxTime > minTime else {
                continue
            }

            var path = Path()
            for (pointIndex, point) in points.enumerated() {
                let xPosition = size.width * (point.time - minTime) / (maxTime - minTime)
                let laneHeight = size.height / Double(max(series.count, 1))
                let laneTop = laneHeight * Double(index)
                let yPosition = laneTop + laneHeight * (1 - min(max(point.value, 0), 1))

                if pointIndex == 0 {
                    path.move(to: CGPoint(x: xPosition, y: yPosition))
                } else {
                    path.addLine(to: CGPoint(x: xPosition, y: yPosition))
                }
            }

            context.stroke(path, with: .color(color.opacity(0.85)), lineWidth: 2)
        }
    }
}

private func phraseColor(for kind: PhraseTimelineSegmentKind) -> Color {
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
    value.formatted(.number.precision(.fractionLength(2))) + "s"
}
