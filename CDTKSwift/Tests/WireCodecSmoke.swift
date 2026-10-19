import Foundation

enum CDTKError: Error {
    case invalidPairing(String)
    case connection(String)
    case protocolMismatch(String)
}

@main
struct TestWire {
    static func main() throws {
        let raw = Data((0..<600).map { UInt8($0 % 256) })
        let tlv = WireCodec.tlvEncode([(1, raw), (6, Data([4]))])
        let decoded = try WireCodec.tlvDecode(tlv)
        precondition(decoded[1] == raw && decoded[6] == Data([4]))
        let body = try WireCodec.json(["mtu": 16000, "type": "clientHandshakeRequest"])
        let frame = try WireCodec.frame(magic: "CDTunnel", body: body)
        precondition(frame.prefix(8) == Data("CDTunnel".utf8))
        precondition(Int(frame[8]) * 256 + Int(frame[9]) == body.count)
        let parsed = try WireCodec.object(body)
        let mtu = try WireCodec.nested(parsed, ["mtu"]) as? Int
        precondition(mtu == 16000)
        print("WireCodec smoke tests passed")
    }
}
