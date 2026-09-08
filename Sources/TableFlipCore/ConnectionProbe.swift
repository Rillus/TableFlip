import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public enum ConnectionProbe {
    public static func tcp(host: String, port: Int) -> Bool {
        guard port > 0, port <= 65535 else { return false }
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        #if os(Linux)
        hints.ai_socktype = Int32(SOCK_STREAM.rawValue)
        #else
        hints.ai_socktype = SOCK_STREAM
        #endif
        var result: UnsafeMutablePointer<addrinfo>?
        let lookup = getaddrinfo(host, String(port), &hints, &result)
        guard lookup == 0, let first = result else { return false }
        defer { freeaddrinfo(result) }
        let socketFd = socket(first.pointee.ai_family, first.pointee.ai_socktype, first.pointee.ai_protocol)
        guard socketFd >= 0 else { return false }
        defer { _ = close(socketFd) }
        let status = connect(socketFd, first.pointee.ai_addr, first.pointee.ai_addrlen)
        return status == 0
    }
}
