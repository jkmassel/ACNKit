import Foundation
import e131

fileprivate func extractACNPID(from packet: e131_packet_t) -> String?{
    var pid = packet.root.acn_pid
    
    let ptr = UnsafeBufferPointer(start: &pid.0, count: MemoryLayout.size(ofValue: pid))
    return String(bytes: ptr, encoding: .utf8)
}

fileprivate func extractCID(from packet: e131_packet_t) -> UUID{

    var uuidTuple = packet.root.cid

    let ptr = UnsafeBufferPointer(start: &uuidTuple.0, count: MemoryLayout.size(ofValue: uuidTuple))
    let bytes = Array(ptr)

    return NSUUID(uuidBytes: bytes) as UUID
}

fileprivate func extractSourceName(from packet: e131_packet_t) -> String?{

    var sourceName = packet.frame.source_name
    
    let ptr = UnsafeBufferPointer(start: &sourceName.0, count: MemoryLayout.size(ofValue: sourceName))
    let bytes = Array(ptr).filter { $0 != 0 }

    return String(bytes: bytes, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
}

fileprivate func extractChannelValues(from packet: e131_packet_t) -> [UInt8]{
    var channelValues = packet.frame.source_name
    let ptr = UnsafeBufferPointer(start: &channelValues.0, count: MemoryLayout.size(ofValue: channelValues))
    return [UInt8](ptr)
}

struct SACNRootLayer{
    
    let preambleSize: UInt16
    let postambleSize: UInt16
    let acnPID: String
    let flength: UInt16
    let vector: UInt32
    let cid: UUID
    
    init?(with packet: e131_packet_t) {

        let _pid = extractACNPID(from: packet)

        preambleSize = packet.root.preamble_size
        postambleSize = packet.root.postamble_size
        acnPID = _pid!
        flength = packet.root.flength
        vector = packet.root.vector
        cid = extractCID(from: packet)
    }
}

struct SACNFrameLayer{
    let flength: UInt16
    let vector: UInt32
    let sourceName: String
    let priority: UInt8
    let reserved: UInt16
    let sequenceNumber: UInt8
    let options: UInt8
    let universe: UInt16
    
    init?(with packet: e131_packet_t){
        
        guard let _sourceName = extractSourceName(from: packet) else { return nil}
        
        flength = packet.frame.flength
        vector = packet.frame.vector
        sourceName = _sourceName
        priority = packet.frame.priority
        reserved = packet.frame.reserved
        sequenceNumber = packet.frame.seq_number
        options = packet.frame.options
        universe = packet.frame.universe
    }
}

struct SACNDMPLayer{
    let flength: UInt16
    let vector: UInt8
    let type: UInt8
    let firstAddr: UInt16
    let addrInc: UInt16
    let propertyValueCount: UInt16
    let propertyValues: [UInt8]
    
    init(with packet: e131_packet_t){
        flength = packet.dmp.flength
        vector = packet.dmp.vector
        type = packet.dmp.type
        firstAddr = packet.dmp.first_addr
        addrInc = packet.dmp.addr_inc
        propertyValueCount = packet.dmp.prop_val_cnt
        propertyValues = extractChannelValues(from: packet)
    }
}

struct SACNPacket : CustomStringConvertible{
    
    private let packet: e131_packet_t

    var rootLayer: SACNRootLayer?{
        return SACNRootLayer(with: self.packet)
    }

    var frameLayer: SACNFrameLayer?{
        return SACNFrameLayer(with: self.packet)
    }
    
    var dmpLayer: SACNDMPLayer?{
        return SACNDMPLayer(with: self.packet)
    }
    
    init(packet: e131_packet_t) {
        self.packet = packet
    }

    init?(universe: DMXUniverse){

        let pointer: UnsafeMutablePointer = UnsafeMutablePointer<e131_packet_t>
            .allocate(capacity:  MemoryLayout<e131_packet_t>.size)

        var packet = pointer.move()

        guard e131_pkt_init(&packet, universe.number, 512) == 0 else { return nil }

        applyComponentIdentifier(uuid: universe.deviceUUID, to: &packet)
        applySourceName(name: universe.device?.name ?? "sACN Device", to: &packet)

        self.packet = packet
    }

    func valueForChannel(_ number: UInt) -> UInt8{
        guard number <= 512 && number >= 0 else { return 0 }
        return self.values[Int(number)]
    }

    func isNewerThan(_ packet: SACNPacket) -> Bool{
        var packet = self.packet
        return !e131_pkt_discard(&packet, self.packet.frame.seq_number)
    }

    var values: [UInt8]{
        var tmp = self.packet.dmp.prop_val
        return [UInt8](UnsafeBufferPointer(start: &tmp.0, count: MemoryLayout.size(ofValue: tmp)))
    }

    var isValid: Bool{
        var packet = self.packet
        let status = e131_pkt_validate(&packet)

        return status == E131_ERR_NONE
    }

    var description: String{

        //This is a gnarly hack - right now I can't find a way to
        //get it to dump into a string, so we just write to stdOut
        let fh = FileHandle.standardOutput

        var packet = self.packet

        let result = e131_pkt_dump(fdopen(fh.fileDescriptor, "w"), &packet)
        guard result == 0 else {
            debugPrint(result)
            return ""
        }

        return ""
    }
}

private func applyComponentIdentifier(uuid: UUID, to packet: inout e131_packet_t ){

    debugPrint(packet.root)

    packet.root.cid = (
        uuid.uuid.0,
        uuid.uuid.1,
        uuid.uuid.2,
        uuid.uuid.3,
        uuid.uuid.4,
        uuid.uuid.5,
        uuid.uuid.6,
        uuid.uuid.7,
        uuid.uuid.8,
        uuid.uuid.9,
        uuid.uuid.10,
        uuid.uuid.11,
        uuid.uuid.12,
        uuid.uuid.13,
        uuid.uuid.14,
        uuid.uuid.15
    )

    debugPrint(packet.root)
}

// TODO: Test that this will not crash if given a name with > 64 bytes
private func applySourceName(name: String, to packet: inout e131_packet_t){

    // Turn the name into a set of bytes
    let nameBytes = [UInt8](name.utf8).prefix(64)

    withUnsafeMutableBytes(of: &packet.frame.source_name) { (pointer) in
        pointer.copyBytes(from: nameBytes)
    }
}
