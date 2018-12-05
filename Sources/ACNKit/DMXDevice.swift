//
//  DMXDevice.swift
//  ACNKit
//
//  Created by Jeremy Massel on 2018-11-04.
//

import Foundation

public struct DMXDevice{
    let name: String
    let uuid: UUID

    var universes = [DMXUniverse]()

    public init(name: String) {
        self.init(name: name, uuid: UUID() )
    }

    public init(name: String, uuid: UUID){
        self.name = name
        self.uuid = uuid

        self.sendAutomaticUniverseUpdates()
    }

    public mutating func addUniverse(_ universe: DMXUniverse){
        self.universes.append(universe)
    }

    /// Automatically send an update with all of the universe's changes every second,
    /// even if nothing has changed.
    private func sendAutomaticUniverseUpdates() {
        self.universes
            .compactMap{ $0 as? DMXSendingUniverse }
            .forEach{ $0.sendPacket() }

        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.1) {
            self.sendAutomaticUniverseUpdates()
        }
    }
}
