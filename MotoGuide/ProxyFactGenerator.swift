import Foundation

struct ProxyFactGenerator: PlaceFactGenerating {
    // Contract: see /Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml.
    typealias ProxyTokenProvider = () -> String?

    private let proxyTokenProvider: ProxyTokenProvider
    private let session: URLSession
    private let endpoint: URL

    init(
        proxyTokenProvider: @escaping ProxyTokenProvider = { KeychainCredentialLoader.loadMotoGuideProxyToken() },
        session: URLSession = .shared,
        endpoint: URL = URL(string: "https://motoguide-fact-proxy.fly.dev/v1/fact")!
    ) {
        self.proxyTokenProvider = proxyTokenProvider
        self.session = session
        self.endpoint = endpoint
    }

    func fact(for request: PlaceFactRequest) async throws -> String {
        guard let proxyToken = proxyTokenProvider(), !proxyToken.isEmpty else {
            throw PlaceFactError.missingProxyToken
        }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
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
