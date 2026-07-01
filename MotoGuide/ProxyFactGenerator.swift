import Foundation
#if DEBUG
import Darwin
import SwiftUI

struct DebugLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let category: String
    let message: String
}

@MainActor
final class DebugLogStore: ObservableObject {
    static let shared = DebugLogStore()

    @Published private(set) var entries: [DebugLogEntry] = []
    private let maxEntries = 200

    private init() {}

    func clear() {
        entries.removeAll()
    }

    fileprivate func append(category: String, message: String) {
        entries.insert(DebugLogEntry(timestamp: Date(), category: category, message: message), at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
    }
}

enum ProxyDiagnostics {
    static let enabledKey = "ProxyDiagnosticsEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static func log(_ category: String, _ message: String) {
        guard isEnabled else { return }
        print("[MotoGuideDebug] [\(category)] \(message)")
        Task { @MainActor in
            DebugLogStore.shared.append(category: category, message: message)
        }
    }

    static func logResolution(for endpoint: URL) async {
        guard isEnabled else { return }
        guard let host = endpoint.host, !host.isEmpty else {
            log("DNS", "No host in URL \(endpoint.absoluteString)")
            return
        }

        let result = await resolve(host: host)
        log("DNS", result)
    }

    private static func resolve(host: String) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let started = Date()
                var hints = addrinfo(
                    ai_flags: AI_ADDRCONFIG,
                    ai_family: AF_UNSPEC,
                    ai_socktype: SOCK_STREAM,
                    ai_protocol: 0,
                    ai_addrlen: 0,
                    ai_canonname: nil,
                    ai_addr: nil,
                    ai_next: nil
                )
                var results: UnsafeMutablePointer<addrinfo>?
                let status = getaddrinfo(host, nil, &hints, &results)
                defer {
                    if let results {
                        freeaddrinfo(results)
                    }
                }

                let elapsedMilliseconds = Int(Date().timeIntervalSince(started) * 1000)
                guard status == 0 else {
                    let reason = String(cString: gai_strerror(status))
                    continuation.resume(returning: "Resolved \(host): no, \(reason), \(elapsedMilliseconds)ms")
                    return
                }

                var count = 0
                var cursor = results
                while cursor != nil {
                    count += 1
                    cursor = cursor?.pointee.ai_next
                }

                continuation.resume(returning: "Resolved \(host): yes, \(count) address(es), \(elapsedMilliseconds)ms")
            }
        }
    }
}
#else
enum ProxyDiagnostics {
    static func log(_ category: String, _ message: String) {}
    static func logResolution(for endpoint: URL) async {}
}
#endif

enum FactProxyContract {
    // Source of truth: /Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml.
    static let productionBaseURL = URL(string: "https://motoguide-fact-proxy.fly.dev")!
    static let localDevelopmentBaseURL = URL(string: "http://127.0.0.1:3000")!
    static let keychainService = "MotoGuideProxy"
    static let iosTimeoutSeconds: TimeInterval = 3

    static func factEndpoint(baseURL: URL = productionBaseURL) -> URL {
        baseURL
            .appendingPathComponent("v1")
            .appendingPathComponent("fact")
    }

    static func healthEndpoint(baseURL: URL = productionBaseURL) -> URL {
        baseURL.appendingPathComponent("health")
    }
}

struct ProxyFactGenerator: PlaceFactGenerating {
    // Contract: see /Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml.
    typealias ProxyTokenProvider = () -> String?

    private let proxyTokenProvider: ProxyTokenProvider
    private let session: URLSession
    private let endpoint: URL

    init(
        proxyTokenProvider: @escaping ProxyTokenProvider = { KeychainCredentialLoader.loadMotoGuideProxyToken() },
        session: URLSession = .shared,
        baseURL: URL = FactProxyContract.productionBaseURL,
        endpoint: URL? = nil
    ) {
        self.proxyTokenProvider = proxyTokenProvider
        self.session = session
        self.endpoint = endpoint ?? FactProxyContract.factEndpoint(baseURL: baseURL)
    }

    func fact(for request: PlaceFactRequest) async throws -> String {
        guard let proxyToken = proxyTokenProvider(), !proxyToken.isEmpty else {
            ProxyDiagnostics.log("Proxy", "Missing proxy token. No network request sent.")
            throw PlaceFactError.missingProxyToken
        }

        ProxyDiagnostics.log("Proxy", "Preparing POST \(endpoint.absoluteString)")
        ProxyDiagnostics.log("Proxy", "Proxy token present: yes, length \(proxyToken.count)")
        await ProxyDiagnostics.logResolution(for: endpoint)

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = FactProxyContract.iosTimeoutSeconds
        urlRequest.setValue("Bearer \(proxyToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(FactProxyRequest(from: request))
        ProxyDiagnostics.log(
            "Proxy",
            "Request body boundary=\(request.boundary.factLabel), placeName=\(request.placeName), countryContext=\(request.countryContext ?? "nil")"
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            ProxyDiagnostics.log("Proxy", "Network error for \(endpoint.absoluteString): \(error.localizedDescription)")
            throw error
        }

        guard let http = response as? HTTPURLResponse else {
            ProxyDiagnostics.log("Proxy", "Invalid response type: \(type(of: response))")
            throw PlaceFactError.invalidResponse
        }

        ProxyDiagnostics.log("Proxy", "HTTP \(http.statusCode), \(data.count) byte(s) received.")
        guard (200...299).contains(http.statusCode) else {
            throw PlaceFactError.httpError(http.statusCode)
        }

        let decoded: FactProxyResponse
        do {
            decoded = try JSONDecoder().decode(FactProxyResponse.self, from: data)
        } catch {
            ProxyDiagnostics.log("Proxy", "Decode error: \(error.localizedDescription)")
            throw error
        }

        guard let sanitized = FactPhraseBuilder.sanitize(decoded.fact) else {
            ProxyDiagnostics.log("Proxy", "Proxy fact failed local sanitization.")
            throw PlaceFactError.invalidResponse
        }
        ProxyDiagnostics.log("Proxy", "Fact accepted: \(sanitized)")
        return sanitized
    }
}

struct ProxyHealthChecker {
    // Contract: public GET /health returns text/plain "ok" and does not require bearer auth.
    private let session: URLSession
    private let endpoint: URL

    init(
        session: URLSession = .shared,
        baseURL: URL = FactProxyContract.productionBaseURL,
        endpoint: URL? = nil
    ) {
        self.session = session
        self.endpoint = endpoint ?? FactProxyContract.healthEndpoint(baseURL: baseURL)
    }

    func isHealthy() async -> Bool {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = FactProxyContract.iosTimeoutSeconds
        ProxyDiagnostics.log("Proxy", "Checking health \(endpoint.absoluteString)")
        await ProxyDiagnostics.logResolution(for: endpoint)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let body = String(data: data, encoding: .utf8) else {
                ProxyDiagnostics.log("Proxy", "Health check failed: invalid response.")
                return false
            }
            let healthy = body.trimmingCharacters(in: .whitespacesAndNewlines) == "ok"
            ProxyDiagnostics.log("Proxy", "Health HTTP \(http.statusCode), body=\(body.trimmingCharacters(in: .whitespacesAndNewlines)), healthy=\(healthy)")
            return healthy
        } catch {
            ProxyDiagnostics.log("Proxy", "Health network error: \(error.localizedDescription)")
            return false
        }
    }
}

private struct FactProxyRequest: Encodable {
    let boundary: String
    let placeName: String
    let countryContext: String?

    init(from request: PlaceFactRequest) {
        self.boundary = request.boundary.factLabel
        self.placeName = request.placeName
        self.countryContext = request.countryContext
    }
}

private struct FactProxyResponse: Decodable {
    let fact: String
}
