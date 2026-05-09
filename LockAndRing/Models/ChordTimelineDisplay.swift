import Foundation

enum ChordTimelineSegmentKind: String, Equatable, Hashable, Sendable {
    case silence
    case consonantOrOnset
    case searching
    case stable
    case locked
    case ringing
    case lowConfidence

    var title: String {
        switch self {
        case .silence:
            "Silence"
        case .consonantOrOnset:
            "Consonant / onset"
        case .searching:
            "Searching"
        case .stable:
            "Stable"
        case .locked:
            "Locked"
        case .ringing:
            "Ringing"
        case .lowConfidence:
            "Low confidence"
        }
    }

    var paletteToken: ChordTimelinePaletteToken {
        switch self {
        case .silence:
            .neutralGray
        case .consonantOrOnset:
            .orange
        case .searching:
            .amber
        case .stable:
            .blue
        case .locked:
            .green
        case .ringing:
            .purple
        case .lowConfidence:
            .red
        }
    }
}

enum ChordTimelinePaletteToken: Equatable, Hashable, Sendable {
    case neutralGray
    case orange
    case amber
    case blue
    case green
    case purple
    case red
}

extension ChordTimelineSegmentKind {
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

struct ChordEventMarker: Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: ChordEventMarkerKind
    let time: TimeInterval

    init(id: UUID = UUID(), kind: ChordEventMarkerKind, time: TimeInterval) {
        self.id = id
        self.kind = kind
        self.time = time
    }
}

enum ChordEventMarkerKind: String, Equatable, Sendable {
    case soundOnset
    case analyzableVowelStart
    case lockAchieved
    case ringAchieved
    case bestLock
    case bestRing

    var title: String {
        switch self {
        case .soundOnset:
            "Sound onset"
        case .analyzableVowelStart:
            "Vowel start"
        case .lockAchieved:
            "Lock"
        case .ringAchieved:
            "Ring"
        case .bestLock:
            "Best locked vowel"
        case .bestRing:
            "Best ringing vowel"
        }
    }
}
