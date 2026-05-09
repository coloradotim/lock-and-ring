import Foundation

struct AudioInputFrame: Equatable, Sendable {
    let hostTime: UInt64
    let sampleRate: Double
    let frameSize: Int
    let channelCount: Int
    let monoSamples: [Float]
    let channelSamples: [[Float]]
    let instrumentation: AudioInputInstrumentation
}

struct AudioInputInstrumentation: Equatable, Sendable {
    let rmsLevel: Float
    let channelRMSLevels: [Float]
    let isClipping: Bool
    let channelClipping: [Bool]
    let hasChannelImbalance: Bool
    let noiseFloor: Float
    let hasSignal: Bool
}
