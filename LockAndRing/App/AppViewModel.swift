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
    var selectedRegion: TakeRegion?
    var analysisRegion: TakeRegion?
    var regionDraftStart: TimeInterval = 0
    var regionDraftEnd: TimeInterval = 0
    var savedTake: RecordedTake?
    var savedTakes: [SavedTake]
    var libraryErrorMessage: String?
    var micSetupCheckResult: MicSetupReadinessDisplayState?
    var meterHistory: [MeterSnapshot]
    var latestAnalysisInputFrame: AudioInputFrame?
    var currentTakePlayback = TakePlaybackState()
    private var takePlaybackTask: Task<Void, Never>?
    var audioPlayer: AVAudioPlayer?
    var temporaryPlaybackURL: URL?
    var currentTakePlayer: AVAudioPlayer?
    var currentTakePlaybackURL: URL?
    var currentTakePlaybackTask: Task<Void, Never>?
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
        cleanupTemporaryPlaybackFile()
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
        inputManager.stop()
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
        startAudio()
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

    var recordingReadiness: RecordingReadiness {
        RecordingReadiness(
            inputState: inputManager.state,
            hasKnownInput: !inputManager.devices.isEmpty
        )
    }

    var currentAnalysisTake: RecordedTake? {
        currentTake?.scoped(to: analysisRegion)
    }

    var draftRegion: TakeRegion? {
        guard let currentTake else {
            return nil
        }

        let region = TakeRegion(
            name: nil,
            startTime: regionDraftStart,
            endTime: regionDraftEnd
        )
        return region.clamped(to: currentTake.duration)
    }

    func updateRegionStart(_ progress: Double) {
        guard let currentTake else {
            return
        }

        let time = min(max(progress, 0), 1) * currentTake.duration
        regionDraftStart = min(time, max(regionDraftEnd - 0.1, 0))
        stopCurrentTakePlayback(resetTime: false, restartInput: false)
    }

    func updateRegionEnd(_ progress: Double) {
        guard let currentTake else {
            return
        }

        let time = min(max(progress, 0), 1) * currentTake.duration
        regionDraftEnd = max(time, min(regionDraftStart + 0.1, currentTake.duration))
        stopCurrentTakePlayback(resetTime: false, restartInput: false)
    }

    func analyzeDraftRegion() {
        analysisRegion = draftRegion
    }

    func clearRegionSelection() {
        guard let currentTake else {
            return
        }

        selectedRegion = nil
        analysisRegion = nil
        regionDraftStart = 0
        regionDraftEnd = currentTake.duration
        stopCurrentTakePlayback(resetTime: false, restartInput: false)
    }

    func saveDraftRegion() {
        guard var currentTake, let region = draftRegion else {
            return
        }

        let namedRegion = TakeRegion(
            id: region.id,
            name: "Region \(currentTake.regions.count + 1)",
            startTime: region.startTime,
            endTime: region.endTime
        )
        currentTake.regions.append(namedRegion)
        self.currentTake = currentTake
        selectedRegion = namedRegion
        analysisRegion = namedRegion
        regionDraftStart = namedRegion.startTime
        regionDraftEnd = namedRegion.endTime
    }

    func selectRegion(_ region: TakeRegion?) {
        guard let currentTake else {
            return
        }

        let region = region ?? currentTake.wholeTakeRegion
        selectedRegion = region.name == "Whole take" ? nil : region
        analysisRegion = selectedRegion
        regionDraftStart = region.startTime
        regionDraftEnd = region.endTime
        stopCurrentTakePlayback(resetTime: false, restartInput: false)
    }

    var micSetupReadiness: MicSetupReadinessDisplayState {
        MicSetupReadinessDisplayState(
            inputName: inputManager.selectedInputName,
            inputState: inputManager.state,
            frame: inputManager.latestFrame,
            signal: SignalQualityDisplayState(meters: currentFrame.meters)
        )
    }

    func runMicSetupCheck() {
        micSetupCheckResult = micSetupReadiness
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
        source: TakeSource = .imported,
        regions: [TakeRegion] = []
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
            audioClip: clip,
            regions: regions
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
