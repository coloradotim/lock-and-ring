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
            fileType: "wav",
            sampleRate: 4,
            monoSamples: [0, 0, 0, 0, 0, 0],
            channelSamples: [[0, 0, 0, 0, 0, 0]]
        )

        XCTAssertEqual(clip.duration, 1.5)
    }

    func testImportDiagnosticsDescribeAnalysisPath() {
        let clip = OfflineAudioClip(
            fileName: "fixture.mp3",
            fileType: "mp3",
            sampleRate: 44_100,
            channelSamples: [
                [0, 0.5, 1.0, 0.5],
                [0, 0.5, 1.0, 0.5]
            ]
        )

        XCTAssertEqual(clip.diagnostics.sourceType, .imported)
        XCTAssertEqual(clip.diagnostics.fileType, "mp3")
        XCTAssertEqual(clip.diagnostics.channelCount, 2)
        XCTAssertEqual(clip.diagnostics.sourceSampleRate, 44_100)
        XCTAssertEqual(clip.diagnostics.analysisSampleRate, 44_100)
        XCTAssertEqual(clip.diagnostics.monoConversionBehavior, "Simple channel average from decoded PCM.")
        XCTAssertEqual(clip.diagnostics.normalizationBehavior, "No gain normalization is applied before analysis.")
        XCTAssertEqual(clip.diagnostics.peakLevel, 1.0)
        XCTAssertEqual(clip.diagnostics.clippingRatio, 0.25)
        XCTAssertEqual(clip.diagnostics.stereoCorrelation ?? 0, 1.0, accuracy: 0.001)
    }
}
