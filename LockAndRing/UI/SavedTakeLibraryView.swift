import SwiftUI

struct SavedTakeLibraryView: View {
    let savedTakes: [SavedTake]
    let onPlay: (SavedTake) -> Void
    let onAnalyze: (SavedTake) -> Void
    let onCompare: (SavedTake) -> Void
    let onRename: (SavedTake, String) -> Void
    let onDelete: (SavedTake) -> Void

    var body: some View {
        RehearsalPanel(title: "Saved Takes") {
            if savedTakes.isEmpty {
                Text("No saved takes yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(savedTakes) { take in
                        SavedTakeRow(
                            take: take,
                            onPlay: onPlay,
                            onAnalyze: onAnalyze,
                            onCompare: onCompare,
                            onRename: onRename,
                            onDelete: onDelete
                        )
                    }
                }
            }
        }
    }
}

private struct SavedTakeRow: View {
    let take: SavedTake
    let onPlay: (SavedTake) -> Void
    let onAnalyze: (SavedTake) -> Void
    let onCompare: (SavedTake) -> Void
    let onRename: (SavedTake, String) -> Void
    let onDelete: (SavedTake) -> Void
    @State private var draftName: String

    init(
        take: SavedTake,
        onPlay: @escaping (SavedTake) -> Void,
        onAnalyze: @escaping (SavedTake) -> Void,
        onCompare: @escaping (SavedTake) -> Void,
        onRename: @escaping (SavedTake, String) -> Void,
        onDelete: @escaping (SavedTake) -> Void
    ) {
        self.take = take
        self.onPlay = onPlay
        self.onAnalyze = onAnalyze
        self.onCompare = onCompare
        self.onRename = onRename
        self.onDelete = onDelete
        _draftName = State(initialValue: take.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                TextField("Take name", text: $draftName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)
                    .onSubmit {
                        onRename(take, draftName)
                    }

                Text(metadataText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let confidence = take.signalConfidence {
                    Text(confidence, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                Button("Play") {
                    onPlay(take)
                }

                Button("View") {
                    onAnalyze(take)
                }

                Button("Compare") {
                    onCompare(take)
                }

                Button("Rename") {
                    onRename(take, draftName)
                }

                Button("Delete", role: .destructive) {
                    onDelete(take)
                }
            }
            .font(.caption)
        }
        .padding(10)
        .background(.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }

    private var metadataText: String {
        let duration = take.duration.formatted(.number.precision(.fractionLength(1))) + "s"
        return "\(take.source.title) - \(duration) - \(take.createdAt.formatted(date: .abbreviated, time: .shortened))"
    }
}
