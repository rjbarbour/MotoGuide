import Foundation
import Security

enum KeychainCredentialLoader {
    // Contract: the iOS app stores only proxy credentials under these services.
    // See /Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml.
    static func loadMotoGuideProxyToken(service: String = FactProxyContract.keychainService) -> String? {
        loadGenericPassword(service: service)
    }

    static func storeMotoGuideProxyToken(_ token: String, service: String = FactProxyContract.keychainService) -> Bool {
        storeGenericPassword(token, service: service)
    }

    static func loadMotoGuideDeviceId(service: String = FactProxyContract.deviceIdKeychainService) -> String? {
        loadGenericPassword(service: service)
    }

    static func storeMotoGuideDeviceId(_ deviceId: String, service: String = FactProxyContract.deviceIdKeychainService) -> Bool {
        storeGenericPassword(deviceId, service: service)
    }

    static func loadGenericPassword(service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let password = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !password.isEmpty else {
            return nil
        }
        return password
    }

    static func storeGenericPassword(_ password: String, service: String) -> Bool {
        guard let data = password
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .data(using: .utf8),
              !data.isEmpty else {
            return false
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }
        guard updateStatus == errSecItemNotFound else {
            return false
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }
}

#if DEBUG
enum DebugProxyTokenImporter {
    private static let environmentKey = "MOTOGUIDE_PROXY_TOKEN"

    static func importFromEnvironment() {
        guard let token = ProcessInfo.processInfo.environment[environmentKey],
              KeychainCredentialLoader.storeMotoGuideProxyToken(token) else {
            return
        }
        print("Stored MotoGuide proxy token in iOS Keychain service \(FactProxyContract.keychainService).")
    }
}
#endif
