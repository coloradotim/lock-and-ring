@testable import LockAndRing
import XCTest

final class SpectrumAnalyzerTests: XCTestCase {
    func testPlaceholderFrameHasExpectedMeterShape() {
        let frame = SpectrumAnalyzer().analyzePlaceholderFrame()

        XCTAssertEqual(frame.meters.lock.value, 0)
        XCTAssertEqual(frame.meters.ring.value, 0)
        XCTAssertEqual(frame.meters.roughness.value, 0)
        XCTAssertEqual(frame.meters.stability.value, 0)
    }

    func testPureSineWaveProducesStablePeakNearFrequency() {
        let analyzer = SpectrumAnalyzer(fftSize: 2_048, smoothingFactor: 1)
        let samples = sineWave(frequency: 440, sampleRate: 44_100, count: 2_048)

        let spectrum = analyzer.analyze(samples: samples, sampleRate: 44_100)
        let strongestPeak = spectrum.peaks.max { $0.magnitude < $1.magnitude }

        XCTAssertNotNil(strongestPeak)
        XCTAssertEqual(strongestPeak?.frequency ?? 0, 440, accuracy: 25)
    }

    func testHarmonicStackExtractsFundamentalAndOvertonePeaks() {
        let analyzer = SpectrumAnalyzer(fftSize: 4_096, smoothingFactor: 1)
        let samples = mixedSignal(
            frequencies: [220, 440, 660],
            amplitudes: [1, 0.65, 0.45],
            sampleRate: 44_100,
            count: 4_096
        )

        let spectrum = analyzer.analyze(samples: samples, sampleRate: 44_100)
        let peakFrequencies = spectrum.peaks.map(\.frequency)

        XCTAssertTrue(peakFrequencies.contains { abs($0 - 220) < 20 })
        XCTAssertTrue(peakFrequencies.contains { abs($0 - 440) < 20 })
        XCTAssertTrue(peakFrequencies.contains { abs($0 - 660) < 20 })
    }

    func testMixedIntervalExtractsBothPrimaryTones() {
        let analyzer = SpectrumAnalyzer(fftSize: 4_096, smoothingFactor: 1)
        let samples = mixedSignal(
            frequencies: [330, 495],
            amplitudes: [1, 0.9],
            sampleRate: 44_100,
            count: 4_096
        )

        let spectrum = analyzer.analyze(samples: samples, sampleRate: 44_100)
        let peakFrequencies = spectrum.peaks.map(\.frequency)

        XCTAssertTrue(peakFrequencies.contains { abs($0 - 330) < 20 })
        XCTAssertTrue(peakFrequencies.contains { abs($0 - 495) < 20 })
    }

    func testSilentInputDoesNotCreatePeaks() {
        let analyzer = SpectrumAnalyzer(fftSize: 2_048, smoothingFactor: 1)
        let samples = Array(repeating: Float(0), count: 2_048)

        let spectrum = analyzer.analyze(samples: samples, sampleRate: 44_100)

        XCTAssertTrue(spectrum.peaks.isEmpty)
    }

    private func sineWave(frequency: Double, sampleRate: Double, count: Int) -> [Float] {
        (0..<count).map { index in
            Float(sin(2 * Double.pi * frequency * Double(index) / sampleRate))
        }
    }

    private func mixedSignal(
        frequencies: [Double],
        amplitudes: [Double],
        sampleRate: Double,
        count: Int
    ) -> [Float] {
        (0..<count).map { index in
            let sample = zip(frequencies, amplitudes).reduce(Double(0)) { partialResult, component in
                let (frequency, amplitude) = component
                return partialResult + amplitude * sin(2 * Double.pi * frequency * Double(index) / sampleRate)
            }
            return Float(sample / Double(max(frequencies.count, 1)))
        }
    }
}
