import Foundation

@MainActor
@Observable
final class AppViewModel {
    var inputManager: AudioInputManager
    var offlineAnalyzer: OfflineAudioAnalyzer
    var currentFrame: AnalysisFrame
    var takeRecorder: TakeRecorder
    var workflowState: MainWorkflowState = .ready
    var currentTake: RecordedTake?
    var savedTake: RecordedTake?
    var meterHistory: [MeterSnapshot]
    var latestAnalysisInputFrame: AudioInputFrame?
    private var takePlaybackTask: Task<Void, Never>?
    private var analysisScorer: CompositeAnalysisScorer
    private let offlineFrameSize = 2_048

    init(
        inputManager: AudioInputManager? = nil,
        offlineAnalyzer: OfflineAudioAnalyzer? = nil,
        currentFrame: AnalysisFrame = .placeholder,
        takeRecorder: TakeRecorder? = nil
    ) {
        self.inputManager = inputManager ?? AudioInputManager()
        self.offlineAnalyzer = offlineAnalyzer ?? OfflineAudioAnalyzer()
        self.currentFrame = currentFrame
        self.takeRecorder = takeRecorder ?? TakeRecorder()
        self.meterHistory = [currentFrame.meters]
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
        inputManager.stop()
    }

    func startPrimaryTakeRecording() {
        startTakeRecording(slot: .takeA)
    }

    func startTakeRecording(slot: TakeSlot = .takeA) {
        takePlaybackTask?.cancel()
        takePlaybackTask = nil
        startAudio()
        takeRecorder.startRecording(slot: slot)
        workflowState = .recording(startedAt: takeRecorder.recordingStartedAt ?? Date())
    }

    func stopTakeRecording() {
        takeRecorder.finishRecording()
        currentTake = takeRecorder.take(for: .takeA)
        workflowState = currentTake == nil ? .ready : .reviewingTake
    }

    func clearTake(slot: TakeSlot) {
        takeRecorder.clear(slot: slot)
        if slot == .takeA {
            currentTake = nil
        }
    }

    func saveCurrentTake() {
        savedTake = currentTake
    }

    func discardCurrentTake() {
        currentTake = nil
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
            currentTake = nil
            workflowState = .ready
            return
        }

        currentTake = analyzedTake(from: clip)
        workflowState = currentTake == nil ? .ready : .reviewingTake
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
        takeRecorder.record(analyzedFrame)
    }

    private func analyzedTake(from clip: OfflineAudioClip) -> RecordedTake? {
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
            name: "Imported take: \(clip.fileName)",
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(clip.duration),
            frames: frames
        )
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
