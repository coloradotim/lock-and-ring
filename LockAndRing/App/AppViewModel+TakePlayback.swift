import AVFoundation
import Foundation

@MainActor
extension AppViewModel {
    func toggleCurrentTakePlayback() {
        playCurrentTake(region: nil, loop: false)
    }

    func playCurrentTake(region: TakeRegion?, loop: Bool) {
        guard let currentTakePlayer else {
            return
        }

        if currentTakePlayer.isPlaying {
            stopCurrentTakePlayback(resetTime: false, restartInput: true)
        } else {
            inputManager.stop()
            audioPlayer?.stop()
            let range = playbackRange(for: region)
            if currentTakePlayer.currentTime < range.start || currentTakePlayer.currentTime >= range.end {
                currentTakePlayer.currentTime = range.start
            }
            currentTakePlayer.play()
            currentTakePlayback.rangeStart = range.start
            currentTakePlayback.rangeEnd = range.end
            currentTakePlayback.isLooping = loop
            currentTakePlayback.isPlaying = true
            startCurrentTakeProgressLoop()
        }
    }

    func stopRegionPlayback() {
        stopCurrentTakePlayback(resetTime: false, restartInput: true)
        currentTakePlayback.isLooping = false
        currentTakePlayback.rangeStart = 0
        currentTakePlayback.rangeEnd = currentTakePlayback.duration
    }

    func playReferenceTake() {
        guard let savedTake else {
            return
        }

        playRecordedTake(savedTake)
    }

    func stopAuditionPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        cleanupTemporaryPlaybackFile()
        stopRegionPlayback()
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
        selectedRegion = nil
        analysisRegion = nil
        regionDraftStart = 0
        regionDraftEnd = take?.duration ?? 0
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
                isAvailable: true,
                isLooping: false,
                rangeStart: 0,
                rangeEnd: player.duration
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

    func cleanupTemporaryPlaybackFile() {
        if let temporaryPlaybackURL {
            try? FileManager.default.removeItem(at: temporaryPlaybackURL)
        }

        temporaryPlaybackURL = nil
    }

    private func playRecordedTake(_ take: RecordedTake) {
        guard let clip = take.audioClip else {
            return
        }

        inputManager.stop()
        stopCurrentTakePlayback(resetTime: false, restartInput: false)
        audioPlayer?.stop()
        cleanupTemporaryPlaybackFile()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LockAndRing-reference-\(take.id.uuidString).wav")

        do {
            try AudioClipFileStore.write(clip, to: url)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            temporaryPlaybackURL = url
            audioPlayer?.play()
            libraryErrorMessage = nil
        } catch {
            libraryErrorMessage = error.localizedDescription
        }
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
        if player.currentTime >= currentTakePlayback.rangeEnd {
            if currentTakePlayback.isLooping {
                player.currentTime = currentTakePlayback.rangeStart
                player.play()
                return true
            }

            player.pause()
            currentTakePlayback.isPlaying = false
            currentTakePlaybackTask = nil
            startAudio()
            return false
        }

        if player.isPlaying {
            return true
        }

        currentTakePlayback.isPlaying = false
        currentTakePlaybackTask = nil
        startAudio()
        return false
    }

    private func playbackRange(for region: TakeRegion?) -> (start: TimeInterval, end: TimeInterval) {
        guard let duration = currentTake?.duration, duration > 0 else {
            return (0, currentTakePlayer?.duration ?? 0)
        }

        guard let region = region?.clamped(to: duration) else {
            return (0, currentTakePlayer?.duration ?? duration)
        }

        return (region.startTime, region.endTime)
    }
}

struct TakePlaybackState: Equatable {
    var duration: Double = 0
    var currentTime: Double = 0
    var isPlaying = false
    var isAvailable = false
    var isLooping = false
    var rangeStart: TimeInterval = 0
    var rangeEnd: TimeInterval = 0

    var progress: Double {
        guard duration > 0 else {
            return 0
        }

        return min(max(currentTime / duration, 0), 1)
    }
}
