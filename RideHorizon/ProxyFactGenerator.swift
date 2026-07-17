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
        print("[RideHorizonDebug] [\(category)] \(message)")
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
    /// Temporary private-beta compatibility switch. Remove once the RideHorizon host is live.
    static let useLegacyProductionProxy = true
    static let rideHorizonProductionBaseURL = URL(string: "https://ridehorizon.digitalmercenaries.ai")!
    static let legacyProductionBaseURL = URL(string: "https://motoguide-fact-proxy.fly.dev")!
    static var productionBaseURL: URL {
        useLegacyProductionProxy ? legacyProductionBaseURL : rideHorizonProductionBaseURL
    }
    static let localDevelopmentBaseURL = URL(string: "http://127.0.0.1:3000")!
    static let keychainService = "RideHorizonProxy"
    static let deviceIdKeychainService = "RideHorizonDeviceId"
    static let factTimeoutSeconds: TimeInterval = 3
    static let speechTimeoutSeconds: TimeInterval = 15
    static let healthTimeoutSeconds: TimeInterval = 3
    static let iosTimeoutSeconds = factTimeoutSeconds

    static func factEndpoint(baseURL: URL = productionBaseURL) -> URL {
        baseURL
            .appendingPathComponent("v1")
            .appendingPathComponent("fact")
    }

    static func speechEndpoint(baseURL: URL = productionBaseURL) -> URL {
        baseURL
            .appendingPathComponent("v1")
            .appendingPathComponent("speech")
    }

    static func provisioningEndpoint(baseURL: URL = productionBaseURL) -> URL {
        baseURL
            .appendingPathComponent("v1")
            .appendingPathComponent("provision")
    }

    static func healthEndpoint(baseURL: URL = productionBaseURL) -> URL {
        baseURL.appendingPathComponent("health")
    }
}

struct ProxyFactGenerator: PlaceFactGenerating {
    // Contract: see /Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml.
    typealias ProxyTokenProvider = () -> String?
    typealias DeviceIdProvider = () -> String?
    typealias CredentialInvalidator = () -> Void

    private let proxyTokenProvider: ProxyTokenProvider
    private let deviceIdProvider: DeviceIdProvider
    private let credentialInvalidator: CredentialInvalidator
    private let session: URLSession
    private let endpoint: URL

    init(
        proxyTokenProvider: @escaping ProxyTokenProvider = { KeychainCredentialLoader.loadRideHorizonProxyToken() },
        deviceIdProvider: @escaping DeviceIdProvider = { KeychainCredentialLoader.loadRideHorizonDeviceId() },
        credentialInvalidator: @escaping CredentialInvalidator = { ProxyCredentialLifecycle.invalidate() },
        session: URLSession = .shared,
        baseURL: URL = FactProxyContract.productionBaseURL,
        endpoint: URL? = nil
    ) {
        self.proxyTokenProvider = proxyTokenProvider
        self.deviceIdProvider = deviceIdProvider
        self.credentialInvalidator = credentialInvalidator
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
        urlRequest.timeoutInterval = FactProxyContract.factTimeoutSeconds
        urlRequest.setValue("Bearer \(proxyToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let deviceId = deviceIdProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
           !deviceId.isEmpty {
            urlRequest.setValue(deviceId, forHTTPHeaderField: "X-RideHorizon-Device-Id")
            ProxyDiagnostics.log("Proxy", "Device id present: yes, length \(deviceId.count)")
        }
        urlRequest.httpBody = try JSONEncoder().encode(FactProxyRequest(from: request))
        ProxyDiagnostics.log(
            "Proxy",
            "Request body boundary=\(request.boundary.factLabel), factMode=\(request.factMode.rawValue), placeName=\(request.placeName), countryContext=\(request.countryContext ?? "nil")"
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
            if http.statusCode == 401 {
                credentialInvalidator()
            }
            throw PlaceFactError.httpError(http.statusCode)
        }

        let decoded: FactProxyResponse
        do {
            decoded = try JSONDecoder().decode(FactProxyResponse.self, from: data)
        } catch {
            ProxyDiagnostics.log("Proxy", "Decode error: \(error.localizedDescription)")
            throw error
        }

        guard let sanitized = FactPhraseBuilder.sanitize(decoded.fact, mode: request.factMode) else {
            ProxyDiagnostics.log("Proxy", "Proxy fact failed local sanitization.")
            throw PlaceFactError.invalidResponse
        }
        ProxyDiagnostics.log("Proxy", "Fact accepted: \(sanitized)")
        return sanitized
    }
}

struct ProxySpeechGenerator {
    typealias ProxyTokenProvider = () -> String?
    typealias DeviceIdProvider = () -> String?
    typealias CredentialInvalidator = () -> Void

    private let proxyTokenProvider: ProxyTokenProvider
    private let deviceIdProvider: DeviceIdProvider
    private let credentialInvalidator: CredentialInvalidator
    private let session: URLSession
    private let endpoint: URL
    private static let maxSpeechTextLength = 1400

    init(
        proxyTokenProvider: @escaping ProxyTokenProvider = { KeychainCredentialLoader.loadRideHorizonProxyToken() },
        deviceIdProvider: @escaping DeviceIdProvider = { KeychainCredentialLoader.loadRideHorizonDeviceId() },
        credentialInvalidator: @escaping CredentialInvalidator = { ProxyCredentialLifecycle.invalidate() },
        session: URLSession = .shared,
        baseURL: URL = FactProxyContract.productionBaseURL,
        endpoint: URL? = nil
    ) {
        self.proxyTokenProvider = proxyTokenProvider
        self.deviceIdProvider = deviceIdProvider
        self.credentialInvalidator = credentialInvalidator
        self.session = session
        self.endpoint = endpoint ?? FactProxyContract.speechEndpoint(baseURL: baseURL)
    }

    func speechAudio(for text: String) async throws -> Data {
        let boundedText = Self.normalizedSingleSpeechText(text)
        if boundedText.count != text.count {
            ProxyDiagnostics.log(
                "Speech",
                "Truncated speech text from \(text.count) to \(boundedText.count) chars to match proxy limit \(Self.maxSpeechTextLength)."
            )
        }
        return try await speechAudioChunk(for: boundedText)
    }

    func speechAudios(for text: String) async throws -> [Data] {
        let chunks = Self.chunkSpeechText(Self.normalizedSpeechText(text))
        if chunks.count > 1 {
            ProxyDiagnostics.log("Speech", "Splitting speech text into \(chunks.count) chunk(s) for proxy requests.")
        }

        var responses: [Data] = []
        for chunk in chunks {
            responses.append(try await speechAudioChunk(for: chunk))
        }
        return responses
    }

    private func speechAudioChunk(for text: String) async throws -> Data {
        guard let proxyToken = proxyTokenProvider(), !proxyToken.isEmpty else {
            ProxyDiagnostics.log("Speech", "Missing proxy token. No speech request sent.")
            throw PlaceFactError.missingProxyToken
        }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = FactProxyContract.speechTimeoutSeconds
        urlRequest.setValue("Bearer \(proxyToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        ProxyDiagnostics.log("Speech", "Proxy token present: yes, length \(proxyToken.count)")
        if let deviceId = deviceIdProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
           !deviceId.isEmpty {
            urlRequest.setValue(deviceId, forHTTPHeaderField: "X-RideHorizon-Device-Id")
            ProxyDiagnostics.log("Speech", "Device id present: yes, length \(deviceId.count)")
        } else {
            ProxyDiagnostics.log("Speech", "Device id present: no")
        }
        urlRequest.httpBody = try JSONEncoder().encode(SpeechProxyRequest(text: text))

        ProxyDiagnostics.log(
            "Speech",
            "Preparing POST \(endpoint.absoluteString), textLength=\(text.count), timeout=\(FactProxyContract.speechTimeoutSeconds)s"
        )
        await ProxyDiagnostics.logResolution(for: endpoint)

        let data: Data
        let response: URLResponse
        let started = Date()
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            ProxyDiagnostics.log(
                "Speech",
                "Network error for \(endpoint.absoluteString) after \(Self.elapsedSeconds(since: started))s: \(error.localizedDescription)"
            )
            throw error
        }
        let elapsedSeconds = Self.elapsedSeconds(since: started)
        guard let http = response as? HTTPURLResponse else {
            ProxyDiagnostics.log("Speech", "Invalid response type after \(elapsedSeconds)s: \(type(of: response))")
            throw PlaceFactError.invalidResponse
        }
        ProxyDiagnostics.log("Speech", "HTTP \(http.statusCode), \(data.count) byte(s) received, elapsedToLastByte=\(elapsedSeconds)s.")
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 401 {
                credentialInvalidator()
            }
            if let proxyError = try? JSONDecoder().decode(SpeechProxyErrorResponse.self, from: data) {
                ProxyDiagnostics.log("Speech", "Proxy diagnostic code \(proxyError.code.rawValue).")
                throw PlaceFactError.speechServiceUnavailable(code: proxyError.code.rawValue)
            }
            ProxyDiagnostics.log("Speech", "Proxy speech failed with HTTP \(http.statusCode).")
            throw PlaceFactError.httpError(http.statusCode)
        }
        if let contentType = http.value(forHTTPHeaderField: "Content-Type"), !contentType.lowercased().hasPrefix("audio/") {
            ProxyDiagnostics.log("Speech", "Unexpected content type: \(contentType)")
            throw PlaceFactError.invalidResponse
        }
        guard !data.isEmpty else {
            ProxyDiagnostics.log("Speech", "Proxy speech returned empty audio.")
            throw PlaceFactError.invalidResponse
        }
        return data
    }

    private static func normalizedSpeechText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedSingleSpeechText(_ text: String) -> String {
        let trimmed = normalizedSpeechText(text)
        guard trimmed.count > maxSpeechTextLength else { return trimmed }
        return String(trimmed.prefix(maxSpeechTextLength))
    }

    private static func chunkSpeechText(_ text: String) -> [String] {
        guard text.count > maxSpeechTextLength else {
            return [text]
        }

        var chunks: [String] = []
        var current = ""

        for token in text.split(whereSeparator: { $0.isWhitespace }) {
            let word = String(token)
            if word.count > maxSpeechTextLength {
                if !current.isEmpty {
                    chunks.append(current)
                    current = ""
                }
                chunks.append(contentsOf: hardSplit(word))
                continue
            }

            if current.isEmpty {
                current = word
                continue
            }

            if current.count + 1 + word.count <= maxSpeechTextLength {
                current.append(" ")
                current.append(word)
            } else {
                chunks.append(current)
                current = word
            }
        }

        if !current.isEmpty {
            chunks.append(current)
        }
        return chunks
    }

    private static func hardSplit(_ text: String) -> [String] {
        var chunks: [String] = []
        var start = text.startIndex
        while start < text.endIndex {
            let end = text.index(start, offsetBy: maxSpeechTextLength, limitedBy: text.endIndex) ?? text.endIndex
            chunks.append(String(text[start..<end]))
            start = end
        }
        return chunks
    }

    private static func elapsedSeconds(since date: Date) -> String {
        String(format: "%.2f", Date().timeIntervalSince(date))
    }
}

protocol ProxySpeechGenerating {
    func speechAudios(for text: String) async throws -> [Data]
}

extension ProxySpeechGenerator: ProxySpeechGenerating {}

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
        request.timeoutInterval = FactProxyContract.healthTimeoutSeconds
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
    let factMode: String
    let countryContext: String?
    let placeHierarchy: PlaceHierarchy
    let riderContext: RiderContext

    init(from request: PlaceFactRequest) {
        self.boundary = request.boundary.factLabel
        self.placeName = request.placeName
        self.factMode = request.factMode.rawValue
        self.countryContext = request.countryContext
        self.placeHierarchy = request.placeHierarchy
        self.riderContext = request.riderContext
    }
}

private struct FactProxyResponse: Decodable {
    let fact: String
}

private struct SpeechProxyRequest: Encodable {
    let text: String
}

private struct SpeechProxyErrorResponse: Decodable {
    let error: String
    let code: SpeechProxyDiagnosticCode
}

private enum SpeechProxyDiagnosticCode: String, Decodable {
    case authentication = "RH-TTS-01"
    case accountCapacity = "RH-TTS-02"
    case throttled = "RH-TTS-03"
    case upstreamFailure = "RH-TTS-04"
}
