@testable import LockAndRing
import XCTest

final class MainWorkflowStateTests: XCTestCase {
    func testReadyStateKeepsRecordTakePrimary() {
        XCTAssertEqual(MainWorkflowState.ready.title, "Ready")
        XCTAssertEqual(MainWorkflowState.ready.primaryActionTitle, "Record Take")
        XCTAssertFalse(MainWorkflowState.ready.showsTakeAnalysis)
    }

    func testReviewAndCompareStatesShowTakeAnalysis() {
        XCTAssertTrue(MainWorkflowState.reviewingTake.showsTakeAnalysis)
        XCTAssertTrue(MainWorkflowState.comparing.showsTakeAnalysis)
        XCTAssertEqual(MainWorkflowState.reviewingTake.title, "Take Analysis")
        XCTAssertEqual(MainWorkflowState.comparing.primaryActionTitle, "Back to Take Analysis")
    }

    func testRecordingStateKeepsStopPrimary() {
        let state = MainWorkflowState.recording(startedAt: Date(timeIntervalSince1970: 10))

        XCTAssertEqual(state.title, "Recording")
        XCTAssertEqual(state.primaryActionTitle, "Stop")
        XCTAssertFalse(state.showsTakeAnalysis)
    }
}
