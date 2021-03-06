import Foundation
import e131

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

public struct SACNPacket : CustomStringConvertible{
    
    internal let packet: e131_packet_t

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

    init?(universe: DMXSendingUniverse, withSequenceNumber sequenceNumber: UInt8 = 0){

        let pointer: UnsafeMutablePointer = UnsafeMutablePointer<e131_packet_t>
            .allocate(capacity:  MemoryLayout<e131_packet_t>.size)

        var packet = pointer.move()

        guard e131_pkt_init(&packet, universe.number, 512) == 0 else { return nil }

        applyComponentIdentifier(uuid: universe.deviceUUID, to: &packet)
        applySourceName(name: universe.device?.name ?? "sACN Device", to: &packet)
        applyDMXChannels(universe.values, to: &packet)
        packet.frame.seq_number = sequenceNumber

        self.packet = packet

        assert(universe.values == self.values)
    }

    public func valueForChannel(_ number: Int) -> DMXValue{
        guard number <= 512 && number > 0 else { return DMXValue(withAbsoluteValue: 0) }
        let absoluteValue = self.dmpLayer?.propertyValues[number] ?? 0
        return DMXValue(withAbsoluteValue: absoluteValue)
    }

    func isNewerThan(_ packet: SACNPacket) -> Bool{
        var packet = self.packet
        return !e131_pkt_discard(&packet, self.packet.frame.seq_number)
    }

    var values: [UInt8]{
        return extractChannelValues(from: self.packet)
    }

    public var isValid: Bool{
        var packet = self.packet
        let status = e131_pkt_validate(&packet)

        return status == E131_ERR_NONE
    }

    public var description: String{

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

private func applyComponentIdentifier(uuid: UUID, to packet: inout e131_packet_t ) {
    packet.root.cid = uuid.uuid
}

@inline(__always) fileprivate func applySourceName(name: String, to packet: inout e131_packet_t) {

    // Turn the name into a set of bytes
    let nameBytes = [UInt8](name.utf8).prefix(64)

    withUnsafeMutableBytes(of: &packet.frame.source_name) { (pointer) in
        pointer.copyBytes(from: nameBytes)
    }
}

@inline(__always) fileprivate func applyDMXChannels(_ channels: [UInt8], to packet: inout e131_packet_t) {

    precondition(channels.count == 513)

    withUnsafeMutableBytes(of: &packet.dmp.prop_val) { (pointer) in
//        pointer.storeBytes(of: <#T##T#>, toByteOffset: <#T##Int#>, as: <#T##T.Type#>)
// For better performance – it might be better to maintain a ready-to-go packet at all times,
// and updates just send the packet on its way
        pointer.copyBytes(from: channels)
    }
}

@inline(__always) fileprivate func extractACNPID(from packet: e131_packet_t) -> String? {
    return withUnsafeBytes(of: packet.root.acn_pid) { String(bytes: $0, encoding: .utf8) }
}

@inline(__always) fileprivate func extractCID(from packet: e131_packet_t) -> UUID{
    return UUID(uuid: packet.root.cid)
}

@inline(__always) fileprivate func extractSourceName(from packet: e131_packet_t) -> String? {
     return withUnsafeBytes(of: packet.frame.source_name) {
        guard let ptr = $0.baseAddress?.assumingMemoryBound(to: CChar.self) else {
            return nil
        }

        return String(cString: ptr).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@inline(__always)  func extractChannelValues(from packet: e131_packet_t) -> [UInt8]{
    return withUnsafeBytes(of: packet.dmp.prop_val) { [UInt8]($0) }
}
