@testable import LockAndRing
import XCTest

final class AudioFrameNormalizerTests: XCTestCase {
    func testMonoFrameReportsLevelAndSignal() {
        let frame = AudioFrameNormalizer.makeFrame(
            channels: [[0.25, -0.25, 0.25, -0.25]],
            sampleRate: 48_000
        )

        XCTAssertEqual(frame?.sampleRate, 48_000)
        XCTAssertEqual(frame?.frameSize, 4)
        XCTAssertEqual(frame?.channelCount, 1)
        XCTAssertEqual(frame?.monoSamples, [0.25, -0.25, 0.25, -0.25])
        XCTAssertEqual(frame?.instrumentation.rmsLevel ?? 0, 0.25, accuracy: 0.001)
        XCTAssertEqual(frame?.instrumentation.channelRMSLevels.count, 1)
        XCTAssertEqual(frame?.instrumentation.hasSignal, true)
    }

    func testStereoFramePreservesChannelsAndDownmixesToMono() {
        let frame = AudioFrameNormalizer.makeFrame(
            channels: [
                [0.4, 0.2, -0.2, -0.4],
                [0.2, 0.0, -0.4, -0.2]
            ],
            sampleRate: 44_100
        )

        XCTAssertEqual(frame?.channelCount, 2)
        XCTAssertEqual(frame?.channelSamples[0], [0.4, 0.2, -0.2, -0.4])
        XCTAssertEqual(frame?.channelSamples[1], [0.2, 0.0, -0.4, -0.2])
        XCTAssertEqual(frame?.monoSamples, [0.3, 0.1, -0.3, -0.3])
        XCTAssertEqual(frame?.instrumentation.channelRMSLevels.count, 2)
    }

    func testClippingIsDetectedPerChannel() {
        let frame = AudioFrameNormalizer.makeFrame(
            channels: [
                [0.1, 0.2, 0.99],
                [0.1, 0.2, 0.3]
            ],
            sampleRate: 44_100
        )

        XCTAssertEqual(frame?.instrumentation.isClipping, true)
        XCTAssertEqual(frame?.instrumentation.channelClipping, [true, false])
    }

    func testMajorStereoImbalanceIsDetected() {
        let frame = AudioFrameNormalizer.makeFrame(
            channels: [
                [0.8, 0.8, 0.8, 0.8],
                [0.05, 0.05, 0.05, 0.05]
            ],
            sampleRate: 44_100
        )

        XCTAssertEqual(frame?.instrumentation.hasChannelImbalance, true)
    }

    func testEmptyChannelsDoNotProduceFrame() {
        XCTAssertNil(AudioFrameNormalizer.makeFrame(channels: [], sampleRate: 44_100))
        XCTAssertNil(AudioFrameNormalizer.makeFrame(channels: [[]], sampleRate: 44_100))
    }
}
