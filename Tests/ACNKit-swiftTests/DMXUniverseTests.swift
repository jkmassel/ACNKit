//
//  DMXUniverseTests.swift
//  ACNKit-swiftTests
//
//  Created by Jeremy Massel on 2018-12-02.
//

import XCTest
@testable import ACNKit

class DMXUniverseTests: XCTestCase {

    func testSequenceNumberWrapping() {

        let universe = DMXUniverse(number: 1)

        for _ in 1...1000 {
            _  = universe.nextSequenceNumber()
        }
    }
}
