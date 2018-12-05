//
//  SACNPacketTests.swift
//  ACNKit-swiftTests
//
//  Created by Jeremy Massel on 2018-11-04.
//

import XCTest
@testable import ACNKit

fileprivate let device = DMXDevice(name: "My Test Device")

class SACNPacketTests: XCTestCase {

    let universe = DMXSendingUniverse(number: 1, priority: 1, on: device)

    func testThatPacketUUIDIsCorrectlyApplied(){
        let packet = universe.createPacket()!
        assert(packet.rootLayer?.cid == universe.deviceUUID, "The UUID is correctly copied into the packet from the Universe UUID")
    }

    func testThatPacketSourceNameIsCorrectlyApplied(){
        let packet = universe.createPacket()
        assert(packet?.frameLayer?.sourceName == device.name, "The device name is correctly copied into the packet")
    }

    func testThatPacketSourceNamesWithGreaterThan64BytesAreProperlyTruncated(){

        let universeName = NSUUID().uuidString + NSUUID().uuidString

        let device = DMXDevice(name: universeName) //72 Byte Name
        let universe = DMXSendingUniverse(number: 1, priority: 1, on: device)
        let packet = universe.createPacket()

        assert(packet?.frameLayer?.sourceName.lengthOfBytes(using: .utf8) == 64, "The device name should be truncated down to 64 characters")
        assert(packet?.frameLayer?.sourceName == String(universeName.prefix(64)), "The packet's source name should be the first 64 characters of the device name")
    }

    func testThatDMXValuesAreCorrectlyApplied(){

        let values = (0...512).map{ _ in UInt8.random(in: 0...255) }
        universe.setValues(values)
        let packet = universe.createPacket()!

        XCTAssertEqual(values, packet.values)
    }
}
