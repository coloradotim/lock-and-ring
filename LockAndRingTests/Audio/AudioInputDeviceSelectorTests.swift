@testable import LockAndRing
import XCTest

final class AudioInputDeviceSelectorTests: XCTestCase {
    func testSavedDeviceIDIsRestoredWhenPresent() {
        let iphone = device(id: "iphone", name: "Tim's iPhone Microphone")
        let mac = device(id: "macbook", name: "MacBook Air Microphone")
        let savedPreference = AudioInputDevicePreference(deviceID: iphone.id, label: iphone.name)

        let selected = AudioInputDeviceSelector.choosePreferredDevice(
            from: [mac, iphone],
            savedPreference: savedPreference
        )

        XCTAssertEqual(selected, iphone)
    }

    func testSavedLabelIsUsedWhenDeviceIDChanges() {
        let mac = device(id: "new-id", name: "MacBook Air Microphone")
        let savedPreference = AudioInputDevicePreference(
            deviceID: "old-id",
            label: "MacBook Air Microphone"
        )

        let selected = AudioInputDeviceSelector.choosePreferredDevice(
            from: [device(id: "iphone", name: "Tim's iPhone Microphone"), mac],
            savedPreference: savedPreference
        )

        XCTAssertEqual(selected, mac)
    }

    func testBuiltInMicIsPreferredOverIPhoneWithoutSavedPreference() {
        let iphone = device(id: "iphone", name: "Tim's iPhone Microphone")
        let builtIn = device(id: "built-in", name: "Built-in Microphone")

        let selected = AudioInputDeviceSelector.choosePreferredDevice(
            from: [iphone, builtIn],
            savedPreference: nil
        )

        XCTAssertEqual(selected, builtIn)
    }

    func testMissingSavedDeviceFallsBackToLocalMic() {
        let internalMic = device(id: "internal", name: "Internal Microphone")
        let savedPreference = AudioInputDevicePreference(
            deviceID: "missing",
            label: "Missing Microphone"
        )

        let selected = AudioInputDeviceSelector.choosePreferredDevice(
            from: [device(id: "iphone", name: "Tim's iPhone Microphone"), internalMic],
            savedPreference: savedPreference
        )

        XCTAssertEqual(selected, internalMic)
    }

    func testEmptyLabelsDoNotPreferIPhoneWhenOtherDeviceExists() {
        let unlabeled = device(id: "local-default", name: "")
        let iphone = device(id: "iphone", name: "iPhone Microphone")

        let selected = AudioInputDeviceSelector.choosePreferredDevice(
            from: [iphone, unlabeled],
            savedPreference: nil
        )

        XCTAssertEqual(selected, unlabeled)
    }

    private func device(id: String, name: String) -> AudioInputDevice {
        AudioInputDevice(id: id, name: name, audioDeviceID: 1)
    }
}
