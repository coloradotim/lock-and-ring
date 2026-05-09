import Foundation

enum MainWorkflowState: Equatable, Sendable {
    case ready
    case recording(startedAt: Date)
    case analyzing
    case reviewingTake
    case comparing

    var title: String {
        switch self {
        case .ready:
            "Ready"
        case .recording:
            "Recording"
        case .analyzing:
            "Analyzing"
        case .reviewingTake:
            "Take Analysis"
        case .comparing:
            "Comparison"
        }
    }

    var primaryActionTitle: String {
        switch self {
        case .ready:
            "Record Take"
        case .recording:
            "Stop"
        case .analyzing:
            "Analyzing..."
        case .reviewingTake:
            "Record Again"
        case .comparing:
            "Back to Take Analysis"
        }
    }

    var showsTakeAnalysis: Bool {
        switch self {
        case .reviewingTake, .comparing:
            true
        case .ready, .recording, .analyzing:
            false
        }
    }
}
