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

    static func log(_ category: String, _ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        let resolvedMessage = message()
        print("[RideHorizonDebug] [\(category)] \(resolvedMessage)")
        Task { @MainActor in
            DebugLogStore.shared.append(category: category, message: resolvedMessage)
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
    static func log(_ category: String, _ message: @autoclosure () -> String) {}
    static func logResolution(for endpoint: URL) async {}
}
#endif

enum FactProxyContract {
    // Source of truth: /Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml.
    /// Stable public edge. Cloudflare owns origin cutover so released apps never
    /// need to know the transitional Fly app name.
    static let productionBaseURL = URL(string: "https://ridehorizon.digitalmercenaries.ai")!
    static let localDevelopmentBaseURL = URL(string: "http://127.0.0.1:3000")!
    static let keychainService = "RideHorizonProxy"
    static let deviceIdKeychainService = "RideHorizonDeviceId"
    static let factTimeoutSeconds: TimeInterval = 35
    static let speechTimeoutSeconds: TimeInterval = 35
    static let healthTimeoutSeconds: TimeInterval = 10
    static let sessionTimeoutSeconds: TimeInterval = 12
    static let sessionOperationTimeoutSeconds: TimeInterval = 30
    static let iosTimeoutSeconds: TimeInterval = 60
    static let retryDelaysSeconds: [TimeInterval] = [3, 10]
    static let rideIdHeader = "X-RideHorizon-Ride-Id"
    static let previousResponseIdHeader = "X-RideHorizon-Previous-Response-Id"
    static let responseIdHeader = "X-RideHorizon-Response-Id"

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

    static func healthEndpoint(baseURL: URL = productionBaseURL) -> URL {
        baseURL.appendingPathComponent("health")
    }
}

struct ProxyRequestExecutor {
    typealias ResponseRetryDecision = (HTTPURLResponse, Data) -> Bool

    let session: URLSession
    let retryDelays: [TimeInterval]

    func data(
        for request: URLRequest,
        category: String,
        onRetry: (@Sendable (Int) -> Void)? = nil,
        shouldRetryResponse: ResponseRetryDecision
    ) async throws -> (Data, URLResponse) {
        var retryIndex = 0

        while true {
            try Task.checkCancellation()

            do {
                let (data, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse,
                   retryIndex < retryDelays.count,
                   shouldRetryResponse(http, data) {
                    onRetry?(retryIndex + 1)
                    try await waitBeforeRetry(category: category, retryIndex: retryIndex, reason: "HTTP \(http.statusCode)")
                    retryIndex += 1
                    continue
                }
                return (data, response)
            } catch {
                guard retryIndex < retryDelays.count, Self.isTransientNetworkError(error) else {
                    throw error
                }
                onRetry?(retryIndex + 1)
                try await waitBeforeRetry(category: category, retryIndex: retryIndex, reason: "transient network failure")
                retryIndex += 1
            }
        }
    }

    private func waitBeforeRetry(category: String, retryIndex: Int, reason: String) async throws {
        let delay = retryDelays[retryIndex]
        ProxyDiagnostics.log(
            category,
            "Retrying after \(reason) in \(Self.formatted(delay))s (retry \(retryIndex + 1)/\(retryDelays.count))."
        )
        try Task.checkCancellation()
        guard delay > 0 else { return }
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }

    static func isTransientHTTPStatus(_ statusCode: Int) -> Bool {
        statusCode == 408 || statusCode == 502 || statusCode == 503 || statusCode == 504
    }

    private static func isTransientNetworkError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut,
             .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed,
             .networkConnectionLost,
             .notConnectedToInternet,
             .resourceUnavailable:
            return true
        default:
            return false
        }
    }

    private static func formatted(_ seconds: TimeInterval) -> String {
        seconds.rounded() == seconds ? String(Int(seconds)) : String(format: "%.1f", seconds)
    }
}

enum ProxyOperationDeadline {
    static func run<Value: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        let race = ProxyOperationRace<Value>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                race.install(continuation: continuation)

                let operationTask = Task {
                    do {
                        race.resolve(.success(try await operation()))
                    } catch {
                        race.resolve(.failure(error))
                    }
                }
                let timeoutTask = Task {
                    do {
                        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                        race.resolve(.failure(URLError(.timedOut)))
                    } catch {
                        // The operation won the race or the caller cancelled it.
                    }
                }
                race.install(operationTask: operationTask, timeoutTask: timeoutTask)
            }
        } onCancel: {
            race.resolve(.failure(CancellationError()))
        }
    }
}

private final class ProxyOperationRace<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var result: Result<Value, Error>?
    private var operationTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?

    func install(continuation: CheckedContinuation<Value, Error>) {
        lock.lock()
        if let result {
            lock.unlock()
            continuation.resume(with: result)
            return
        }
        self.continuation = continuation
        lock.unlock()
    }

    func install(operationTask: Task<Void, Never>, timeoutTask: Task<Void, Never>) {
        lock.lock()
        if result != nil {
            lock.unlock()
            operationTask.cancel()
            timeoutTask.cancel()
            return
        }
        self.operationTask = operationTask
        self.timeoutTask = timeoutTask
        lock.unlock()
    }

    func resolve(_ result: Result<Value, Error>) {
        lock.lock()
        guard self.result == nil else {
            lock.unlock()
            return
        }
        self.result = result
        let continuation = self.continuation
        self.continuation = nil
        let operationTask = self.operationTask
        let timeoutTask = self.timeoutTask
        lock.unlock()

        operationTask?.cancel()
        timeoutTask?.cancel()
        continuation?.resume(with: result)
    }
}

final class ProxyFactGenerator: PlaceFactGenerating, @unchecked Sendable {
    // Contract: see /Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml.
    typealias ProxyTokenProvider = () -> String?
    typealias DeviceIdProvider = () -> String?
    typealias CredentialInvalidator = () -> Void
    typealias CredentialRefresher = () async throws -> Void

    private let proxyTokenProvider: ProxyTokenProvider
    private let deviceIdProvider: DeviceIdProvider
    private let credentialInvalidator: CredentialInvalidator
    private let credentialRefresher: CredentialRefresher
    private let requestExecutor: ProxyRequestExecutor
    private let endpoint: URL
    private let operationTimeoutSeconds: TimeInterval
    private let conversationMutex = AsyncMutex()
    private var linkedRideSessionID: UUID?
    private var previousResponseID: String?

    init(
        proxyTokenProvider: @escaping ProxyTokenProvider = { KeychainCredentialLoader.loadRideHorizonProxyToken() },
        deviceIdProvider: @escaping DeviceIdProvider = { KeychainCredentialLoader.loadRideHorizonDeviceId() },
        credentialInvalidator: @escaping CredentialInvalidator = { ProxyCredentialLifecycle.invalidate() },
        credentialRefresher: @escaping CredentialRefresher = {
            try await ProxySessionCoordinator.shared.provisionSessionIfNeeded()
        },
        session: URLSession = .shared,
        baseURL: URL = FactProxyContract.productionBaseURL,
        endpoint: URL? = nil,
        retryDelays: [TimeInterval] = FactProxyContract.retryDelaysSeconds,
        operationTimeoutSeconds: TimeInterval = FactProxyContract.iosTimeoutSeconds
    ) {
        self.proxyTokenProvider = proxyTokenProvider
        self.deviceIdProvider = deviceIdProvider
        self.credentialInvalidator = credentialInvalidator
        self.credentialRefresher = credentialRefresher
        self.requestExecutor = ProxyRequestExecutor(session: session, retryDelays: retryDelays)
        self.endpoint = endpoint ?? FactProxyContract.factEndpoint(baseURL: baseURL)
        self.operationTimeoutSeconds = operationTimeoutSeconds
    }

    func fact(for request: PlaceFactRequest) async throws -> String {
        try await generatedFact(for: request).text
    }

    func generatedFact(for request: PlaceFactRequest) async throws -> GeneratedPlaceFact {
        await conversationMutex.acquire()
        do {
            try Task.checkCancellation()
            if let rideSessionID = request.rideSessionID,
               rideSessionID != linkedRideSessionID {
                linkedRideSessionID = rideSessionID
                previousResponseID = nil
            }
            let requestPreviousResponseID = previousResponseID
            let response = try await ProxyOperationDeadline.run(seconds: operationTimeoutSeconds) {
                try await self.fact(
                    for: request,
                    previousResponseID: requestPreviousResponseID,
                    retryAfterAuthenticationFailure: true
                )
            }
            if let rideSessionID = request.rideSessionID {
                guard let responseID = response.responseID else {
                    throw PlaceFactError.invalidResponse
                }
                linkedRideSessionID = rideSessionID
                previousResponseID = responseID
            }
            await conversationMutex.release()
            return response.generatedFact
        } catch {
            if request.rideSessionID == linkedRideSessionID {
                linkedRideSessionID = nil
                previousResponseID = nil
            }
            await conversationMutex.release()
            throw error
        }
    }

    private func fact(
        for request: PlaceFactRequest,
        previousResponseID: String?,
        retryAfterAuthenticationFailure: Bool
    ) async throws -> ProxyFactResult {
        var proxyToken = proxyTokenProvider()
        if proxyToken?.isEmpty != false {
            ProxyDiagnostics.log("Proxy", "Proxy session missing; provisioning automatically.")
            try await credentialRefresher()
            proxyToken = proxyTokenProvider()
        }
        guard let proxyToken, !proxyToken.isEmpty else {
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
        if let rideSessionID = request.rideSessionID {
            urlRequest.setValue(
                rideSessionID.uuidString.lowercased(),
                forHTTPHeaderField: FactProxyContract.rideIdHeader
            )
            if let previousResponseID {
                urlRequest.setValue(
                    previousResponseID,
                    forHTTPHeaderField: FactProxyContract.previousResponseIdHeader
                )
            }
        }
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
            (data, response) = try await requestExecutor.data(
                for: urlRequest,
                category: "Proxy",
                shouldRetryResponse: { http, _ in
                    ProxyRequestExecutor.isTransientHTTPStatus(http.statusCode)
                }
            )
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
                if retryAfterAuthenticationFailure {
                    ProxyDiagnostics.log("Auth", "Proxy session rejected; reprovisioning and retrying once.")
                    try await credentialRefresher()
                    return try await fact(
                        for: request,
                        previousResponseID: previousResponseID,
                        retryAfterAuthenticationFailure: false
                    )
                }
            }
            throw PlaceFactError.httpError(http.statusCode)
        }

        let decoded: FactProxyResponse
        do {
            decoded = try JSONDecoder().decode(FactProxyResponse.self, from: data)
        } catch {
            ProxyDiagnostics.log("Proxy", "Decode error: \(error.localizedDescription)")
            throw PlaceFactError.invalidResponse
        }

        guard let sanitized = FactPhraseBuilder.sanitize(decoded.fact, mode: request.factMode) else {
            ProxyDiagnostics.log("Proxy", "Proxy fact failed local sanitization.")
            throw PlaceFactError.invalidResponse
        }
        var seenSourceURLs = Set<String>()
        guard decoded.sources.count <= PlaceFactSource.maximumCount else {
            throw PlaceFactError.invalidResponse
        }
        var sources: [PlaceFactSource] = []
        for rawSource in decoded.sources {
            guard let source = PlaceFactSource.validated(title: rawSource.title, url: rawSource.url),
                  seenSourceURLs.insert(source.url.absoluteString).inserted else {
                throw PlaceFactError.invalidResponse
            }
            sources.append(source)
        }
        ProxyDiagnostics.log("Proxy", "Fact accepted: \(sanitized)")
        let responseID = request.rideSessionID == nil
            ? nil
            : http.value(forHTTPHeaderField: FactProxyContract.responseIdHeader)
        return ProxyFactResult(
            generatedFact: GeneratedPlaceFact(text: sanitized, sources: sources),
            responseID: responseID
        )
    }

    func endRideConversation(_ rideSessionID: UUID) async {
        await conversationMutex.acquire()
        if linkedRideSessionID == rideSessionID {
            linkedRideSessionID = nil
            previousResponseID = nil
        }
        await conversationMutex.release()
    }
}

private struct ProxyFactResult: Sendable {
    let generatedFact: GeneratedPlaceFact
    let responseID: String?
}

private actor AsyncMutex {
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if !isLocked {
            isLocked = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if waiters.isEmpty {
            isLocked = false
        } else {
            let next = waiters.removeFirst()
            next.resume()
        }
    }
}

struct ProxySpeechGenerator {
    typealias ProxyTokenProvider = () -> String?
    typealias DeviceIdProvider = () -> String?
    typealias CredentialInvalidator = () -> Void
    typealias CredentialRefresher = () async throws -> Void

    private let proxyTokenProvider: ProxyTokenProvider
    private let deviceIdProvider: DeviceIdProvider
    private let credentialInvalidator: CredentialInvalidator
    private let credentialRefresher: CredentialRefresher
    private let requestExecutor: ProxyRequestExecutor
    private let endpoint: URL
    private static let maxSpeechTextLength = 1400

    init(
        proxyTokenProvider: @escaping ProxyTokenProvider = { KeychainCredentialLoader.loadRideHorizonProxyToken() },
        deviceIdProvider: @escaping DeviceIdProvider = { KeychainCredentialLoader.loadRideHorizonDeviceId() },
        credentialInvalidator: @escaping CredentialInvalidator = { ProxyCredentialLifecycle.invalidate() },
        credentialRefresher: @escaping CredentialRefresher = {
            try await ProxySessionCoordinator.shared.provisionSessionIfNeeded()
        },
        session: URLSession = .shared,
        baseURL: URL = FactProxyContract.productionBaseURL,
        endpoint: URL? = nil,
        retryDelays: [TimeInterval] = FactProxyContract.retryDelaysSeconds
    ) {
        self.proxyTokenProvider = proxyTokenProvider
        self.deviceIdProvider = deviceIdProvider
        self.credentialInvalidator = credentialInvalidator
        self.credentialRefresher = credentialRefresher
        self.requestExecutor = ProxyRequestExecutor(session: session, retryDelays: retryDelays)
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
        return try await ProxyOperationDeadline.run(seconds: FactProxyContract.iosTimeoutSeconds) {
            try await speechAudioChunk(for: boundedText)
        }
    }

    func speechAudios(for text: String) async throws -> [Data] {
        try await speechAudios(for: text, onRetry: { _ in })
    }

    func speechAudios(
        for text: String,
        onRetry: @escaping @Sendable (Int) -> Void
    ) async throws -> [Data] {
        try await ProxyOperationDeadline.run(seconds: FactProxyContract.iosTimeoutSeconds) {
            let chunks = Self.chunkSpeechText(Self.normalizedSpeechText(text))
            if chunks.count > 1 {
                ProxyDiagnostics.log("Speech", "Splitting speech text into \(chunks.count) chunk(s) for proxy requests.")
            }

            var responses: [Data] = []
            for chunk in chunks {
                try Task.checkCancellation()
                responses.append(try await speechAudioChunk(for: chunk, onRetry: onRetry))
            }
            return responses
        }
    }

    private func speechAudioChunk(for text: String) async throws -> Data {
        try await speechAudioChunk(for: text, retryAfterAuthenticationFailure: true, onRetry: { _ in })
    }

    private func speechAudioChunk(
        for text: String,
        onRetry: @escaping @Sendable (Int) -> Void
    ) async throws -> Data {
        try await speechAudioChunk(
            for: text,
            retryAfterAuthenticationFailure: true,
            onRetry: onRetry
        )
    }

    private func speechAudioChunk(
        for text: String,
        retryAfterAuthenticationFailure: Bool,
        onRetry: @escaping @Sendable (Int) -> Void
    ) async throws -> Data {
        var proxyToken = proxyTokenProvider()
        if proxyToken?.isEmpty != false {
            ProxyDiagnostics.log("Speech", "Proxy session missing; provisioning automatically.")
            try await credentialRefresher()
            proxyToken = proxyTokenProvider()
        }
        guard let proxyToken, !proxyToken.isEmpty else {
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
            (data, response) = try await requestExecutor.data(
                for: urlRequest,
                category: "Speech",
                onRetry: onRetry,
                shouldRetryResponse: { http, data in
                    guard ProxyRequestExecutor.isTransientHTTPStatus(http.statusCode) else {
                        return false
                    }
                    guard http.statusCode == 502,
                          let proxyError = try? JSONDecoder().decode(SpeechProxyErrorResponse.self, from: data) else {
                        return true
                    }
                    return proxyError.code == .upstreamFailure
                }
            )
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
                if retryAfterAuthenticationFailure {
                    ProxyDiagnostics.log("Auth", "Speech session rejected; reprovisioning and retrying once.")
                    onRetry(1)
                    try await credentialRefresher()
                    return try await speechAudioChunk(
                        for: text,
                        retryAfterAuthenticationFailure: false,
                        onRetry: onRetry
                    )
                }
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

protocol RetryReportingProxySpeechGenerating: ProxySpeechGenerating {
    func speechAudios(
        for text: String,
        onRetry: @escaping @Sendable (Int) -> Void
    ) async throws -> [Data]
}

extension ProxySpeechGenerator: ProxySpeechGenerating {}
extension ProxySpeechGenerator: RetryReportingProxySpeechGenerating {}

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
    let previousRideSummaries: [String]?

    init(from request: PlaceFactRequest) {
        self.boundary = request.boundary.factLabel
        self.placeName = request.placeName
        self.factMode = request.factMode.rawValue
        self.countryContext = request.countryContext
        self.placeHierarchy = request.placeHierarchy
        self.riderContext = request.riderContext
        self.previousRideSummaries = request.previousRideSummaries.isEmpty
            ? nil
            : request.previousRideSummaries
    }
}

private struct FactProxyResponse: Decodable {
    let fact: String
    let sources: [Source]

    struct Source: Decodable {
        let title: String
        let url: String
    }
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
