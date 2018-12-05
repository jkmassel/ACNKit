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

    var universe = [DMXUniverse]()

    init(name: String) {
        self.init(name: name, uuid: UUID() )
    }

    init(name: String, uuid: UUID){
        self.name = name
        self.uuid = uuid
    }

    mutating func addUniverse(_ universe: DMXUniverse){
        self.universe.append(universe)
    }
}
