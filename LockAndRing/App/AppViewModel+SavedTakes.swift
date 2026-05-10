import AVFoundation
import Foundation

@MainActor
extension AppViewModel {
    func importTake(from url: URL) {
        workflowState = .analyzing
        stopAudio()
        takeRecorder.clear(slot: .takeA)
        offlineAnalyzer.importFile(from: url)

        guard let clip = offlineAnalyzer.clip else {
            replaceCurrentTake(nil)
            workflowState = .ready
            return
        }

        replaceCurrentTake(analyzedTake(from: clip))
        workflowState = currentTake == nil ? .ready : .reviewingTake
    }

    func renameSavedTake(_ savedTake: SavedTake, to name: String) {
        do {
            _ = try takeLibrary.rename(id: savedTake.id, to: name)
            reloadSavedTakes()
        } catch {
            libraryErrorMessage = error.localizedDescription
        }
    }

    func deleteSavedTake(_ savedTake: SavedTake) {
        do {
            try takeLibrary.delete(id: savedTake.id)
            reloadSavedTakes()
        } catch {
            libraryErrorMessage = error.localizedDescription
        }
    }

    func playSavedTake(_ savedTake: SavedTake) {
        do {
            let clip = try takeLibrary.audioClip(for: savedTake)
            audioPlayer?.stop()
            cleanupTemporaryPlaybackFile()
            audioPlayer = try AVAudioPlayer(contentsOf: savedTake.audioURL)
            audioPlayer?.play()
            replay(clip: clip)
        } catch {
            libraryErrorMessage = error.localizedDescription
        }
    }

    func analyzeSavedTake(_ savedTake: SavedTake) {
        do {
            let clip = try takeLibrary.audioClip(for: savedTake)
            replaceCurrentTake(
                analyzedTake(
                    from: clip,
                    name: savedTake.name,
                    source: savedTake.source,
                    regions: savedTake.regions
                )
            )
            workflowState = currentTake == nil ? .ready : .reviewingTake
        } catch {
            libraryErrorMessage = error.localizedDescription
        }
    }

    func useSavedTakeForComparison(_ savedTake: SavedTake) {
        do {
            let clip = try takeLibrary.audioClip(for: savedTake)
            self.savedTake = analyzedTake(
                from: clip,
                name: savedTake.name,
                source: savedTake.source,
                regions: savedTake.regions
            )
        } catch {
            libraryErrorMessage = error.localizedDescription
        }
    }

    func reloadSavedTakes() {
        do {
            savedTakes = try takeLibrary.load()
            libraryErrorMessage = nil
        } catch {
            libraryErrorMessage = error.localizedDescription
        }
    }
}
