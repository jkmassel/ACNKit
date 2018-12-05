import Foundation
import e131

public typealias DMXUniverseListener = (DMXUniverse) -> ()

public protocol DMXUniverseDelegate {
    func universeDidDiscard(invalidPacket: SACNPacket, universe: DMXUniverse)
    func universeDidDiscard(outdatedPacket: SACNPacket, universe: DMXUniverse)
}

public class DMXUniverse{

    public let number: UInt16
    private var _values = [UInt8](repeating: 0, count: 513)
    public var values: [UInt8] { return _values }
    public var isListening: Bool = false
    public var delegate: DMXUniverseDelegate?

    private var lastIncomingPacket: SACNPacket?
    private let socket: SACNSocket

    private let queue: DispatchQueue
    public var listener: DMXUniverseListener?

    public var sourceName: String
    
    public var priority = E131_DEFAULT_PRIORITY
    private var currentSequenceNumber: UInt8 = 0
    
    var packetsReceived = 0
    var listenStartDate: Date?

    var device: DMXDevice?
    public lazy var deviceUUID: UUID = {
        return device?.uuid ?? UUID()
    }()

    public init(number: UInt16, priority: UInt8 = E131_DEFAULT_PRIORITY, on device: DMXDevice? = nil){
        self.number = number
        self.priority = priority
        self.device = device

        self.sourceName = "dmx-universe-\(self.number)"
        self.queue = DispatchQueue(label: "DMX Universe \(number)")
        self.socket = SACNSocket(universe: number)
    }

    @discardableResult
    public func connect() -> Bool{

        self.isListening = true
        self.listenStartDate = Date()

        self.waitForNewPacket()

        return self.socket.connect()
    }

    public func close(){
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

        guard !(lastIncomingPacket?.isNewerThan(packet) ?? false) else {
            self.delegate?.universeDidDiscard(outdatedPacket: packet, universe: self)
            return
        }

        self._values = packet.values
        self.listener?(self)
    }

    public subscript (index: UInt16) -> DMXValue {
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


            self._values[Int(index)] = newValue.absoluteValue
        }
    }

    public func setValues(_ values: [DMXValue]){
        self._values = values.map({ $0.absoluteValue })
    }

    public func setValues( _ values: [UInt8]){
        self._values = values
    }

    public var packetsPerSecond: Decimal{
        guard let startDate = self.listenStartDate else { return 0 }
        let numberOfSeconds = Date().timeIntervalSince(startDate)

        return Decimal(self.packetsReceived) / Decimal(numberOfSeconds)
    }

    deinit {
        self.close()
    }
}

extension DMXUniverse{
    
    public func createPacket() -> SACNPacket?{
        return SACNPacket(universe: self, withSequenceNumber: self.nextSequenceNumber())
    }

    internal func nextSequenceNumber() -> UInt8 {

        if self.currentSequenceNumber == UInt8.max {
            self.currentSequenceNumber = 0
        }
        else{
            self.currentSequenceNumber += 1
        }

        return self.currentSequenceNumber
    }

    public func sendPacket(){
        guard let packet = self.createPacket() else { return }
        self.socket.send_packet(packet)
    }
}
