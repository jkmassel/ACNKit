import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(sACN_swiftTests.allTests),
    ]
}
#endif