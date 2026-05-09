@testable import LockAndRing
import XCTest

final class VisualizationHelpTests: XCTestCase {
    func testLegendEntriesMatchTimelineKinds() {
        XCTAssertEqual(
            VisualizationHelpCopy.legendEntries.map(\.kind),
            ChordTimelineSegmentKind.legendOrder
        )
    }

    func testLegendExplainsRequiredRegionKinds() {
        let explanations = Dictionary(
            uniqueKeysWithValues: VisualizationHelpCopy.legendEntries.map { ($0.kind, $0.explanation) }
        )

        XCTAssertTrue(explanations[.consonantOrOnset]?.contains("transient") == true)
        XCTAssertTrue(explanations[.locked]?.contains("harmonic alignment") == true)
        XCTAssertTrue(explanations[.ringing]?.contains("Upper harmonic") == true)
        XCTAssertTrue(explanations[.lowConfidence]?.contains("does not trust") == true)
    }

    func testHelpCopyExplainsWaveformSpectrogramAndOverlays() {
        XCTAssertTrue(VisualizationHelpCopy.waveform.contains("timing"))
        XCTAssertTrue(VisualizationHelpCopy.spectrogram.contains("harmonic structure"))
        XCTAssertTrue(VisualizationHelpCopy.metrics.contains("interpretation layer"))
        XCTAssertTrue(VisualizationHelpCopy.howToRead.contains("Colored regions"))
    }

    func testMissingMarkersProduceNoLabels() {
        XCTAssertTrue([TimelineMarkerLabel](markers: []).isEmpty)
    }

    func testMarkerLabelsFormatTimes() {
        let marker = ChordEventMarker(kind: .bestRing, time: 1.234)
        let label = [TimelineMarkerLabel](markers: [marker]).first

        XCTAssertEqual(label?.title, "Best ringing vowel")
        XCTAssertEqual(label?.timeText, "1.23s")
    }
}
