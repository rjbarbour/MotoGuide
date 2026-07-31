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

    @discardableResult
    static func deleteRideHorizonDeviceId(service: String = FactProxyContract.deviceIdKeychainService) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
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

enum ProxyCredentialLifecycle {
    static func invalidate() {
        KeychainCredentialLoader.deleteRideHorizonProxyToken()
    }
}

enum ProxySessionProvisionError: LocalizedError, Equatable {
    case invalidResponse
    case missingToken
    case keychainFailure
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "RideHorizon could not obtain proxy session access."
        case .missingToken:
            return "Proxy session response did not include a token."
        case .keychainFailure:
            return "RideHorizon could not securely store automatic proxy access on this device."
        case .httpError(let statusCode):
            return "Proxy session provisioning returned HTTP \(statusCode)."
        }
    }
}

private struct FallbackSessionRequest: Encodable {
    let reason: String
}

private struct FallbackSessionResponse: Decodable {
    let sessionToken: String
}

private struct DeviceIdentifierStore {
    private let service = FactProxyContract.deviceIdKeychainService

    func loadOrCreate() throws -> String {
        if let existing = KeychainCredentialLoader.loadRideHorizonDeviceId(service: service),
           !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return existing
        }

        let deviceId = "rh-ios-\(UUID().uuidString.lowercased())"
        let normalized = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard KeychainCredentialLoader.storeRideHorizonDeviceId(normalized, service: service) else {
            throw ProxySessionProvisionError.keychainFailure
        }
        return normalized
    }
}

final actor ProxySessionCoordinator {
    static let shared = ProxySessionCoordinator()

    enum ProvisionTarget {
        case production
    }

    private var inFlightTask: Task<Void, Error>?
    private let session: URLSession
    private let deviceIdentifierStore: DeviceIdentifierStore

    fileprivate init(
        session: URLSession = .shared,
        deviceIdentifierStore: DeviceIdentifierStore = DeviceIdentifierStore()
    ) {
        self.session = session
        self.deviceIdentifierStore = deviceIdentifierStore
    }

    func provisionSessionIfNeeded(_ target: ProvisionTarget = .production) async throws {
        if KeychainCredentialLoader.loadRideHorizonProxyToken() != nil {
            return
        }

        if let existing = inFlightTask {
            return try await existing.value
        }

        let task = Task {
            try await self.provisionSession(target: target)
        }
        inFlightTask = task
        defer { inFlightTask = nil }
        try await task.value
    }

    func forceProvisionSession(_ target: ProvisionTarget = .production) async throws {
        inFlightTask?.cancel()
        inFlightTask = nil
        ProxyCredentialLifecycle.invalidate()
        try await provisionSessionIfNeeded(target)
    }

    private func provisionSession(target: ProvisionTarget) async throws {
        let endpoint: URL = switch target {
        case .production:
            FactProxyContract.sessionFallbackEndpoint()
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = FactProxyContract.factTimeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(FallbackSessionRequest(reason: "app_auto_provision"))
        let deviceId = try deviceIdentifierStore.loadOrCreate()
        request.setValue(deviceId, forHTTPHeaderField: "X-RideHorizon-Device-Id")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            ProxyDiagnostics.log("Auth", "Session fallback request network error: \(error.localizedDescription)")
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProxySessionProvisionError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ProxySessionProvisionError.httpError(httpResponse.statusCode)
        }

        let sessionResponse = try JSONDecoder().decode(FallbackSessionResponse.self, from: data)
        let token = sessionResponse.sessionToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard token.hasPrefix("rh_") && token.count > 10 else {
            throw ProxySessionProvisionError.missingToken
        }
        guard KeychainCredentialLoader.storeRideHorizonProxyToken(token) else {
            throw ProxySessionProvisionError.keychainFailure
        }
        ProxyDiagnostics.log("Auth", "Provisioned fallback proxy session.")
    }
}

extension FactProxyContract {
    static func sessionFallbackEndpoint() -> URL {
        productionBaseURL
            .appendingPathComponent("v1")
            .appendingPathComponent("session")
            .appendingPathComponent("fallback")
    }
}
