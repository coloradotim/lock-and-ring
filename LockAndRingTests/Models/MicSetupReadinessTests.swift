@testable import LockAndRing
import XCTest

final class MicSetupReadinessTests: XCTestCase {
    func testNominalSignalMapsToReadyGuidance() throws {
        let state = MicSetupReadinessDisplayState(
            inputName: "External Mic",
            inputState: .running,
            frame: try frame(samples: cleanSamples(amplitude: 0.2)),
            signal: nil
        )

        XCTAssertEqual(state.kind, .ready)
        XCTAssertEqual(state.setupCheckResult, "Setup looks usable.")
        XCTAssertTrue(state.compactItems.contains("Mic: External Mic"))
        XCTAssertTrue(state.compactItems.contains("Level: good"))
    }

    func testQuietSignalMapsToMoveCloserGuidance() throws {
        let state = MicSetupReadinessDisplayState(
            inputName: "Built-in Mic",
            inputState: .running,
            frame: try frame(samples: alternatingSamples(amplitude: 0.01)),
            signal: nil
        )

        XCTAssertEqual(state.kind, .tooQuiet)
        XCTAssertEqual(state.recommendation, "Move closer to the mic or sing slightly louder.")
    }

    func testClippedInputMapsToGainGuidance() throws {
        let state = MicSetupReadinessDisplayState(
            inputName: "USB Mic",
            inputState: .running,
            frame: try frame(samples: [0.99, -0.99, 0.4, -0.4]),
            signal: nil
        )

        XCTAssertEqual(state.kind, .clipping)
        XCTAssertEqual(state.recommendation, "Lower input gain or move the mic farther away.")
    }

    func testStereoImbalanceMapsToXYMicGuidance() throws {
        let state = MicSetupReadinessDisplayState(
            inputName: "External XY Mic",
            inputState: .running,
            frame: try frame(
                channels: [
                    alternatingSamples(amplitude: 0.4),
                    alternatingSamples(amplitude: 0.05)
                ]
            ),
            signal: nil
        )

        XCTAssertEqual(state.kind, .stereoImbalance)
        XCTAssertEqual(
            state.recommendation,
            "Reposition the XY mic or singers so the stereo image is centered."
        )
    }

    func testNoisyInputMapsToRoomGuidance() throws {
        let state = MicSetupReadinessDisplayState(
            inputName: "Room Mic",
            inputState: .running,
            frame: try frame(samples: Array(repeating: 0.08, count: 32)),
            signal: nil
        )

        XCTAssertEqual(state.kind, .noisyRoom)
        XCTAssertEqual(state.recommendation, "Move away from fans or HVAC, or choose a quieter room.")
    }

    func testPreparingAndPermissionStatesUseDeterministicCopy() {
        let preparing = MicSetupReadinessDisplayState(
            inputName: "Default Microphone",
            inputState: .requestingPermission,
            frame: nil,
            signal: nil
        )
        let needsPermission = MicSetupReadinessDisplayState(
            inputName: "Default Microphone",
            inputState: .permissionDenied,
            frame: nil,
            signal: nil
        )

        XCTAssertEqual(preparing.kind, .preparing)
        XCTAssertEqual(preparing.recommendation, "Use Check Mic Setup after singing or speaking for 3 seconds.")
        XCTAssertEqual(needsPermission.kind, .needsPermission)
        XCTAssertEqual(
            needsPermission.recommendation,
            "Grant microphone permission in macOS settings, then try again."
        )
    }

    private func frame(samples: [Float]) throws -> AudioInputFrame {
        try XCTUnwrap(
            AudioFrameNormalizer.makeFrame(channels: [samples], sampleRate: 44_100)
        )
    }

    private func frame(channels: [[Float]]) throws -> AudioInputFrame {
        try XCTUnwrap(
            AudioFrameNormalizer.makeFrame(channels: channels, sampleRate: 44_100)
        )
    }

    private func alternatingSamples(amplitude: Float) -> [Float] {
        Array(repeating: [amplitude, -amplitude], count: 16).flatMap { $0 }
    }

    private func cleanSamples(amplitude: Float) -> [Float] {
        Array(repeating: [0, amplitude, 0, -amplitude], count: 8).flatMap { $0 }
    }
}
