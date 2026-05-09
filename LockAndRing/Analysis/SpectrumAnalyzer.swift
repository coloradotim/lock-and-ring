import Accelerate
import Foundation

final class SpectrumAnalyzer {
    private let fftSize: Int
    private let log2FFTSize: vDSP_Length
    private let smoothingFactor: Float
    private let setup: FFTSetup
    private let window: [Float]
    private var previousMagnitudes: [Float]

    init(fftSize: Int = 2_048, smoothingFactor: Float = 0.25) {
        precondition(fftSize > 0 && fftSize.isPowerOfTwo, "FFT size must be a positive power of two.")

        self.fftSize = fftSize
        self.log2FFTSize = vDSP_Length(log2(Float(fftSize)))
        self.smoothingFactor = min(max(smoothingFactor, 0), 1)
        self.previousMagnitudes = Array(repeating: 0, count: fftSize / 2)

        var hannWindow = Array(repeating: Float(0), count: fftSize)
        vDSP_hann_window(&hannWindow, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        self.window = hannWindow

        guard let setup = vDSP_create_fftsetup(log2FFTSize, FFTRadix(kFFTRadix2)) else {
            fatalError("Unable to create FFT setup for size \(fftSize).")
        }
        self.setup = setup
    }

    deinit {
        vDSP_destroy_fftsetup(setup)
    }

    func analyzePlaceholderFrame() -> AnalysisFrame {
        .placeholder
    }

    func analyze(samples: [Float], sampleRate: Double) -> SpectrumSnapshot {
        let paddedSamples = paddedOrTrimmed(samples)
        var windowedSamples = Array(repeating: Float(0), count: fftSize)
        vDSP_vmul(paddedSamples, 1, window, 1, &windowedSamples, 1, vDSP_Length(fftSize))

        var real = Array(repeating: Float(0), count: fftSize / 2)
        var imaginary = Array(repeating: Float(0), count: fftSize / 2)
        var magnitudes = Array(repeating: Float(0), count: fftSize / 2)

        real.withUnsafeMutableBufferPointer { realPointer in
            imaginary.withUnsafeMutableBufferPointer { imaginaryPointer in
                guard let realBaseAddress = realPointer.baseAddress,
                      let imaginaryBaseAddress = imaginaryPointer.baseAddress else {
                    return
                }

                var splitComplex = DSPSplitComplex(
                    realp: realBaseAddress,
                    imagp: imaginaryBaseAddress
                )

                windowedSamples.withUnsafeBufferPointer { samplesPointer in
                    guard let samplesBaseAddress = samplesPointer.baseAddress else {
                        return
                    }

                    samplesBaseAddress.withMemoryRebound(
                        to: DSPComplex.self,
                        capacity: fftSize / 2
                    ) { complexPointer in
                        vDSP_ctoz(
                            complexPointer,
                            2,
                            &splitComplex,
                            1,
                            vDSP_Length(fftSize / 2)
                        )
                    }
                }

                vDSP_fft_zrip(
                    setup,
                    &splitComplex,
                    1,
                    log2FFTSize,
                    FFTDirection(FFT_FORWARD)
                )

                vDSP_zvabs(
                    &splitComplex,
                    1,
                    &magnitudes,
                    1,
                    vDSP_Length(fftSize / 2)
                )
            }
        }

        let normalizedMagnitudes = normalize(magnitudes)
        let smoothedMagnitudes = smooth(normalizedMagnitudes)
        previousMagnitudes = smoothedMagnitudes

        let bins = smoothedMagnitudes.enumerated().map { index, magnitude in
            SpectrumBin(
                frequency: Double(index) * sampleRate / Double(fftSize),
                magnitude: Double(magnitude)
            )
        }
        let peaks = extractPeaks(from: bins)

        return SpectrumSnapshot(
            sampleRate: sampleRate,
            fftSize: fftSize,
            bins: bins,
            peaks: peaks
        )
    }

    func extractPeaks(from bins: [SpectrumBin], minimumMagnitude: Double = 0.18) -> [SpectrumPeak] {
        guard bins.count >= 3 else {
            return []
        }

        let localPeaks = (1..<(bins.count - 1)).compactMap { index -> SpectrumPeak? in
            let previous = bins[index - 1]
            let current = bins[index]
            let next = bins[index + 1]

            guard current.magnitude >= minimumMagnitude,
                  current.magnitude >= previous.magnitude,
                  current.magnitude > next.magnitude else {
                return nil
            }

            return SpectrumPeak(
                frequency: current.frequency,
                magnitude: current.magnitude,
                binIndex: index
            )
        }

        return localPeaks
            .sorted { $0.magnitude > $1.magnitude }
            .prefix(8)
            .sorted { $0.frequency < $1.frequency }
    }

    private func paddedOrTrimmed(_ samples: [Float]) -> [Float] {
        if samples.count == fftSize {
            return samples
        }

        if samples.count > fftSize {
            return Array(samples.suffix(fftSize))
        }

        return samples + Array(repeating: 0, count: fftSize - samples.count)
    }

    private func normalize(_ magnitudes: [Float]) -> [Float] {
        let usableMagnitudes = Array(magnitudes.dropFirst())
        guard let maximum = usableMagnitudes.max(), maximum > 0 else {
            return magnitudes.map { _ in 0 }
        }

        return magnitudes.map { min(max($0 / maximum, 0), 1) }
    }

    private func smooth(_ magnitudes: [Float]) -> [Float] {
        guard previousMagnitudes.count == magnitudes.count else {
            return magnitudes
        }

        return zip(magnitudes, previousMagnitudes).map { current, previous in
            current * smoothingFactor + previous * (1 - smoothingFactor)
        }
    }
}

private extension Int {
    var isPowerOfTwo: Bool {
        self > 0 && (self & (self - 1)) == 0
    }
}
