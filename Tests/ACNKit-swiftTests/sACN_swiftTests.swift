import XCTest
@testable import ACNKit

final class sACN_swiftTests: XCTestCase {

    let universe = DMXReceivingUniverse(number: 1)

    func testThatChannelZeroReturnsZero(){
        let exp = XCTestExpectation()

        universe.listener = {
            if $0[0].percent == 0{
                exp.fulfill()
            }
        }

        wait(for: [exp], timeout: 60.0)
    }

    func testThatChannel513ReturnsZero(){
        let exp = XCTestExpectation()

        universe.listener = {

            if $0[513].percent == 0{
                exp.fulfill()
            }
        }

        wait(for: [exp], timeout: 60.0)
    }

    override func setUp() {
        universe.connect()
        super.setUp()
    }

    override func tearDown() {
        universe.close()
        super.tearDown()
    }
}
