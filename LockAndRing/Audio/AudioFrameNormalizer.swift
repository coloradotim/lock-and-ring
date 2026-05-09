import AVFoundation
import Foundation

enum AudioFrameNormalizer {
    static let clippingThreshold: Float = 0.98
    static let imbalanceThreshold: Float = 0.35

    static func makeFrame(from buffer: AVAudioPCMBuffer, time: AVAudioTime) -> AudioInputFrame? {
        guard let floatChannelData = buffer.floatChannelData else {
            return nil
        }

        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameLength > 0, channelCount > 0 else {
            return nil
        }

        let channels = (0..<channelCount).map { channelIndex in
            Array(UnsafeBufferPointer(start: floatChannelData[channelIndex], count: frameLength))
        }

        return makeFrame(
            channels: channels,
            sampleRate: buffer.format.sampleRate,
            hostTime: time.hostTime
        )
    }

    static func makeFrame(
        channels: [[Float]],
        sampleRate: Double,
        hostTime: UInt64 = 0
    ) -> AudioInputFrame? {
        guard let firstChannel = channels.first, !firstChannel.isEmpty else {
            return nil
        }

        let frameSize = firstChannel.count
        let normalizedChannels = channels.map { channel in
            Array(channel.prefix(frameSize))
        }
        let monoSamples = downmixToMono(channels: normalizedChannels, frameSize: frameSize)
        let channelRMS = normalizedChannels.map(rootMeanSquare)
        let channelClipping = normalizedChannels.map(containsClipping)
        let rmsLevel = rootMeanSquare(monoSamples)
        let noiseFloor = estimateNoiseFloor(monoSamples)

        return AudioInputFrame(
            hostTime: hostTime,
            sampleRate: sampleRate,
            frameSize: frameSize,
            channelCount: normalizedChannels.count,
            monoSamples: monoSamples,
            channelSamples: normalizedChannels,
            instrumentation: AudioInputInstrumentation(
                rmsLevel: rmsLevel,
                channelRMSLevels: channelRMS,
                isClipping: channelClipping.contains(true),
                channelClipping: channelClipping,
                hasChannelImbalance: hasChannelImbalance(channelRMS),
                noiseFloor: noiseFloor,
                hasSignal: rmsLevel > max(noiseFloor * 2, 0.01)
            )
        )
    }

    private static func downmixToMono(channels: [[Float]], frameSize: Int) -> [Float] {
        guard channels.count > 1 else {
            return channels.first ?? []
        }

        return (0..<frameSize).map { frameIndex in
            let sum = channels.reduce(Float(0)) { partialResult, channel in
                partialResult + channel[frameIndex]
            }
            return sum / Float(channels.count)
        }
    }

    private static func rootMeanSquare(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else {
            return 0
        }

        let squareSum = samples.reduce(Float(0)) { partialResult, sample in
            partialResult + sample * sample
        }
        return sqrt(squareSum / Float(samples.count))
    }

    private static func containsClipping(_ samples: [Float]) -> Bool {
        samples.contains { abs($0) >= clippingThreshold }
    }

    private static func hasChannelImbalance(_ rmsLevels: [Float]) -> Bool {
        guard rmsLevels.count >= 2, let minimum = rmsLevels.min(), let maximum = rmsLevels.max() else {
            return false
        }

        guard maximum > 0 else {
            return false
        }

        return (maximum - minimum) / maximum >= imbalanceThreshold
    }

    private static func estimateNoiseFloor(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else {
            return 0
        }

        let sortedMagnitudes = samples.map { abs($0) }.sorted()
        let index = max(0, Int(Double(sortedMagnitudes.count - 1) * 0.1))
        return sortedMagnitudes[index]
    }
}
