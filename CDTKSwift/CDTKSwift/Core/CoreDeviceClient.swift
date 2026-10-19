import Foundation
import CryptoKit
import Network
import Security
import Dispatch
import Darwin

struct TunnelHandshake: Sendable {
    let sourceAddress: String
    let serverAddress: String
    let rsdPort: Int
    let mtu: Int
    let listenerPort: UInt16
}

/// CoreDevice Remote Pairing 探针。
/// 说明：目前实现 Pair Verify -> CreateListener -> TLS-PSK -> CDTunnel 握手。
/// 尚未实现内嵌 IPv6/TCP 协议栈及 RemoteXPC 设备服务，请勿把隧道握手等同于服务已可调用。
struct CoreDeviceClient {
    let host: String
    let pairingPort: UInt16

    init(host: String = "10.7.0.1", pairingPort: UInt16 = 49152) {
        self.host = host
        self.pairingPort = pairingPort
    }

    func checkPort() async throws {
        let socket = SocketChannel(host: host, port: pairingPort)
        defer { socket.close() }
        try await socket.open(timeout: 6)
    }

    func handshake(record: PairingRecord, progress: @escaping (String) -> Void) async throws -> TunnelHandshake {
        let pairing = SocketChannel(host: host, port: pairingPort)
        defer { pairing.close() }

        progress("正在连接本地 Remote Pairing 服务…")
        try await pairing.open(timeout: 8)
        progress("正在进行 X25519 / Ed25519 Pair Verify…")

        let initial: [String: Any] = [
            "request": ["_0": ["handshake": ["_0": [
                "hostOptions": ["attemptPairVerify": true],
                "wireProtocolVersion": 19
            ]]]]
        ]
        try await sendPlain(initial, sequence: 0, to: pairing)
        _ = try await pairing.readFrame(magic: "RPPairing")

        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        let m1 = WireCodec.tlvEncode([
            (6, Data([1])), (3, ephemeral.publicKey.rawRepresentation)
        ])
        try await sendPairEvent(m1, start: true, sequence: 1, to: pairing)

        let msg2 = try await pairing.readFrame(magic: "RPPairing")
        let tlv2 = try WireCodec.tlvDecode(WireCodec.base64(msg2, ["message", "plain", "_0", "event", "_0", "pairingData", "_0", "data"]))
        guard tlv2[6] == Data([2]), let remoteKey = tlv2[3], remoteKey.count == 32 else {
            throw CDTKError.protocolMismatch("Pair Verify M2 格式错误或设备拒绝配对")
        }
        let devicePublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: remoteKey)
        let sharedSecret = try ephemeral.sharedSecretFromKeyAgreement(with: devicePublicKey)
        let secretBytes = sharedSecret.withUnsafeBytes { Data($0) }
        let pairingEncryptionKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA512.self,
            salt: Data("Pair-Verify-Encrypt-Salt".utf8),
            sharedInfo: Data("Pair-Verify-Encrypt-Info".utf8),
            outputByteCount: 32
        )

        let messageToSign = ephemeral.publicKey.rawRepresentation + Data(record.identifier.utf8) + remoteKey
        let signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: record.privateKey)
        let signature = try signingKey.signature(for: messageToSign)
        let inner = WireCodec.tlvEncode([(1, Data(record.identifier.utf8)), (10, signature)])
        let encryptedInner = try encryptRaw(inner, key: pairingEncryptionKey,
                                            nonce: Data([0, 0, 0, 0] + Array("PV-Msg03".utf8)))
        let m3 = WireCodec.tlvEncode([(6, Data([3])), (5, encryptedInner)])
        try await sendPairEvent(m3, start: false, sequence: 2, to: pairing)

        let msg4 = try await pairing.readFrame(magic: "RPPairing")
        let tlv4 = try WireCodec.tlvDecode(WireCodec.base64(msg4, ["message", "plain", "_0", "event", "_0", "pairingData", "_0", "data"]))
        guard tlv4[6] == Data([4]), tlv4[7] == nil else {
            throw CDTKError.invalidPairing("配对认证失败：请确认 plist 与本机对应，并重新生成有效配对文件")
        }
        progress("设备已接受 Pair Verify；正在创建 TCP Listener…")

        let clientKey = derivedKey(secretBytes, info: "ClientEncrypt-main")
        let serverKey = derivedKey(secretBytes, info: "ServerEncrypt-main")
        let listenerRequest: [String: Any] = [
            "request": ["_0": ["createListener": [
                "key": secretBytes.base64EncodedString(),
                "peerConnectionsInfo": [["owningPID": Int(getpid()), "owningProcessName": "CoreDeviceSwift"]],
                "transportProtocolType": "tcp"
            ]]]
        ]
        let requestData = try WireCodec.json(listenerRequest)
        let zeroNonce = Data(repeating: 0, count: 12)
        let encrypted = try encryptRaw(requestData, key: clientKey, nonce: zeroNonce)
        let envelope: [String: Any] = [
            "message": ["streamEncrypted": ["_0": encrypted.base64EncodedString()]],
            "originatedBy": "host", "sequenceNumber": 3
        ]
        try await pairing.send(WireCodec.frame(magic: "RPPairing", body: WireCodec.json(envelope)))
        let listenerResponse = try await pairing.readFrame(magic: "RPPairing")
        let encryptedAnswer = try WireCodec.base64(listenerResponse, ["message", "streamEncrypted", "_0"])
        let decrypted = try decryptRaw(encryptedAnswer, key: serverKey, nonce: zeroNonce)
        let listenerJSON = try WireCodec.object(decrypted)
        guard let port = try WireCodec.nested(listenerJSON, ["response", "_1", "createListener", "port"]) as? Int,
              port > 0, port <= Int(UInt16.max) else {
            throw CDTKError.protocolMismatch("未取得有效的 TLS-PSK Listener 端口")
        }

        progress("Listener 已创建，正在进行原生 TLS-PSK 握手…")
        let tls = NWProtocolTLS.Options()
        sec_protocol_options_set_min_tls_protocol_version(tls.securityProtocolOptions, .TLSv12)
        sec_protocol_options_set_max_tls_protocol_version(tls.securityProtocolOptions, .TLSv12)
        sec_protocol_options_set_peer_authentication_required(tls.securityProtocolOptions, false)
        let keyData = secretBytes.withUnsafeBytes { DispatchData(bytes: $0) }
        let identityData = Data().withUnsafeBytes { DispatchData(bytes: $0) }
        sec_protocol_options_add_pre_shared_key(tls.securityProtocolOptions, keyData as __DispatchData, identityData as __DispatchData)

        let tunnel = SocketChannel(host: host, port: UInt16(port), tls: tls)
        defer { tunnel.close() }
        try await tunnel.open(timeout: 10)
        progress("TLS 通道建立，正在验证 CDTunnel 握手…")

        let clientHello: [String: Any] = ["type": "clientHandshakeRequest", "mtu": 16000]
        try await tunnel.send(WireCodec.frame(magic: "CDTunnel", body: WireCodec.json(clientHello)))
        let data = try await tunnel.readFrame(magic: "CDTunnel")
        guard let source = try WireCodec.nested(data, ["clientParameters", "address"]) as? String,
              let server = data["serverAddress"] as? String,
              let rsd = data["serverRSDPort"] as? Int,
              let mtu = try WireCodec.nested(data, ["clientParameters", "mtu"]) as? Int else {
            throw CDTKError.protocolMismatch("CDTunnel 握手完成但没有提供有效 IPv6 地址或 RSD 端口")
        }
        progress("已通过 CDTunnel 握手；原生 IPv6/RemoteXPC 服务阶段尚未实现。")
        return TunnelHandshake(sourceAddress: source, serverAddress: server,
                               rsdPort: rsd, mtu: mtu, listenerPort: UInt16(port))
    }

    private func sendPlain(_ body: [String: Any], sequence: Int, to socket: SocketChannel) async throws {
        let msg: [String: Any] = ["message": ["plain": ["_0": body]],
                                  "originatedBy": "host", "sequenceNumber": sequence]
        try await socket.send(WireCodec.frame(magic: "RPPairing", body: WireCodec.json(msg)))
    }

    private func sendPairEvent(_ tlv: Data, start: Bool, sequence: Int,
                               to socket: SocketChannel) async throws {
        let data: [String: Any] = ["event": ["_0": ["pairingData": ["_0": [
            "data": tlv.base64EncodedString(),
            "kind": "verifyManualPairing", "startNewSession": start
        ]]]]]
        try await sendPlain(data, sequence: sequence, to: socket)
    }

    private func derivedKey(_ raw: Data, info: String) -> SymmetricKey {
        HKDF<SHA512>.deriveKey(inputKeyMaterial: SymmetricKey(data: raw),
                               salt: Data(), info: Data(info.utf8), outputByteCount: 32)
    }

    // RPPairing 的 encrypted 字段不包含 12 字节 nonce，只包含 cipher + auth tag。
    private func encryptRaw(_ data: Data, key: SymmetricKey, nonce: Data) throws -> Data {
        let sealed = try ChaChaPoly.seal(data, using: key, nonce: ChaChaPoly.Nonce(data: nonce))
        return sealed.ciphertext + sealed.tag
    }

    private func decryptRaw(_ data: Data, key: SymmetricKey, nonce: Data) throws -> Data {
        guard data.count >= 16 else { throw CDTKError.protocolMismatch("加密报文过短") }
        let body = Data(data.dropLast(16))
        let tag = Data(data.suffix(16))
        let box = try ChaChaPoly.SealedBox(nonce: ChaChaPoly.Nonce(data: nonce), ciphertext: body, tag: tag)
        return try ChaChaPoly.open(box, using: key)
    }
}
