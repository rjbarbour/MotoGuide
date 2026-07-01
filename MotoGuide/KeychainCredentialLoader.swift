import Foundation
import Security

enum KeychainCredentialLoader {
    // Contract: the iOS app stores only the proxy token under this service.
    // See /Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml.
    static func loadMotoGuideProxyToken(service: String = FactProxyContract.keychainService) -> String? {
        loadGenericPassword(service: service)
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
}
