import Foundation
import e131

struct SocketErr : Error{

    private let code: Int

    init(errorCode: Int) {
        self.code = errorCode
    }
}

class SACNSocket{

    public let port: UInt16
    private let universe: UInt16

    private var incomingSocketFileDescriptor: Int32
    private var outgoingSocketFileDescriptor: Int32

    private let dispatchQueue: DispatchQueue
    var isConnected = false

    init(universe: UInt16, queue: DispatchQueue, port: UInt16 = E131_DEFAULT_PORT) {
        self.port = port
        self.universe = universe
        self.incomingSocketFileDescriptor = e131_socket()
        self.outgoingSocketFileDescriptor = e131_socket()

        self.dispatchQueue = queue
    }

    public func connect() -> Bool{

        debugPrint("connecting")

        do{
//            try self.bind()
            try self.prepareSocketForBroadcasting(self.outgoingSocketFileDescriptor)
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

    private func prepareSocketForBroadcasting(_ fileDescriptor: Int32) throws {

        try self.dispatchQueue.sync {

            var shouldBroadcast = 1

            let size: UInt32 = UInt32(MemoryLayout.size(ofValue: shouldBroadcast))

            let broadcastResult = setsockopt(fileDescriptor, SOL_SOCKET, SO_BROADCAST, &shouldBroadcast, size)

            guard broadcastResult != -1 else {
                throw SocketErr(errorCode: 1)
            }
        }
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

        guard self.isConnected, let destination = self.getDestination() else {
            return
        }

        let data = withUnsafePointer(to: packet.packet, { return $0 })
        let address = withUnsafePointer(to: destination, { return $0 })

        _ = self.dispatchQueue.sync {
            e131_send(self.outgoingSocketFileDescriptor, data, address)
        }
    }

    private func getDestination() -> e131_addr_t? {

        var outgoingAddress = create_sendable_address(port)
        let unsafeAddress = withUnsafeMutablePointer(to: &outgoingAddress, { $0 })
        let result = e131_multicast_dest(unsafeAddress, universe, E131_DEFAULT_PORT)

        guard result == 0 else {
            return nil
        }

        return outgoingAddress
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

    deinit {
        self.disconnect()
    }
}
