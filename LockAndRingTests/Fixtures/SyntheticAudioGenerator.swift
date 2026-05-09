import Foundation

struct SyntheticAudioGenerator {
    var sampleRate: Double
    var duration: Double
    var seed: UInt64

    init(sampleRate: Double = 44_100, duration: Double = 0.25, seed: UInt64 = 0xC0FFEE) {
        self.sampleRate = sampleRate
        self.duration = duration
        self.seed = seed
    }

    func generate(
        fundamentals: [SyntheticFundamental],
        noiseAmplitude: Double = 0
    ) -> [Float] {
        let sampleCount = Int((sampleRate * duration).rounded())
        var random = SeededRandom(seed: seed)

        return (0..<sampleCount).map { sampleIndex in
            let time = Double(sampleIndex) / sampleRate
            let tonalSample = fundamentals.reduce(0) { partialResult, fundamental in
                partialResult + fundamental.sample(at: time)
            }
            let noise = noiseAmplitude > 0 ? random.nextSignedDouble() * noiseAmplitude : 0
            return Float(max(min(tonalSample + noise, 1), -1))
        }
    }

    func singleSine(
        frequency: Double = 440,
        amplitude: Double = 0.9,
        vibrato: Vibrato? = nil
    ) -> [Float] {
        generate(
            fundamentals: [
                SyntheticFundamental(
                    frequency: frequency,
                    amplitude: amplitude,
                    partials: [.fundamental],
                    vibrato: vibrato
                )
            ]
        )
    }

    func octave(root: Double = 220) -> [Float] {
        generate(
            fundamentals: [
                .sine(frequency: root, amplitude: 0.8),
                .sine(frequency: root * 2, amplitude: 0.65)
            ]
        )
    }

    func perfectFifth(root: Double = 220) -> [Float] {
        generate(
            fundamentals: [
                .sine(frequency: root, amplitude: 0.8),
                .sine(frequency: root * 3 / 2, amplitude: 0.7)
            ]
        )
    }

    func justMajorThird(root: Double = 220) -> [Float] {
        generate(
            fundamentals: [
                .sine(frequency: root, amplitude: 0.8),
                .sine(frequency: root * 5 / 4, amplitude: 0.65)
            ]
        )
    }

    func equalTemperedMajorThird(root: Double = 220) -> [Float] {
        generate(
            fundamentals: [
                .sine(frequency: root, amplitude: 0.8),
                .sine(frequency: root * pow(2, 4.0 / 12.0), amplitude: 0.65)
            ]
        )
    }

    func mistunedMajorThird(root: Double = 220, detuningCents: Double = 18) -> [Float] {
        generate(
            fundamentals: [
                .sine(frequency: root, amplitude: 0.8),
                .sine(
                    frequency: root * 5 / 4,
                    amplitude: 0.65,
                    detuningCents: detuningCents
                )
            ]
        )
    }

    func closeSemitoneCluster(root: Double = 220) -> [Float] {
        generate(
            fundamentals: [
                .sine(frequency: root, amplitude: 0.78),
                .sine(frequency: root * pow(2, 1.0 / 12.0), amplitude: 0.7),
                .sine(frequency: root * pow(2, 2.0 / 12.0), amplitude: 0.52)
            ]
        )
    }

    func dominantSeventhApproximation(root: Double = 220) -> [Float] {
        generate(
            fundamentals: [
                .sine(frequency: root, amplitude: 0.75),
                .sine(frequency: root * 5 / 4, amplitude: 0.58),
                .sine(frequency: root * 3 / 2, amplitude: 0.62),
                .sine(frequency: root * 7 / 4, amplitude: 0.5)
            ]
        )
    }

    func reinforcedHarmonicStack(root: Double = 220) -> [Float] {
        generate(
            fundamentals: [
                SyntheticFundamental(
                    frequency: root,
                    amplitude: 0.95,
                    partials: [
                        .init(number: 1, amplitude: 1),
                        .init(number: 2, amplitude: 0.82),
                        .init(number: 3, amplitude: 0.78),
                        .init(number: 4, amplitude: 0.66),
                        .init(number: 5, amplitude: 0.52),
                        .init(number: 6, amplitude: 0.42)
                    ]
                )
            ]
        )
    }

    func chaoticUpperPartials(root: Double = 220) -> [Float] {
        generate(
            fundamentals: [
                SyntheticFundamental(
                    frequency: root,
                    amplitude: 0.95,
                    partials: [
                        .init(number: 1, amplitude: 1),
                        .init(number: 2, amplitude: 0.18, detuningCents: 31),
                        .init(number: 3, amplitude: 0.22, detuningCents: -45),
                        .init(number: 5, amplitude: 0.15, detuningCents: 58)
                    ]
                )
            ],
            noiseAmplitude: 0.02
        )
    }

    func noisyRoomLikeInput(root: Double = 220) -> [Float] {
        generate(
            fundamentals: [
                SyntheticFundamental(
                    frequency: root,
                    amplitude: 0.55,
                    partials: [.fundamental, .init(number: 2, amplitude: 0.35)]
                )
            ],
            noiseAmplitude: 0.08
        )
    }
}

struct SyntheticFundamental {
    let frequency: Double
    let amplitude: Double
    let detuningCents: Double
    let partials: [SyntheticPartial]
    let vibrato: Vibrato?

    init(
        frequency: Double,
        amplitude: Double,
        detuningCents: Double = 0,
        partials: [SyntheticPartial],
        vibrato: Vibrato? = nil
    ) {
        self.frequency = frequency
        self.amplitude = amplitude
        self.detuningCents = detuningCents
        self.partials = partials
        self.vibrato = vibrato
    }

    static func sine(
        frequency: Double,
        amplitude: Double,
        detuningCents: Double = 0,
        vibrato: Vibrato? = nil
    ) -> SyntheticFundamental {
        SyntheticFundamental(
            frequency: frequency,
            amplitude: amplitude,
            detuningCents: detuningCents,
            partials: [.fundamental],
            vibrato: vibrato
        )
    }

    func sample(at time: Double) -> Double {
        let partialScale = max(partials.reduce(0) { $0 + $1.amplitude }, 1)

        return partials.reduce(0) { partialResult, partial in
            let partialFrequency = tunedFrequency(
                frequency * Double(partial.number),
                detuningCents: detuningCents + partial.detuningCents,
                time: time
            )
            let phase = 2 * Double.pi * partialFrequency * time + partial.phase
            return partialResult + amplitude * partial.amplitude * sin(phase) / partialScale
        }
    }

    private func tunedFrequency(
        _ baseFrequency: Double,
        detuningCents: Double,
        time: Double
    ) -> Double {
        let detuned = baseFrequency * pow(2, detuningCents / 1_200)
        guard let vibrato else {
            return detuned
        }

        let vibratoCents = vibrato.depthCents * sin(2 * Double.pi * vibrato.rate * time)
        return detuned * pow(2, vibratoCents / 1_200)
    }
}

struct SyntheticPartial {
    let number: Int
    let amplitude: Double
    let detuningCents: Double
    let phase: Double

    init(
        number: Int,
        amplitude: Double,
        detuningCents: Double = 0,
        phase: Double = 0
    ) {
        self.number = number
        self.amplitude = amplitude
        self.detuningCents = detuningCents
        self.phase = phase
    }

    static let fundamental = SyntheticPartial(number: 1, amplitude: 1)
}

struct Vibrato {
    let depthCents: Double
    let rate: Double
}

private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func nextSignedDouble() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1
        let value = Double((state >> 11) & ((1 << 53) - 1)) / Double(1 << 53)
        return value * 2 - 1
    }
}
