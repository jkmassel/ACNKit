import Foundation
import e131

typealias DMXUniverseListener = (DMXUniverse) -> ()

protocol DMXUniverseDelegate {
    func universeDidDiscard(invalidPacket: SACNPacket, universe: DMXUniverse)
    func universeDidDiscard(outdatedPacket: SACNPacket, universe: DMXUniverse)
}

class DMXUniverse{

    public let number: UInt16
    public var values: [UInt8]
    public var isListening: Bool = false
    public var delegate: DMXUniverseDelegate?

    private var lastPacket: SACNPacket?
    private let socket: SACNSocket

    private let queue: DispatchQueue
    public var listener: DMXUniverseListener?

    public var sourceName: String
    
    public var priority = E131_DEFAULT_PRIORITY
    
    var packetsReceived = 0
    var listenStartDate: Date?

    init(number: UInt16, priority: UInt8 = E131_DEFAULT_PRIORITY){
        self.number = number
        self.priority = priority
        self.values = []

        self.sourceName = "dmx-universe-\(self.number)"
        self.queue = DispatchQueue(label: "DMX Universe \(number)")
        self.socket = SACNSocket(universe: number)
    }

    @discardableResult
    func startListeningForChanges() -> Bool{

        self.isListening = true
        self.listenStartDate = Date()

        self.waitForNewPacket()

        return self.socket.connect()
    }

    func close(){
        self.socket.disconnect()
    }

    private func waitForNewPacket(){

        guard self.isListening else { return }

        self.queue.async {
            defer{
                self.waitForNewPacket()
            }

            guard let packet = self.socket.receive_packet() else { return }
            self.update(with: packet)
        }
    }

    internal func update(with packet: SACNPacket){

        //Increment packets received
        self.packetsReceived += 1

        guard packet.isValid else {
            self.delegate?.universeDidDiscard(invalidPacket: packet, universe: self)
            return
        }

        guard !(lastPacket?.isNewerThan(packet) ?? false) else {
            self.delegate?.universeDidDiscard(outdatedPacket: packet, universe: self)
            return
        }

        self.values = packet.values
        self.listener?(self)
    }

    subscript (index: UInt16) -> DMXValue {
        get{
            guard index >= 0 && index <= 512 else { return DMXValue.zero }
            let value = self.values[Int(index)]
            return DMXValue(withAbsoluteValue: value)
        }
        set{

            //Don't allow setting out-of-bounds DMX values
            guard index >= 0 && index <= 512 else{
                return
            }

            self.values[Int(index)] = newValue.absoluteValue
            
//            let packet = self.createPacket()
//            self.socket.send_packet(packet)
        }
    }

    var packetsPerSecond: Decimal{
        guard let startDate = self.listenStartDate else { return 0 }
        let numberOfSeconds = Date().timeIntervalSince(startDate)

        return Decimal(self.packetsReceived) / Decimal(numberOfSeconds)
    }

    deinit {
        self.close()
    }
}

extension DMXUniverse{
    
    fileprivate func createPacket() -> SACNPacket?{
        return SACNPacket(universe: self)
    }
}
