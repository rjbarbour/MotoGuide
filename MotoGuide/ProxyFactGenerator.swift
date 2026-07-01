import Foundation

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
            throw PlaceFactError.missingProxyToken
        }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = FactProxyContract.iosTimeoutSeconds
        urlRequest.setValue("Bearer \(proxyToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(FactProxyRequest(from: request))

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw PlaceFactError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw PlaceFactError.httpError(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(FactProxyResponse.self, from: data)
        guard let sanitized = FactPhraseBuilder.sanitize(decoded.fact) else {
            throw PlaceFactError.invalidResponse
        }
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

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let body = String(data: data, encoding: .utf8) else {
                return false
            }
            return body.trimmingCharacters(in: .whitespacesAndNewlines) == "ok"
        } catch {
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
