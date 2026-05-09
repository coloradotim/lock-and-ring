import AVFoundation
import Foundation

@MainActor
@Observable
final class OfflineAudioAnalyzer {
    private let frameSize: Int
    private var playbackTask: Task<Void, Never>?

    private(set) var clip: OfflineAudioClip?
    private(set) var state: OfflineAnalysisState = .empty
    private(set) var currentTime: Double = 0
    var onFrame: ((AudioInputFrame) -> Void)?
    var onPlaybackStarted: (() -> Void)?
    var onPlaybackStopped: (() -> Void)?

    var selectedFileName: String {
        clip?.fileName ?? "No file selected"
    }

    var duration: Double {
        clip?.duration ?? 0
    }

    var progress: Double {
        guard duration > 0 else {
            return 0
        }

        return min(max(currentTime / duration, 0), 1)
    }

    init(frameSize: Int = 2_048) {
        self.frameSize = frameSize
    }

    func importFile(from url: URL) {
        pause()
        state = .loading
        let isScopedResource = url.startAccessingSecurityScopedResource()
        defer {
            if isScopedResource {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            clip = try OfflineAudioFileLoader.load(url: url)
            currentTime = 0
            state = .ready
            publishFrame(at: currentTime)
        } catch {
            clip = nil
            currentTime = 0
            state = .failed(error.localizedDescription)
        }
    }

    func play() {
        guard clip != nil, state != .playing else {
            return
        }

        state = .playing
        onPlaybackStarted?()
        playbackTask = Task { [weak self] in
            await self?.playbackLoop()
        }
    }

    func pause() {
        playbackTask?.cancel()
        playbackTask = nil

        if case .playing = state {
            state = clip == nil ? .empty : .paused
            onPlaybackStopped?()
        }
    }

    func togglePlayback() {
        if case .playing = state {
            pause()
        } else {
            play()
        }
    }

    func scrub(to progress: Double) {
        guard let clip else {
            return
        }

        currentTime = min(max(progress, 0), 1) * clip.duration
        publishFrame(at: currentTime)
    }

    private func playbackLoop() async {
        while !Task.isCancelled {
            guard let clip else {
                state = .empty
                return
            }

            publishFrame(at: currentTime)
            currentTime += Double(frameSize) / clip.sampleRate

            if currentTime >= clip.duration {
                currentTime = clip.duration
                state = .ready
                playbackTask = nil
                onPlaybackStopped?()
                return
            }

            let nanoseconds = UInt64(Double(frameSize) / clip.sampleRate * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
        }
    }

    private func publishFrame(at time: Double) {
        guard let clip,
              let frame = clip.frame(at: time, frameSize: frameSize) else {
            return
        }

        onFrame?(frame)
    }
}

enum OfflineAnalysisState: Equatable {
    case empty
    case loading
    case ready
    case playing
    case paused
    case failed(String)
}

enum OfflineAudioFileLoader {
    static func load(url: URL) throws -> OfflineAudioClip {
        let file = try AVAudioFile(forReading: url)
        let processingFormat = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: frameCount) else {
            throw OfflineAudioImportError.bufferAllocationFailed
        }

        try file.read(into: buffer)
        guard let floatChannelData = buffer.floatChannelData else {
            throw OfflineAudioImportError.unsupportedFormat
        }

        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(processingFormat.channelCount)
        guard frameLength > 0, channelCount > 0 else {
            throw OfflineAudioImportError.emptyFile
        }

        let channelSamples = (0..<channelCount).map { channelIndex in
            Array(UnsafeBufferPointer(start: floatChannelData[channelIndex], count: frameLength))
        }

        guard let frame = AudioFrameNormalizer.makeFrame(
            channels: channelSamples,
            sampleRate: processingFormat.sampleRate
        ) else {
            throw OfflineAudioImportError.unsupportedFormat
        }

        return OfflineAudioClip(
            fileName: url.lastPathComponent,
            fileType: url.pathExtension.isEmpty ? "unknown" : url.pathExtension.lowercased(),
            sampleRate: processingFormat.sampleRate,
            monoSamples: frame.monoSamples,
            channelSamples: frame.channelSamples
        )
    }
}

enum OfflineAudioImportError: LocalizedError {
    case bufferAllocationFailed
    case unsupportedFormat
    case emptyFile

    var errorDescription: String? {
        switch self {
        case .bufferAllocationFailed:
            "Unable to allocate an audio buffer for this file."
        case .unsupportedFormat:
            "Unable to decode this audio file into floating-point PCM samples."
        case .emptyFile:
            "The selected audio file contains no readable samples."
        }
    }
}

struct OfflineAudioClip: Equatable, Sendable {
    let fileName: String
    let fileType: String
    let sampleRate: Double
    let monoSamples: [Float]
    let channelSamples: [[Float]]
    let diagnostics: OfflineAudioImportDiagnostics

    init(
        fileName: String,
        fileType: String = "unknown",
        sampleRate: Double,
        monoSamples: [Float]? = nil,
        channelSamples: [[Float]]
    ) {
        self.fileName = fileName
        self.fileType = fileType
        self.sampleRate = sampleRate
        self.channelSamples = channelSamples
        self.monoSamples = monoSamples ?? Self.downmixToMono(channelSamples)
        self.diagnostics = OfflineAudioImportDiagnostics(
            fileType: fileType,
            sampleRate: sampleRate,
            channelSamples: channelSamples,
            monoSamples: self.monoSamples
        )
    }

    var duration: Double {
        Double(monoSamples.count) / sampleRate
    }

    var channelCount: Int {
        channelSamples.count
    }

    func frame(at time: Double, frameSize: Int) -> AudioInputFrame? {
        guard frameSize > 0, !monoSamples.isEmpty else {
            return nil
        }

        let startIndex = min(max(Int(time * sampleRate), 0), max(monoSamples.count - 1, 0))
        let endIndex = min(startIndex + frameSize, monoSamples.count)
        let monoFrame = padded(Array(monoSamples[startIndex..<endIndex]), frameSize: frameSize)
        let channelFrames = channelSamples.map { channel in
            padded(Array(channel[startIndex..<min(startIndex + frameSize, channel.count)]), frameSize: frameSize)
        }

        return AudioFrameNormalizer.makeFrame(
            channels: channelFrames.isEmpty ? [monoFrame] : channelFrames,
            sampleRate: sampleRate,
            hostTime: UInt64(startIndex)
        )
    }

    private func padded(_ samples: [Float], frameSize: Int) -> [Float] {
        if samples.count >= frameSize {
            return Array(samples.prefix(frameSize))
        }

        return samples + Array(repeating: 0, count: frameSize - samples.count)
    }

    private static func downmixToMono(_ channels: [[Float]]) -> [Float] {
        guard let firstChannel = channels.first else {
            return []
        }

        guard channels.count > 1 else {
            return firstChannel
        }

        return firstChannel.indices.map { index in
            let sum = channels.reduce(Float(0)) { partialResult, channel in
                guard index < channel.count else {
                    return partialResult
                }

                return partialResult + channel[index]
            }
            return sum / Float(channels.count)
        }
    }
}

struct OfflineAudioImportDiagnostics: Equatable, Sendable {
    let sourceType: TakeSource
    let fileType: String
    let channelCount: Int
    let sourceSampleRate: Double
    let analysisSampleRate: Double
    let monoConversionBehavior: String
    let normalizationBehavior: String
    let peakLevel: Double
    let clippingRatio: Double
    let stereoCorrelation: Double?

    init(
        fileType: String,
        sampleRate: Double,
        channelSamples: [[Float]],
        monoSamples: [Float]
    ) {
        self.sourceType = .imported
        self.fileType = fileType
        self.channelCount = channelSamples.count
        self.sourceSampleRate = sampleRate
        self.analysisSampleRate = sampleRate
        self.monoConversionBehavior = channelSamples.count > 1
            ? "Simple channel average from decoded PCM."
            : "Single decoded PCM channel."
        self.normalizationBehavior = "No gain normalization is applied before analysis."
        self.peakLevel = monoSamples.map { Double(abs($0)) }.max() ?? 0
        self.clippingRatio = monoSamples.ratio { abs($0) >= 0.98 }
        self.stereoCorrelation = Self.stereoCorrelation(channelSamples)
    }

    private static func stereoCorrelation(_ channels: [[Float]]) -> Double? {
        guard channels.count >= 2 else {
            return nil
        }

        let left = channels[0]
        let right = channels[1]
        let count = min(left.count, right.count)
        guard count > 1 else {
            return nil
        }

        var dot = 0.0
        var leftEnergy = 0.0
        var rightEnergy = 0.0

        for index in 0..<count {
            let leftValue = Double(left[index])
            let rightValue = Double(right[index])
            dot += leftValue * rightValue
            leftEnergy += leftValue * leftValue
            rightEnergy += rightValue * rightValue
        }

        guard leftEnergy > 0, rightEnergy > 0 else {
            return nil
        }

        return dot / sqrt(leftEnergy * rightEnergy)
    }
}

private extension Array where Element == Float {
    func ratio(where predicate: (Float) -> Bool) -> Double {
        guard !isEmpty else {
            return 0
        }

        return Double(filter(predicate).count) / Double(count)
    }
}
