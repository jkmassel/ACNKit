import Foundation
import e131

class SACNSocket{

    public let port: UInt16
    private let universe: UInt16
    private var incomingSocketFileDescriptor: Int32
    private var outgoingSocketFileDescriptor: e131_addr_t?

    private let dispatchQueue: DispatchQueue
    var isConnected = false

    init(port: UInt16 = E131_DEFAULT_PORT, universe: UInt16) {
        self.port = port
        self.universe = universe
        self.incomingSocketFileDescriptor = e131_socket()

        self.dispatchQueue = DispatchQueue(label: "SACN-Socket-\(universe)")
//        debugPrint("initialized socket")
    }

    public func connect() -> Bool{

        do{
            try self.bind()
        }
        catch let err{
            debugPrint(err)
            self.isConnected = false
            return false
        }

        guard self.multicast_join(universe: universe) else { return false }

        self.isConnected = true

        return self.isConnected
    }

    public func disconnect(){

        self.dispatchQueue.sync {
//            debugPrint("disconnecting")
            let handle = FileHandle(fileDescriptor: self.incomingSocketFileDescriptor)
            handle.closeFile()
//            debugPrint("disconnected")

            //Set up a new socket for next time
            self.incomingSocketFileDescriptor = e131_socket()
        }

        self.isConnected = false
    }

    public func receive_packet() -> SACNPacket?{

        guard self.isConnected else { return nil }

        var packet = e131_packet_t()
        var returnNil = false

        self.dispatchQueue.sync {
            debugPrint("Waiting for packet")
            let result = e131_recv(self.incomingSocketFileDescriptor, &packet)
            debugPrint("Received packet")

            if result < 0{
                debugPrint("Unable to receive packet: \(result)")
                returnNil = true
            }
        }

        guard !returnNil else { return nil }

        return SACNPacket(packet: packet)
    }

    public func send_packet(_ packet: SACNPacket){

        guard self.isConnected else { return }

//        self.dispatchQueue.sync {
            let addr = create_sendable_address(self.universe)

            let pointer = withUnsafePointer(to: packet.packet, { return $0 })
            let socket = withUnsafePointer(to: addr, { return $0 })


            e131_send(self.incomingSocketFileDescriptor, pointer, socket)
//        }
    }
    
    private func bind() throws{

        try self.dispatchQueue.sync {
            debugPrint("Binding")
            let result = e131_bind(self.incomingSocketFileDescriptor, self.port)

            if result != 0{
                debugPrint("Unable to bind socket on port: \(self.port). Error: \(errno)")
                throw SocketBindError(rawValue: errno)
            }

            debugPrint("Bound")
        }
    }

    private func multicast_join(universe: UInt16) -> Bool{

        let result = e131_multicast_join(self.incomingSocketFileDescriptor, universe)

        if result != 0{
            debugPrint("Unable to join multicast group for universe \(universe)")
        }

        return result == 0
    }

    private func multicast_create(universe: UInt16, port: UInt16 = E131_DEFAULT_PORT) -> Bool {

        self.outgoingSocketFileDescriptor = create_sendable_address(port)

        let socket = withUnsafeMutablePointer(to: &self.outgoingSocketFileDescriptor!, { return $0 })
        let result = e131_multicast_dest(socket, universe, port)

        if result != 0 {
            debugPrint("Unable to create multicast destination")
        }

        return result == 0
    }

    deinit {
        self.disconnect()
    }
}
