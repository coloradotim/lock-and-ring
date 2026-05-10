import Foundation

@MainActor
extension AppViewModel {
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
}
