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
}
