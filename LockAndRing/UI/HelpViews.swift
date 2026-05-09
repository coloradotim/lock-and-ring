import SwiftUI

struct ModeHelpDisclosure: View {
    let mode: AppMode

    var body: some View {
        DisclosureGroup("How to use this mode") {
            Text(helpText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
        .padding(12)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
    }

    private var helpText: String {
        switch mode {
        case .live:
            "Use Live Rehearsal while singing. Start with signal status, then read changes and quality labels."
        case .takes:
            "Record Take 1, make one musical adjustment, record Take 2, then compare the plain-language result."
        case .file:
            "Import a recording, play or scrub it, and inspect quality plus spectrum detail at the playback point."
        }
    }
}

struct MetricHelpDisclosure: View {
    var body: some View {
        DisclosureGroup("What do these metrics mean?") {
            VStack(alignment: .leading, spacing: 8) {
                helpRow("Lock", "How organized and stable the chord appears harmonically.")
                helpRow("Ring", "Upper harmonic reinforcement that often grows when the chord lines up.")
                helpRow("Roughness", "Interference, beating, or instability. Lower is usually better.")
                helpRow("Stability", "Whether the sound stays organized over time.")
                helpRow("Confidence", "How much the app trusts the measurement under current signal conditions.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 6)
        }
    }

    private func helpRow(_ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .fontWeight(.semibold)
                .frame(width: 70, alignment: .leading)

            Text(text)
        }
    }
}

struct SpectrogramHelpDisclosure: View {
    var body: some View {
        DisclosureGroup("How to read this") {
            VStack(alignment: .leading, spacing: 8) {
                Text(VisualizationHelpCopy.howToRead)
                helpRow(VisualizationHelpCopy.waveform)
                helpRow(VisualizationHelpCopy.spectrogram)
                helpRow(VisualizationHelpCopy.metrics)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 6)
        }
    }

    private func helpRow(_ text: String) -> some View {
        Label(text, systemImage: "info.circle")
            .labelStyle(.titleAndIcon)
    }
}

struct VisualizationLegend: View {
    let entries: [VisualizationLegendEntry]

    init(entries: [VisualizationLegendEntry] = VisualizationHelpCopy.legendEntries) {
        self.entries = entries
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                ForEach(entries) { entry in
                    Label(entry.title, systemImage: "square.fill")
                        .foregroundStyle(color(for: entry.kind))
                }
            }
            .font(.caption2)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(entries) { entry in
                    Text("\(entry.title): \(entry.explanation)")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
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
