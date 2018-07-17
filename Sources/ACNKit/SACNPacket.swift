import Foundation
import e131

struct SACNPacket : CustomStringConvertible{

    private let packet: e131_packet_t

    init(packet: e131_packet_t) {
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
