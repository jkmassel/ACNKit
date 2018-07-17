import Foundation

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

    var packetsReceived = 0
    var listenStartDate: Date?

    init(number: UInt16){
        self.number = number
        self.values = []

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
        guard index >= 0 && index <= 512 else { return DMXValue.zero }
        let value = self.values[Int(index)]
        return DMXValue(withAbsoluteValue: value)
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
