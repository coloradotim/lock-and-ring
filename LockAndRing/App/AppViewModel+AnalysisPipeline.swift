import Foundation

@MainActor
extension AppViewModel {
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

    func analyze(_ frame: AudioInputFrame) {
        let analyzedFrame = analyzedFrame(for: frame, timestamp: Date())
        publish(analyzedFrame, inputFrame: frame)
        takeRecorder.record(analyzedFrame, inputFrame: frame)
    }

    func analyzedTake(
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

    func replay(clip: OfflineAudioClip) {
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

    func analyzedFrame(for frame: AudioInputFrame, timestamp: Date) -> AnalysisFrame {
        let result = analysisScorer.score(frame: frame)
        return AnalysisFrame(
            timestamp: timestamp,
            meters: result.meters,
            spectrum: result.spectrum,
            spectrogram: currentFrame.spectrogram.appending(result.spectrum),
            ringHistory: currentFrame.ringHistory.appending(result.ring)
        )
    }

    func publish(_ analyzedFrame: AnalysisFrame, inputFrame: AudioInputFrame) {
        currentFrame = analyzedFrame
        latestAnalysisInputFrame = inputFrame
        meterHistory = Array((meterHistory + [analyzedFrame.meters]).suffix(64))
    }
}
