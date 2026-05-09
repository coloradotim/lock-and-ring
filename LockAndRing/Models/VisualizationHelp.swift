import Foundation

struct VisualizationLegendEntry: Identifiable, Equatable, Sendable {
    let kind: ChordTimelineSegmentKind

    var id: ChordTimelineSegmentKind {
        kind
    }

    var title: String {
        kind.title
    }

    var explanation: String {
        switch kind {
        case .silence:
            "No reliable musical signal was detected."
        case .consonantOrOnset:
            "Broadband transient energy before the target vowel becomes analyzable."
        case .searching:
            "The chord is sounding, but the app has not found stable lock yet."
        case .stable:
            "The sound is steadier, though not yet over the lock threshold."
        case .locked:
            "The spectrum was stable, roughness was low, and harmonic alignment stayed above threshold."
        case .ringing:
            "Upper harmonic energy increased while roughness remained low."
        case .lowConfidence:
            "The app does not trust this section enough to make a strong musical claim."
        }
    }
}

enum VisualizationHelpCopy {
    static let legendEntries: [VisualizationLegendEntry] =
        ChordTimelineSegmentKind.legendOrder.map(VisualizationLegendEntry.init(kind:))

    static let howToRead = """
    The waveform shows timing, consonants, breaths, and transients. The spectrogram shows where sound energy lives over time. Upper bands can indicate stronger upper harmonics, but the app only treats this as ring when those harmonics are organized and roughness stays low. Colored regions show what the app detected, so you do not have to read the raw spectrogram yourself.
    """

    static let waveform = "Waveform = timing, onset, consonants, breath, and volume/transients."

    static let spectrogram =
        "Spectrogram = harmonic structure, upper partials, stability, ring, roughness, and noise."

    static let metrics =
        "Metric curves and colored overlays are the app interpretation layer; trust them more than raw color intensity."
}

struct TimelineMarkerLabel: Identifiable, Equatable, Sendable {
    let marker: ChordEventMarker

    var id: UUID {
        marker.id
    }

    var title: String {
        marker.kind.title
    }

    var timeText: String {
        marker.time.formatted(.number.precision(.fractionLength(2))) + "s"
    }
}

extension Array where Element == TimelineMarkerLabel {
    init(markers: [ChordEventMarker]) {
        self = markers.map(TimelineMarkerLabel.init(marker:))
    }
}
