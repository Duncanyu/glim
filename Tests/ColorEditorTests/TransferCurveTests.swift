import XCTest
@testable import ColorEditor

final class TransferCurveTests: XCTestCase {
    func testNeutralCurveAndIndependentRedDimming() {
        let baseline: [Float] = [0, 0.1, 0.4, 0.7, 0.9]
        let neutral = GammaTable(red: baseline, green: baseline, blue: baseline)
            .adjusted(with: DisplaySettings())
        for (actual, expected) in zip(neutral.red, baseline) {
            XCTAssertEqual(actual, expected, accuracy: 0.00001)
        }

        var settings = DisplaySettings()
        settings.redGain = 0.5
        let changed = GammaTable(red: baseline, green: baseline, blue: baseline)
            .adjusted(with: settings)
        XCTAssertEqual(changed.red.last!, 0.45, accuracy: 0.00001)
        XCTAssertEqual(changed.green.last!, 0.9, accuracy: 0.00001)
        XCTAssertEqual(changed.blue.last!, 0.9, accuracy: 0.00001)

        XCTAssertTrue(neutral.approximatelyEquals(neutral))
        var external = neutral
        external.red[2] += 0.01
        XCTAssertFalse(neutral.approximatelyEquals(external))
    }

    func testGammaBoostRevealsNearBlackWithoutMovingWhite() {
        let baseline: [Float] = [0, 0.01, 0.04, 0.16, 0.36, 0.64, 1]
        var settings = DisplaySettings()
        settings.gamma = 2

        let adjusted = TransferCurve.adjust(baseline, settings: settings, channel: .red)

        XCTAssertEqual(adjusted.first!, 0, accuracy: 0.00001)
        XCTAssertGreaterThan(adjusted[1], baseline[1] * 5)
        XCTAssertEqual(adjusted.last!, 1, accuracy: 0.00001)
        XCTAssertTrue(zip(adjusted, adjusted.dropFirst()).allSatisfy(<))
    }

    func testContrastDoesNotCrushNonzeroShadows() {
        let baseline = (0...256).map { Float($0) / 256 }
        var settings = DisplaySettings()
        settings.gamma = 2
        settings.contrast = 1.5

        let adjusted = TransferCurve.adjust(baseline, settings: settings, channel: .green)

        XCTAssertGreaterThan(adjusted[1], 0)
        XCTAssertEqual(adjusted.last!, 1, accuracy: 0.00001)
    }
}
