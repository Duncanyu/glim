import Foundation
import XCTest
@testable import ColorEditor

final class GlimUpdaterTests: XCTestCase {
    func testVersionsRejectMalformedTagsAndCompareAllComponents() {
        XCTAssertTrue(GlimVersion("v0.3.0")! > GlimVersion("0.2.10")!)
        XCTAssertTrue(GlimVersion("v1.0.0")! > GlimVersion("0.99.99")!)
        XCTAssertNil(GlimVersion("v0.3"))
        XCTAssertNil(GlimVersion("v0.3.0-beta"))
        XCTAssertNil(GlimVersion("v0.-1.0"))
    }

    func testChecksumMustMatchNamedArchive() {
        let hash = String(repeating: "a", count: 64)
        let data = Data("\(hash)  Glim-0.3.0.zip\n".utf8)
        XCTAssertEqual(GlimUpdater.checksum(in: data, for: "Glim-0.3.0.zip"), hash)
        XCTAssertNil(GlimUpdater.checksum(in: data, for: "Glim-0.3.1.zip"))
        XCTAssertNil(GlimUpdater.checksum(in: Data("abc  Glim-0.3.0.zip".utf8), for: "Glim-0.3.0.zip"))
    }
}
