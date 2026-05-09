import AVFoundation
import Foundation

@MainActor
@Observable
final class AppViewModel {
    var inputManager: AudioInputManager
    var offlineAnalyzer: OfflineAudioAnalyzer
    var currentFrame: AnalysisFrame
    var takeRecorder: TakeRecorder
    var takeLibrary: SavedTakeLibrary
    var workflowState: MainWorkflowState = .ready
    var currentTake: RecordedTake?
    var savedTake: RecordedTake?
    var savedTakes: [SavedTake]
    var libraryErrorMessage: String?
    var meterHistory: [MeterSnapshot]
    var latestAnalysisInputFrame: AudioInputFrame?
    var currentTakePlayback = TakePlaybackState()
    private var takePlaybackTask: Task<Void, Never>?
    private var audioPlayer: AVAudioPlayer?
    private var currentTakePlayer: AVAudioPlayer?
    private var currentTakePlaybackURL: URL?
    private var currentTakePlaybackTask: Task<Void, Never>?
    private var analysisScorer: CompositeAnalysisScorer
    private let offlineFrameSize = 2_048

    init(
        inputManager: AudioInputManager? = nil,
        offlineAnalyzer: OfflineAudioAnalyzer? = nil,
        currentFrame: AnalysisFrame = .placeholder,
        takeRecorder: TakeRecorder? = nil,
        takeLibrary: SavedTakeLibrary = SavedTakeLibrary()
    ) {
        self.inputManager = inputManager ?? AudioInputManager()
        self.offlineAnalyzer = offlineAnalyzer ?? OfflineAudioAnalyzer()
        self.currentFrame = currentFrame
        self.takeRecorder = takeRecorder ?? TakeRecorder()
        self.takeLibrary = takeLibrary
        self.meterHistory = [currentFrame.meters]
        self.savedTakes = (try? takeLibrary.load()) ?? []
        self.analysisScorer = CompositeAnalysisScorer()
        self.inputManager.onFrame = { [weak self] frame in
            self?.analyze(frame)
        }
        self.offlineAnalyzer.onFrame = { [weak self] frame in
            self?.analyze(frame)
        }
        self.offlineAnalyzer.onPlaybackStarted = { [weak self] in
            self?.stopAudio()
        }
        self.offlineAnalyzer.onPlaybackStopped = { [weak self] in
            self?.startAudio()
        }
    }

    func startAudio() {
        inputManager.start()
    }

    func stopAudio() {
        takePlaybackTask?.cancel()
        takePlaybackTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        stopCurrentTakePlayback(resetTime: false, restartInput: false)
        cleanupCurrentTakePlaybackFile()
        inputManager.stop()
    }

    func startPrimaryTakeRecording() {
        startTakeRecording(slot: .takeA)
    }

    func startTakeRecording(slot: TakeSlot = .takeA) {
        takePlaybackTask?.cancel()
        takePlaybackTask = nil
        replaceCurrentTake(nil)
        startAudio()
        takeRecorder.startRecording(slot: slot)
        workflowState = .recording(startedAt: takeRecorder.recordingStartedAt ?? Date())
    }

    func stopTakeRecording() {
        takeRecorder.finishRecording()
        replaceCurrentTake(takeRecorder.take(for: .takeA))
        workflowState = currentTake == nil ? .ready : .reviewingTake
    }

    func clearTake(slot: TakeSlot) {
        takeRecorder.clear(slot: slot)
        if slot == .takeA {
            replaceCurrentTake(nil)
        }
    }

    func saveCurrentTake() {
        guard let currentTake else {
            return
        }

        do {
            _ = try takeLibrary.save(currentTake)
            savedTake = currentTake
            reloadSavedTakes()
        } catch {
            libraryErrorMessage = error.localizedDescription
        }
    }

    func discardCurrentTake() {
        replaceCurrentTake(nil)
        takeRecorder.clear(slot: .takeA)
        workflowState = .ready
    }

    func reviewCurrentTake() {
        workflowState = currentTake == nil ? .ready : .reviewingTake
    }

    func compareCurrentTake() {
        workflowState = canCompareCurrentTake ? .comparing : .reviewingTake
    }

    var canCompareCurrentTake: Bool {
        currentTake != nil && savedTake != nil && currentTake?.id != savedTake?.id
    }

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
                analyzedTake(from: clip, name: savedTake.name, source: savedTake.source)
            )
            workflowState = currentTake == nil ? .ready : .reviewingTake
        } catch {
            libraryErrorMessage = error.localizedDescription
        }
    }

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
        guard let currentTakePlayer else {
            return
        }

        currentTakePlayer.currentTime = min(max(progress, 0), 1) * currentTakePlayer.duration
        currentTakePlayback.currentTime = currentTakePlayer.currentTime
    }

    func useSavedTakeForComparison(_ savedTake: SavedTake) {
        do {
            let clip = try takeLibrary.audioClip(for: savedTake)
            self.savedTake = analyzedTake(from: clip, name: savedTake.name, source: savedTake.source)
        } catch {
            libraryErrorMessage = error.localizedDescription
        }
    }

    func playTake(slot: TakeSlot) {
        guard let take = takeRecorder.take(for: slot), !take.frames.isEmpty else {
            return
        }

        takePlaybackTask?.cancel()
        inputManager.stop()
        takePlaybackTask = Task { [weak self] in
            for frame in take.frames {
                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    self?.currentFrame = frame
                }

                try? await Task.sleep(nanoseconds: 50_000_000)
            }

            await MainActor.run {
                self?.takePlaybackTask = nil
                self?.startAudio()
            }
        }
    }

    private func analyze(_ frame: AudioInputFrame) {
        let analyzedFrame = analyzedFrame(for: frame, timestamp: Date())
        publish(analyzedFrame, inputFrame: frame)
        takeRecorder.record(analyzedFrame, inputFrame: frame)
    }

    private func analyzedTake(
        from clip: OfflineAudioClip,
        name: String? = nil,
        source: TakeSource = .imported
    ) -> RecordedTake? {
        let startedAt = Date()
        let frameDuration = Double(offlineFrameSize) / clip.sampleRate
        var frames: [AnalysisFrame] = []
        var time = 0.0

        while time < clip.duration {
            if let inputFrame = clip.frame(at: time, frameSize: offlineFrameSize) {
                let timestamp = startedAt.addingTimeInterval(time)
                let frame = analyzedFrame(for: inputFrame, timestamp: timestamp)
                frames.append(frame)
                publish(frame, inputFrame: inputFrame)
            }

            time += frameDuration
        }

        guard !frames.isEmpty else {
            return nil
        }

        return RecordedTake(
            slot: .takeA,
            name: name ?? "Imported take: \(clip.fileName)",
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(clip.duration),
            frames: frames,
            source: source,
            audioClip: clip
        )
    }

    private func replay(clip: OfflineAudioClip) {
        takePlaybackTask?.cancel()
        inputManager.stop()
        takePlaybackTask = Task { [weak self] in
            var time = 0.0
            let frameDuration = Double(self?.offlineFrameSize ?? 2_048) / clip.sampleRate

            while time < clip.duration {
                guard !Task.isCancelled else {
                    return
                }

                if let inputFrame = clip.frame(
                    at: time,
                    frameSize: self?.offlineFrameSize ?? 2_048
                ) {
                    await MainActor.run {
                        guard let self else {
                            return
                        }

                        self.publish(
                            self.analyzedFrame(for: inputFrame, timestamp: Date()),
                            inputFrame: inputFrame
                        )
                    }
                }

                time += frameDuration
                try? await Task.sleep(nanoseconds: UInt64(frameDuration * 1_000_000_000))
            }

            await MainActor.run {
                self?.takePlaybackTask = nil
                self?.startAudio()
            }
        }
    }

    private func replaceCurrentTake(_ take: RecordedTake?) {
        currentTake = take
        prepareCurrentTakePlayback(for: take)
    }

    private func prepareCurrentTakePlayback(for take: RecordedTake?) {
        stopCurrentTakePlayback(resetTime: true, restartInput: false)
        cleanupCurrentTakePlaybackFile()
        currentTakePlayback = TakePlaybackState()

        guard let clip = take?.audioClip else {
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LockAndRing-\(take?.id.uuidString ?? UUID().uuidString).wav")

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
            currentTakePlayer = nil
            currentTakePlaybackURL = nil
            currentTakePlayback = TakePlaybackState()
            libraryErrorMessage = error.localizedDescription
        }
    }

    private func stopCurrentTakePlayback(resetTime: Bool, restartInput: Bool) {
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

    private func startCurrentTakeProgressLoop() {
        currentTakePlaybackTask?.cancel()
        currentTakePlaybackTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)

                let shouldContinue = await MainActor.run {
                    guard let self, let player = self.currentTakePlayer else {
                        return false
                    }

                    self.currentTakePlayback.currentTime = player.currentTime
                    if !player.isPlaying {
                        self.currentTakePlayback.isPlaying = false
                        self.currentTakePlaybackTask = nil
                        self.startAudio()
                        return false
                    }

                    return true
                }

                if !shouldContinue {
                    return
                }
            }
        }
    }

    private func cleanupCurrentTakePlaybackFile() {
        if let currentTakePlaybackURL {
            try? FileManager.default.removeItem(at: currentTakePlaybackURL)
        }

        currentTakePlaybackURL = nil
        currentTakePlayer = nil
        currentTakePlayback = TakePlaybackState()
    }

    private func reloadSavedTakes() {
        do {
            savedTakes = try takeLibrary.load()
            libraryErrorMessage = nil
        } catch {
            libraryErrorMessage = error.localizedDescription
        }
    }

    private func analyzedFrame(for frame: AudioInputFrame, timestamp: Date) -> AnalysisFrame {
        let result = analysisScorer.score(frame: frame)
        return AnalysisFrame(
            timestamp: timestamp,
            meters: result.meters,
            spectrum: result.spectrum,
            spectrogram: currentFrame.spectrogram.appending(result.spectrum),
            ringHistory: currentFrame.ringHistory.appending(result.ring)
        )
    }

    private func publish(_ analyzedFrame: AnalysisFrame, inputFrame: AudioInputFrame) {
        currentFrame = analyzedFrame
        latestAnalysisInputFrame = inputFrame
        meterHistory = Array((meterHistory + [analyzedFrame.meters]).suffix(64))
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
