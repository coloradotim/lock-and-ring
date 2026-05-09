import AVFoundation
import Foundation

struct SavedTake: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    let createdAt: Date
    let source: TakeSource
    let duration: TimeInterval
    let audioPath: String
    var analysisSummary: SavedTakeAnalysisSummary?
    var signalConfidence: Double?
    var notes: String?

    var audioURL: URL {
        URL(fileURLWithPath: audioPath)
    }
}

struct SavedTakeAnalysisSummary: Codable, Equatable, Sendable {
    let averageLock: Double
    let averageRing: Double
    let averageRoughness: Double
    let averageStability: Double
    let frameCount: Int

    init(summary: TakeSummary) {
        self.averageLock = summary.averageLock
        self.averageRing = summary.averageRing
        self.averageRoughness = summary.averageRoughness
        self.averageStability = summary.averageStability
        self.frameCount = summary.frameCount
    }
}

enum SavedTakeLibraryError: Equatable, LocalizedError {
    case missingAudio
    case takeNotFound

    var errorDescription: String? {
        switch self {
        case .missingAudio:
            "This take does not include replayable audio."
        case .takeNotFound:
            "The saved take could not be found."
        }
    }
}

final class SavedTakeLibrary {
    private let rootDirectory: URL
    private let audioDirectory: URL
    private let metadataURL: URL
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        rootDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        let rootDirectory = rootDirectory ?? SavedTakeLibrary.defaultRootDirectory()
        self.rootDirectory = rootDirectory
        self.audioDirectory = rootDirectory.appendingPathComponent("Audio", isDirectory: true)
        self.metadataURL = rootDirectory.appendingPathComponent("saved-takes.json")
        self.fileManager = fileManager
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> [SavedTake] {
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            return []
        }

        let data = try Data(contentsOf: metadataURL)
        return try decoder.decode([SavedTake].self, from: data)
            .sorted { $0.createdAt > $1.createdAt }
    }

    func save(_ take: RecordedTake, name: String? = nil) throws -> SavedTake {
        guard let audioClip = take.audioClip else {
            throw SavedTakeLibraryError.missingAudio
        }

        try ensureDirectories()
        let savedName = name ?? take.name
        let audioURL = audioDirectory.appendingPathComponent("\(take.id.uuidString).wav")
        try AudioClipFileStore.write(audioClip, to: audioURL)

        var savedTakes = try load().filter { $0.id != take.id }
        let savedTake = SavedTake(
            id: take.id,
            name: savedName,
            createdAt: take.startedAt,
            source: take.source,
            duration: take.duration,
            audioPath: audioURL.path,
            analysisSummary: SavedTakeAnalysisSummary(summary: take.summary),
            signalConfidence: take.summary.averageConfidence,
            notes: nil
        )
        savedTakes.append(savedTake)
        try persist(savedTakes)
        return savedTake
    }

    func rename(id: UUID, to name: String) throws -> SavedTake {
        var savedTakes = try load()
        guard let index = savedTakes.firstIndex(where: { $0.id == id }) else {
            throw SavedTakeLibraryError.takeNotFound
        }

        savedTakes[index].name = name
        try persist(savedTakes)
        return savedTakes[index]
    }

    func delete(id: UUID) throws {
        var savedTakes = try load()
        guard let savedTake = savedTakes.first(where: { $0.id == id }) else {
            throw SavedTakeLibraryError.takeNotFound
        }

        savedTakes.removeAll { $0.id == id }
        if fileManager.fileExists(atPath: savedTake.audioPath) {
            try fileManager.removeItem(atPath: savedTake.audioPath)
        }
        try persist(savedTakes)
    }

    func audioClip(for savedTake: SavedTake) throws -> OfflineAudioClip {
        try OfflineAudioFileLoader.load(url: savedTake.audioURL)
    }

    private func persist(_ savedTakes: [SavedTake]) throws {
        try ensureDirectories()
        let sortedTakes = savedTakes.sorted { $0.createdAt > $1.createdAt }
        let data = try encoder.encode(sortedTakes)
        try data.write(to: metadataURL, options: .atomic)
    }

    private func ensureDirectories() throws {
        try fileManager.createDirectory(
            at: audioDirectory,
            withIntermediateDirectories: true
        )
    }

    private static func defaultRootDirectory() -> URL {
        let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        return baseURL
            .appendingPathComponent("LockAndRing", isDirectory: true)
            .appendingPathComponent("TakeLibrary", isDirectory: true)
    }
}

enum AudioClipFileStore {
    static func write(_ clip: OfflineAudioClip, to url: URL) throws {
        let channelCount = max(clip.channelSamples.count, 1)
        let frameCount = clip.channelSamples.map(\.count).max() ?? clip.monoSamples.count
        let format = AVAudioFormat(
            standardFormatWithSampleRate: clip.sampleRate,
            channels: AVAudioChannelCount(channelCount)
        )

        guard let format,
              let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(frameCount)
              ),
              let floatChannelData = buffer.floatChannelData else {
            throw OfflineAudioImportError.bufferAllocationFailed
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)
        for channelIndex in 0..<channelCount {
            let samples = channelIndex < clip.channelSamples.count
                ? clip.channelSamples[channelIndex]
                : clip.monoSamples

            for frameIndex in 0..<frameCount {
                floatChannelData[channelIndex][frameIndex] = frameIndex < samples.count
                    ? samples[frameIndex]
                    : 0
            }
        }

        let file = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        try file.write(from: buffer)
    }
}
