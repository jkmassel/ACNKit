import Foundation

struct SocketBindError: Error, RawRepresentable {

    typealias RawValue = Int32
    var rawValue: Int32

    init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    var reason: String{
        switch self.rawValue {
        case EACCES: return "Either the address is protected, and the user is not the superuser, or search permission is denied on a component of the path prefix."
        case EADDRINUSE: return "The given address is already in use. For Internet domain sockets, The port number was specified as zero in the socket address structure, but, upon attempting to bind to an ephemeral port, it was determined that all port numbers in the ephemeral port range are currently in use."
        case EBADF: return "sockfd is not a valid file descriptor."
        case EINVAL: return "Either the socket is already bound to an address, the socket's addrlen is wrong, or addr is not a valid address for this socket's domain."
        case ENOTSOCK: return "The file descriptor sockfd does not refer to a socket."
        case EADDRNOTAVAIL: return "A nonexistent interface was requested or the requested address was not local."
        case EFAULT: return "Socket address points outside the user's accessible address space."
        case ELOOP: return "Too many symbolic links were encountered in resolving addr."
        case ENAMETOOLONG: return "Socket address is too long"
        case ENOENT: return "A component in the directory prefix of the socket pathname does not exist."
        case ENOMEM: return "Insufficient kernel memory was available."
        case ENOTDIR: return "A component of the path prefix is not a directory."
        case EROFS: return "The socket inode would reside on a read-only filesystem."
        default: return "Unknown Error"
        }
    }
}
