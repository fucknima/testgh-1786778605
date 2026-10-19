import Foundation
import Security

struct PairingRecord {
    let identifier: String
    let privateKey: Data
    let publicKey: Data

    init(data: Data) throws {
        guard let dict = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw CDTKError.invalidPairing("配对文件不是有效的 plist 字典")
        }
        guard let identifier = dict["identifier"] as? String, !identifier.isEmpty,
              let privateKey = dict["private_key"] as? Data, privateKey.count >= 32,
              let publicKey = dict["public_key"] as? Data, publicKey.count >= 32 else {
            throw CDTKError.invalidPairing("需要 identifier、private_key、public_key；请使用 Remote Pairing 格式，而不是普通 Lockdown plist")
        }
        self.identifier = identifier
        self.privateKey = Data(privateKey.prefix(32))
        self.publicKey = Data(publicKey.prefix(32))
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
