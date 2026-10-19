import Foundation
import Security

struct PairingRecord {
    let identifier: String
    let privateKey: Data
    let publicKey: Data

    init(data: Data) throws {
        guard let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            if let text = String(data: data, encoding: .utf8),
               let json = text.data(using: .utf8),
               let dictionary = try? JSONSerialization.jsonObject(with: json) as? [String: Any] {
                try self.init(dictionary: dictionary)
                return
            }
            throw CDTKError.invalidPairing("文件既不是 plist 也不是 JSON 配对记录；请确认没有导入网页或压缩包。")
        }
        try self.init(dictionary: dict)
    }

    private init(dictionary dict: [String: Any]) throws {
        // SideStore / RemotePairing records can use differing name casing and representations.
        func bytes(_ keys: [String]) -> Data? {
            for key in keys {
                guard let value = dict[key] else { continue }
                if let data = value as? Data { return data }
                if let string = value as? String {
                    if let decoded = Data(base64Encoded: string) { return decoded }
                    let hex = string.replacingOccurrences(of: " ", with: "")
                    if hex.count.isMultiple(of: 2), hex.count >= 64,
                       hex.allSatisfy({ $0.isHexDigit }) {
                        var out = Data()
                        var index = hex.startIndex
                        while index < hex.endIndex {
                            let next = hex.index(index, offsetBy: 2)
                            guard let b = UInt8(hex[index..<next], radix: 16) else { return nil }
                            out.append(b)
                            index = next
                        }
                        return out
                    }
                }
                if let list = value as? [UInt8] { return Data(list) }
            }
            return nil
        }
        let name = (dict["host_identifier"] as? String) ??
                   (dict["identifier"] as? String) ??
                   (dict["HostID"] as? String) ?? ""
        let secret = bytes(["private_key", "privateKey", "private-key"])
        let pub = bytes(["public_key", "publicKey", "public-key"])
        guard !name.isEmpty, let secret, secret.count >= 32,
              let pub, pub.count >= 32 else {
            let known = dict.keys.sorted().filter { !$0.lowercased().contains("password") }
            if dict["HostPrivateKey"] != nil || dict["DeviceCertificate"] != nil {
                throw CDTKError.invalidPairing("这是传统 Lockdown 信任记录，不是 RSD Remote Pairing Ed25519 配对记录。请使用可导出 Remote Pairing 的工具重新生成。")
            }
            throw CDTKError.invalidPairing("缺少有效的 identifier / private_key / public_key。识别到的字段：\(known.joined(separator: ", "))")
        }
        self.identifier = name
        self.privateKey = Data(secret.prefix(32))
        self.publicKey = Data(pub.prefix(32))
    }

}

enum CDTKError: LocalizedError {
    case invalidPairing(String)
    case connection(String)
    case protocolMismatch(String)

    var errorDescription: String? {
        switch self {
        case .invalidPairing(let text), .connection(let text), .protocolMismatch(let text): return text
        }
    }
}

final class PairingVault {
    static let shared = PairingVault()
    private let service = "com.cdtk.swifttoolkit.pairing"
    private let account = "remote-pairing"
    private init() {}

    func save(_ data: Data) throws {
        _ = try PairingRecord(data: data)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account]
        let update: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw CDTKError.invalidPairing("更新钥匙串失败（错误 \(updateStatus)）")
        }
        var request = query
        request[kSecValueData as String] = data
        request[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(request as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CDTKError.invalidPairing("无法写入本机钥匙串（错误 \(status)）")
        }
    }

    func load() throws -> PairingRecord? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw CDTKError.invalidPairing("读取钥匙串失败（错误 \(status)）")
        }
        return try PairingRecord(data: data)
    }

    func remove() {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                       kSecAttrService as String: service,
                       kSecAttrAccount as String: account] as CFDictionary)
    }
}
