@testable import LockAndRing
import XCTest

final class OfflineAudioAnalyzerTests: XCTestCase {
    func testClipFramesUseRequestedTimeAndPadAtEnd() {
        let clip = OfflineAudioClip(
            fileName: "fixture.wav",
            sampleRate: 10,
            monoSamples: [0, 0.1, 0.2, 0.3, 0.4],
            channelSamples: [[0, 0.1, 0.2, 0.3, 0.4]]
        )

        let frame = clip.frame(at: 0.3, frameSize: 4)

        XCTAssertEqual(frame?.hostTime, 3)
        XCTAssertEqual(frame?.sampleRate, 10)
        XCTAssertEqual(frame?.monoSamples ?? [], [0.3, 0.4, 0, 0])
    }

    func testClipFramesPreserveStereoChannels() {
        let clip = OfflineAudioClip(
            fileName: "fixture.wav",
            sampleRate: 10,
            monoSamples: [0, 0.2, 0.4, 0.6],
            channelSamples: [
                [0, 0.2, 0.4, 0.6],
                [0, -0.2, -0.4, -0.6]
            ]
        )

        let frame = clip.frame(at: 0.1, frameSize: 3)

        XCTAssertEqual(frame?.channelCount, 2)
        XCTAssertEqual(frame?.channelSamples[0], [0.2, 0.4, 0.6])
        XCTAssertEqual(frame?.channelSamples[1], [-0.2, -0.4, -0.6])
        XCTAssertEqual(frame?.monoSamples ?? [], [0, 0, 0])
    }

    func testClipDurationUsesSampleRate() {
        let clip = OfflineAudioClip(
            fileName: "fixture.wav",
            sampleRate: 4,
            monoSamples: [0, 0, 0, 0, 0, 0],
            channelSamples: [[0, 0, 0, 0, 0, 0]]
        )

        XCTAssertEqual(clip.duration, 1.5)
    }
}
