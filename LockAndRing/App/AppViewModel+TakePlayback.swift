import AVFoundation
import Foundation

@MainActor
extension AppViewModel {
    func toggleCurrentTakePlayback() {
        guard let currentTakePlayer else {
            return
        }

        if currentTakePlayer.isPlaying {
            stopCurrentTakePlayback(resetTime: false, restartInput: true)
        } else {
            inputManager.stop()
            audioPlayer?.stop()
            if currentTakePlayer.currentTime >= currentTakePlayer.duration {
                currentTakePlayer.currentTime = 0
            }
            currentTakePlayer.play()
            currentTakePlayback.isPlaying = true
            startCurrentTakeProgressLoop()
        }
    }

    func scrubCurrentTakePlayback(to progress: Double) {
        let clampedProgress = min(max(progress, 0), 1)

        guard let currentTakePlayer else {
            currentTakePlayback.currentTime = clampedProgress * currentTakePlayback.duration
            return
        }

        currentTakePlayer.currentTime = clampedProgress * currentTakePlayer.duration
        currentTakePlayback.currentTime = currentTakePlayer.currentTime
    }

    func replaceCurrentTake(_ take: RecordedTake?) {
        currentTake = take
        prepareCurrentTakePlayback(for: take)
    }

    func prepareCurrentTakePlayback(for take: RecordedTake?) {
        stopCurrentTakePlayback(resetTime: true, restartInput: false)
        cleanupCurrentTakePlaybackFile()

        guard let take, let clip = take.audioClip else {
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LockAndRing-\(take.id.uuidString).wav")

        do {
            try AudioClipFileStore.write(clip, to: url)
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            currentTakePlayer = player
            currentTakePlaybackURL = url
            currentTakePlayback = TakePlaybackState(
                duration: player.duration,
                currentTime: 0,
                isPlaying: false,
                isAvailable: true
            )
            libraryErrorMessage = nil
        } catch {
            currentTakePlaybackURL = nil
            currentTakePlayer = nil
            currentTakePlayback = TakePlaybackState()
            libraryErrorMessage = error.localizedDescription
        }
    }

    func stopCurrentTakePlayback(resetTime: Bool, restartInput: Bool) {
        currentTakePlaybackTask?.cancel()
        currentTakePlaybackTask = nil
        currentTakePlayer?.pause()

        if resetTime {
            currentTakePlayer?.currentTime = 0
        }

        currentTakePlayback.currentTime = currentTakePlayer?.currentTime ?? 0
        currentTakePlayback.isPlaying = false

        if restartInput {
            startAudio()
        }
    }

    func cleanupCurrentTakePlaybackFile() {
        if let currentTakePlaybackURL {
            try? FileManager.default.removeItem(at: currentTakePlaybackURL)
        }

        currentTakePlaybackURL = nil
        currentTakePlayer = nil
        currentTakePlayback = TakePlaybackState()
    }

    private func startCurrentTakeProgressLoop() {
        currentTakePlaybackTask?.cancel()
        currentTakePlaybackTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)

                let shouldContinue = await MainActor.run {
                    self?.refreshCurrentTakePlaybackProgress() ?? false
                }

                if !shouldContinue {
                    return
                }
            }
        }
    }

    private func refreshCurrentTakePlaybackProgress() -> Bool {
        guard let player = currentTakePlayer else {
            return false
        }

        currentTakePlayback.currentTime = player.currentTime
        if player.isPlaying {
            return true
        }

        currentTakePlayback.isPlaying = false
        currentTakePlaybackTask = nil
        startAudio()
        return false
    }
}

struct TakePlaybackState: Equatable {
    var duration: Double = 0
    var currentTime: Double = 0
    var isPlaying = false
    var isAvailable = false

    var progress: Double {
        guard duration > 0 else {
            return 0
        }

        return min(max(currentTime / duration, 0), 1)
    }
}
