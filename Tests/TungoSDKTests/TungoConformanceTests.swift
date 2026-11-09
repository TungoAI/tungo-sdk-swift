import XCTest
@testable import TungoSDK

final class TungoConformanceTests: XCTestCase {
    func testMoneyFormatting() {
        XCTAssertEqual(TungoMoney.toTiyn(45000.0), 4_500_000)
        XCTAssertEqual(TungoMoney.formatTiyn(4_500_000, currency: "KZT"), "45 000,00 ₸")
    }
}
