import Foundation

// 原生 Swift 实现：RPPairing / CDTunnel wire format 和 HomeKit TLV8。
enum WireCodec {
    static func frame(magic: String, body: Data) throws -> Data {
        guard body.count <= Int(UInt16.max) else { throw CDTKError.protocolMismatch("报文超出 65535 字节") }
        let count = UInt16(body.count)
        return Data(magic.utf8) + Data([UInt8(count >> 8), UInt8(count & 0xff)]) + body
    }

    static func json(_ value: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys])
    }

    static func object(_ data: Data) throws -> [String: Any] {
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CDTKError.protocolMismatch("响应不是 JSON 字典")
        }
        return dict
    }

    static func tlvEncode(_ entries: [(UInt8, Data)]) -> Data {
        var result = Data()
        for (type, value) in entries {
            if value.isEmpty {
                result.append(contentsOf: [type, 0])
                continue
            }
            for start in stride(from: 0, to: value.count, by: 255) {
                let end = min(start + 255, value.count)
                result.append(contentsOf: [type, UInt8(end - start)])
                result.append(value.subdata(in: start..<end))
            }
        }
        return result
    }

    static func tlvDecode(_ data: Data) throws -> [UInt8: Data] {
        let bytes = Array(data)
        var result: [UInt8: Data] = [:]
        var i = 0
        while i < bytes.count {
            guard i + 2 <= bytes.count else { throw CDTKError.protocolMismatch("TLV8 头长度错误") }
            let type = bytes[i]
            let length = Int(bytes[i + 1])
            i += 2
            guard i + length <= bytes.count else { throw CDTKError.protocolMismatch("TLV8 数据截断") }
            result[type, default: Data()].append(contentsOf: bytes[i..<(i + length)])
            i += length
        }
        return result
    }

    static func nested(_ obj: Any, _ keys: [String]) throws -> Any {
        var current = obj
        for key in keys {
            guard let dict = current as? [String: Any], let next = dict[key] else {
                throw CDTKError.protocolMismatch("响应缺少字段：\(keys.joined(separator: "."))")
            }
            current = next
        }
        return current
    }

    static func base64(_ obj: Any, _ keys: [String]) throws -> Data {
        guard let string = try nested(obj, keys) as? String,
              let data = Data(base64Encoded: string) else {
            throw CDTKError.protocolMismatch("响应字段不是 Base64 数据")
        }
        return data
    }
}
