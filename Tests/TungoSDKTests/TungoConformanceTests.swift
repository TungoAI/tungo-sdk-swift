import XCTest
@testable import TungoSDK

final class TungoConformanceTests: XCTestCase {
    func testMoneyFormattingAndBinIin() {
        XCTAssertEqual(TungoMoney.toTiyn(45000.0), 4_500_000)
        XCTAssertEqual(TungoMoney.formatTiyn(4_500_000, currency: "KZT"), "45 000,00 ₸")
        XCTAssertTrue(TungoMoney.isValidBinIin("990140000017"))
        XCTAssertTrue(TungoMoney.isValidBinIin("991140000015"))
        XCTAssertFalse(TungoMoney.isValidBinIin("990140000016"))
    }
}
