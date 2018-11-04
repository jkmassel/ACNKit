import Foundation
import e131

class SACNSocket{

    public let port: UInt16
    private let universe: UInt16
    private var socketFileDescriptor: Int32

    private let dispatchQueue: DispatchQueue
    var isConnected = false

    init(port: UInt16 = E131_DEFAULT_PORT, universe: UInt16) {
        self.port = port
        self.universe = universe
        self.socketFileDescriptor = e131_socket()

        self.dispatchQueue = DispatchQueue(label: "SACN-Socket-\(universe)")
        debugPrint("initialized socket")
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
            debugPrint("disconnecting")
            let handle = FileHandle(fileDescriptor: self.socketFileDescriptor)
            handle.closeFile()
            debugPrint("disconnected")

            //Set up a new socket for next time
            self.socketFileDescriptor = e131_socket()
        }

        self.isConnected = false
    }

    public func receive_packet() -> SACNPacket?{

        guard self.isConnected else { return nil }

        var packet = e131_packet_t()
        var returnNil = false

        self.dispatchQueue.sync {
            debugPrint("Waiting for packet")
            let result = e131_recv(self.socketFileDescriptor, &packet)
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


    }
    
    private func bind() throws{

        try self.dispatchQueue.sync {
            debugPrint("Binding")
            let result = e131_bind(self.socketFileDescriptor, self.port)

            if result != 0{
                debugPrint("Unable to bind socket on port: \(self.port). Error: \(errno)")
                throw SocketBindError(rawValue: errno)
            }

            debugPrint("Bound")
        }
    }

    private func multicast_join(universe: UInt16) -> Bool{

        let result = e131_multicast_join(self.socketFileDescriptor, universe)

        if result != 0{
            debugPrint("Unable to join multicast group for universe \(universe)")
        }

        return result == 0
    }

    deinit {
        self.disconnect()
    }
}
