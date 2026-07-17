import Foundation
import Security

enum KeychainCredentialLoader {
    // Contract: the iOS app stores only proxy credentials under these services.
    // See /Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml.
    static func loadRideHorizonProxyToken(service: String = FactProxyContract.keychainService) -> String? {
        loadGenericPassword(service: service)
    }

    static func storeRideHorizonProxyToken(_ token: String, service: String = FactProxyContract.keychainService) -> Bool {
        storeGenericPassword(token, service: service)
    }

    @discardableResult
    static func deleteRideHorizonProxyToken(service: String = FactProxyContract.keychainService) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    static func loadRideHorizonDeviceId(service: String = FactProxyContract.deviceIdKeychainService) -> String? {
        loadGenericPassword(service: service)
    }

    static func storeRideHorizonDeviceId(_ deviceId: String, service: String = FactProxyContract.deviceIdKeychainService) -> Bool {
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
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }
}

extension Notification.Name {
    static let rideHorizonCredentialInvalidated = Notification.Name("RideHorizonCredentialInvalidated")
}

enum ProxyCredentialLifecycle {
    static func invalidate() {
        KeychainCredentialLoader.deleteRideHorizonProxyToken()
        NotificationCenter.default.post(name: .rideHorizonCredentialInvalidated, object: nil)
    }
}

enum CredentialProvisioningError: LocalizedError, Equatable {
    case invalidInvite
    case invalidResponse
    case keychainFailure

    var errorDescription: String? {
        switch self {
        case .invalidInvite:
            return "That invite code is invalid or has expired."
        case .invalidResponse:
            return "RideHorizon could not complete setup. Please try again."
        case .keychainFailure:
            return "RideHorizon could not securely store access on this device."
        }
    }
}

struct ProxyCredentialProvisioner {
    typealias CredentialStore = (String) -> Bool
    typealias DeviceIdProvider = () -> String?
    typealias DeviceIdStore = (String) -> Bool
    typealias DeviceIdGenerator = () -> String

    private let session: URLSession
    private let endpoint: URL
    private let credentialStore: CredentialStore
    private let deviceIdProvider: DeviceIdProvider
    private let deviceIdStore: DeviceIdStore
    private let deviceIdGenerator: DeviceIdGenerator

    init(
        session: URLSession = .shared,
        endpoint: URL = FactProxyContract.provisioningEndpoint(),
        credentialStore: @escaping CredentialStore = { KeychainCredentialLoader.storeRideHorizonProxyToken($0) },
        deviceIdProvider: @escaping DeviceIdProvider = { KeychainCredentialLoader.loadRideHorizonDeviceId() },
        deviceIdStore: @escaping DeviceIdStore = { KeychainCredentialLoader.storeRideHorizonDeviceId($0) },
        deviceIdGenerator: @escaping DeviceIdGenerator = { "rh-ios-\(UUID().uuidString.lowercased())" }
    ) {
        self.session = session
        self.endpoint = endpoint
        self.credentialStore = credentialStore
        self.deviceIdProvider = deviceIdProvider
        self.deviceIdStore = deviceIdStore
        self.deviceIdGenerator = deviceIdGenerator
    }

    func redeem(inviteCode: String) async throws {
        let normalizedInvite = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedInvite.hasPrefix("rhi_"), normalizedInvite.count <= 128 else {
            throw CredentialProvisioningError.invalidInvite
        }

        let deviceId: String
        if let existing = deviceIdProvider()?.trimmingCharacters(in: .whitespacesAndNewlines), !existing.isEmpty {
            deviceId = existing
        } else {
            deviceId = deviceIdGenerator()
            guard deviceIdStore(deviceId) else {
                throw CredentialProvisioningError.keychainFailure
            }
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ProvisionRequest(
            inviteCode: normalizedInvite,
            deviceId: deviceId
        ))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CredentialProvisioningError.invalidResponse
        }
        guard httpResponse.statusCode == 201 else {
            if httpResponse.statusCode == 401 {
                throw CredentialProvisioningError.invalidInvite
            }
            throw CredentialProvisioningError.invalidResponse
        }

        let provisioned = try JSONDecoder().decode(ProvisionResponse.self, from: data)
        guard provisioned.credential.hasPrefix("rh_"), provisioned.credential.count <= 128 else {
            throw CredentialProvisioningError.invalidResponse
        }
        guard credentialStore(provisioned.credential) else {
            throw CredentialProvisioningError.keychainFailure
        }
    }

    private struct ProvisionRequest: Encodable {
        let inviteCode: String
        let deviceId: String
    }

    private struct ProvisionResponse: Decodable {
        let credentialId: UUID
        let credential: String
        let expiresAt: String
    }
}

#if DEBUG
enum DebugProxyTokenImporter {
    private static let environmentKey = "RIDEHORIZON_PROXY_TOKEN"

    static func importFromEnvironment() {
        guard let token = ProcessInfo.processInfo.environment[environmentKey],
              KeychainCredentialLoader.storeRideHorizonProxyToken(token) else {
            return
        }
        print("Stored RideHorizon proxy token in iOS Keychain service \(FactProxyContract.keychainService).")
    }
}
#endif
