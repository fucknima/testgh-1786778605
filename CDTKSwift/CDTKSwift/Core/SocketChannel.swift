import Foundation
import Network

/// Swift 原生 Network.framework 流式套接字；一条连接单独顺序收包。
final class SocketChannel {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "com.cdtk.socket", qos: .userInitiated)

    init(host: String, port: UInt16, tls: NWProtocolTLS.Options? = nil) {
        let p = NWEndpoint.Port(rawValue: port)!
        if let tls = tls {
            connection = NWConnection(host: NWEndpoint.Host(host), port: p,
                                      using: NWParameters(tls: tls, tcp: NWProtocolTCP.Options()))
        } else {
            connection = NWConnection(host: NWEndpoint.Host(host), port: p, using: .tcp)
        }
    }

    func open(timeout: TimeInterval = 8) async throws {
        let conn = connection
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let lock = NSLock()
            var resolved = false
            func complete(_ error: Error?) {
                lock.lock()
                defer { lock.unlock() }
                guard !resolved else { return }
                resolved = true
                if let error = error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready: complete(nil)
                case .failed(let error): complete(CDTKError.connection("连接失败：\(error.localizedDescription)"))
                case .cancelled: complete(CDTKError.connection("连接已关闭或超时"))
                default: break
                }
            }
            conn.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                lock.lock()
                let pending = !resolved
                lock.unlock()
                if pending { conn.cancel() }
            }
        }
    }

    func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            })
        }
    }

    func readExactly(_ count: Int) async throws -> Data {
        guard count >= 0, count <= 65536 else { throw CDTKError.protocolMismatch("接收字节数越界") }
        var result = Data()
        while result.count < count {
            let remaining = count - result.count
            let part: Data = try await withCheckedThrowingContinuation { continuation in
                connection.receive(minimumIncompleteLength: 1, maximumLength: remaining) { data, _, done, error in
                    if let error = error { continuation.resume(throwing: error) }
                    else if let data = data, !data.isEmpty { continuation.resume(returning: data) }
                    else { continuation.resume(throwing: CDTKError.connection(done ? "远端主动断开" : "未收到数据")) }
                }
            }
            result.append(part)
        }
        return result
    }

    func readFrame(magic: String) async throws -> [String: Any] {
        let header = try await readExactly(magic.utf8.count + 2)
        guard header.prefix(magic.utf8.count) == Data(magic.utf8) else {
            throw CDTKError.protocolMismatch("协议魔数不匹配，预期 \(magic)")
        }
        let b = Array(header.suffix(2))
        let len = Int(b[0]) << 8 | Int(b[1])
        return try WireCodec.object(try await readExactly(len))
    }

    func close() { connection.cancel() }
}
