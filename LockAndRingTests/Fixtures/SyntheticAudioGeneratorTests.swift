import XCTest

final class SyntheticAudioGeneratorTests: XCTestCase {
    func testFixturesAreDeterministicByDefault() {
        let first = SyntheticAudioGenerator(seed: 42).noisyRoomLikeInput()
        let second = SyntheticAudioGenerator(seed: 42).noisyRoomLikeInput()

        XCTAssertEqual(first, second)
    }

    func testDifferentSeedsChangeNoise() {
        let first = SyntheticAudioGenerator(seed: 42).noisyRoomLikeInput()
        let second = SyntheticAudioGenerator(seed: 43).noisyRoomLikeInput()

        XCTAssertNotEqual(first, second)
    }

    func testFixtureCatalogProducesNonEmptyBuffers() {
        let generator = SyntheticAudioGenerator()
        let fixtures = [
            generator.singleSine(),
            generator.octave(),
            generator.perfectFifth(),
            generator.justMajorThird(),
            generator.equalTemperedMajorThird(),
            generator.mistunedMajorThird(),
            generator.closeSemitoneCluster(),
            generator.dominantSeventhApproximation(),
            generator.reinforcedHarmonicStack(),
            generator.chaoticUpperPartials(),
            generator.noisyRoomLikeInput()
        ]

        XCTAssertTrue(fixtures.allSatisfy { !$0.isEmpty })
    }
}
