@testable import LockAndRing
import XCTest

final class SavedTakeLibraryTests: XCTestCase {
    private var rootDirectory: URL?
    private var library: SavedTakeLibrary?

    override func setUpWithError() throws {
        rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        library = SavedTakeLibrary(rootDirectory: rootDirectory)
    }

    override func tearDownWithError() throws {
        if let rootDirectory, FileManager.default.fileExists(atPath: rootDirectory.path) {
            try FileManager.default.removeItem(at: rootDirectory)
        }
        rootDirectory = nil
        library = nil
    }

    func testSaveTakePersistsMetadataAndAudio() throws {
        let library = try XCTUnwrap(library)
        let rootDirectory = try XCTUnwrap(rootDirectory)
        let take = recordedTake()

        let savedTake = try library.save(take)
        let reloadedTakes = try SavedTakeLibrary(rootDirectory: rootDirectory).load()

        XCTAssertEqual(reloadedTakes, [savedTake])
        XCTAssertEqual(savedTake.source, .recorded)
        XCTAssertEqual(savedTake.duration, take.duration)
        XCTAssertEqual(savedTake.analysisSummary?.frameCount, take.frames.count)
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedTake.audioPath))
    }

    func testRenamePersistsAcrossReloads() throws {
        let library = try XCTUnwrap(library)
        let rootDirectory = try XCTUnwrap(rootDirectory)
        let savedTake = try library.save(recordedTake())

        let renamedTake = try library.rename(id: savedTake.id, to: "Polecat pass 2")
        let reloadedTake = try SavedTakeLibrary(rootDirectory: rootDirectory).load().first

        XCTAssertEqual(renamedTake.name, "Polecat pass 2")
        XCTAssertEqual(reloadedTake?.name, "Polecat pass 2")
    }

    func testDeleteRemovesMetadataAndAudioFile() throws {
        let library = try XCTUnwrap(library)
        let savedTake = try library.save(recordedTake())

        try library.delete(id: savedTake.id)

        XCTAssertTrue(try library.load().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: savedTake.audioPath))
    }

    func testImportedTakeIsSavedAsLocalReplayableTake() throws {
        let library = try XCTUnwrap(library)
        let take = recordedTake(source: .imported, name: "Imported take: sample.wav")

        let savedTake = try library.save(take)
        let replayClip = try library.audioClip(for: savedTake)

        XCTAssertEqual(savedTake.source, .imported)
        XCTAssertEqual(savedTake.name, "Imported take: sample.wav")
        XCTAssertEqual(replayClip.channelCount, 1)
        XCTAssertGreaterThan(replayClip.duration, 0)
    }

    func testSavedTakePersistsRegionMetadata() throws {
        let library = try XCTUnwrap(library)
        let rootDirectory = try XCTUnwrap(rootDirectory)
        let region = TakeRegion(name: "Final chord", startTime: 0.2, endTime: 0.8)
        let take = recordedTake(regions: [region])

        _ = try library.save(take)
        let reloadedTake = try SavedTakeLibrary(rootDirectory: rootDirectory).load().first

        XCTAssertEqual(reloadedTake?.regions, [region])
    }

    func testSavingTakeWithoutAudioFails() throws {
        let library = try XCTUnwrap(library)
        let take = RecordedTake(
            slot: .takeA,
            name: "No audio",
            startedAt: Date(),
            endedAt: Date().addingTimeInterval(1),
            frames: [frame()]
        )

        XCTAssertThrowsError(try library.save(take)) { error in
            XCTAssertEqual(error as? SavedTakeLibraryError, .missingAudio)
        }
    }

    private func recordedTake(
        source: TakeSource = .recorded,
        name: String = "Before adjustment",
        regions: [TakeRegion] = []
    ) -> RecordedTake {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let audioClip = OfflineAudioClip(
            fileName: "\(name).wav",
            sampleRate: 44_100,
            channelSamples: [[0, 0.1, 0.2, 0.1, 0]]
        )

        return RecordedTake(
            slot: .takeA,
            name: name,
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(audioClip.duration),
            frames: [frame(), frame()],
            source: source,
            audioClip: audioClip,
            regions: regions
        )
    }

    private func frame() -> AnalysisFrame {
        AnalysisFrame.placeholder
    }
}
