import XCTest
@testable import MotoGuide

final class MockPlaceFactGenerator: PlaceFactGenerating {
    var factsByCacheKey: [String: String] = [:]
    var callCount = 0
    var delayNanoseconds: UInt64 = 0
    var shouldThrow = false

    func fact(for request: PlaceFactRequest) async throws -> String {
        callCount += 1
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if shouldThrow {
            throw PlaceFactError.invalidResponse
        }
        if let fact = factsByCacheKey[request.cacheKey] {
            return fact
        }
        throw PlaceFactError.invalidResponse
    }
}

final class FactPhraseBuilderTests: XCTestCase {
    func testUtteranceAppendsSanitizedFact() {
        XCTAssertEqual(
            FactPhraseBuilder.utterance(
                basePhrase: "You are in Stonehouse, Gloucestershire",
                fact: "Known for its steep streets and markets."
            ),
            "You are in Stonehouse, Gloucestershire. Known for its steep streets and markets."
        )
    }

    func testUtteranceReturnsBaseWhenFactMissing() {
        XCTAssertEqual(
            FactPhraseBuilder.utterance(basePhrase: "Welcome to Wales. You are in Stroud, Gloucestershire", fact: nil),
            "Welcome to Wales. You are in Stroud, Gloucestershire"
        )
    }

    func testSanitizeRejectsQuestionsAndInvitations() {
        XCTAssertNil(FactPhraseBuilder.sanitize("Should you visit?"))
        XCTAssertNil(FactPhraseBuilder.sanitize("You should visit the castle."))
    }

    func testSanitizeTruncatesLongFacts() {
        let long = String(repeating: "a", count: 150)
        let sanitized = FactPhraseBuilder.sanitize(long)
        XCTAssertEqual(sanitized?.count, 120)
    }

    func testLongFactsUseLongerBoundedSanitizer() {
        let long = String(repeating: "a", count: 300)
        let sanitized = FactPhraseBuilder.sanitize(long, mode: .longFacts)
        XCTAssertEqual(sanitized?.count, 280)
    }
}

final class PlaceFactCacheTests: XCTestCase {
    func testCacheStoresAndReturnsFacts() {
        let cache = PlaceFactCache(loadPersisted: false)
        let request = PlaceFactRequest(boundary: .town, placeName: "Stroud", countryContext: "United Kingdom")

        cache.store("A market town.", forKey: request.cacheKey)
        XCTAssertEqual(cache.fact(forKey: request.cacheKey), "A market town.")
    }

    func testCacheKeyNormalizesPlaceName() {
        let first = PlaceFactRequest(boundary: .county, placeName: "Gloucestershire", countryContext: nil)
        let second = PlaceFactRequest(boundary: .county, placeName: " gloucestershire ", countryContext: nil)
        XCTAssertEqual(first.cacheKey, second.cacheKey)
    }

    func testCacheKeyIncludesCountryContext() {
        let uk = PlaceFactRequest(boundary: .town, placeName: "Newport", countryContext: "United Kingdom")
        let us = PlaceFactRequest(boundary: .town, placeName: "Newport", countryContext: "United States")

        XCTAssertNotEqual(uk.cacheKey, us.cacheKey)
    }

    func testCacheKeyIncludesFactMode() {
        let short = PlaceFactRequest(boundary: .town, placeName: "Stroud", factMode: .shortFacts, countryContext: "United Kingdom")
        let long = PlaceFactRequest(boundary: .town, placeName: "Stroud", factMode: .longFacts, countryContext: "United Kingdom")

        XCTAssertNotEqual(short.cacheKey, long.cacheKey)
    }

    func testCacheKeyIncludesPlaceHierarchy() {
        let first = PlaceFactRequest(
            boundary: .town,
            placeName: "Newport",
            factMode: .shortFacts,
            countryContext: "United Kingdom",
            placeHierarchy: PlaceHierarchy(
                street: "High Street",
                town: "Newport",
                county: "Shropshire",
                region: "England",
                country: "United Kingdom"
            )
        )

        let second = PlaceFactRequest(
            boundary: .town,
            placeName: "Newport",
            factMode: .shortFacts,
            countryContext: "United Kingdom",
            placeHierarchy: PlaceHierarchy(
                street: "North Road",
                town: "Newport",
                county: "Pembrokeshire",
                region: "Wales",
                country: "United Kingdom"
            )
        )

        XCTAssertNotEqual(first.cacheKey, second.cacheKey)
    }
}

final class CachedPlaceFactGeneratorTests: XCTestCase {
    func testUsesCacheOnSecondLookup() async throws {
        let mock = MockPlaceFactGenerator()
        let cache = PlaceFactCache(loadPersisted: false)
        let generator = CachedPlaceFactGenerator(generator: mock, cache: cache)
        let request = PlaceFactRequest(boundary: .town, placeName: "Stroud", countryContext: "United Kingdom")
        mock.factsByCacheKey[request.cacheKey] = "A steep Cotswold town."

        let first = try await generator.fact(for: request)
        let second = try await generator.fact(for: request)

        XCTAssertEqual(first, "A steep Cotswold town.")
        XCTAssertEqual(second, "A steep Cotswold town.")
        XCTAssertEqual(mock.callCount, 1)
    }
}

final class ProxyFactGeneratorTests: XCTestCase {
    // Contract coverage: see /Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml.
    private let endpoint = URL(string: "https://proxy.test/v1/fact")!

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testPostsFactRequestToProxyWithBearerToken() async throws {
        let endpoint = self.endpoint
        let request = PlaceFactRequest(
            boundary: .town,
            placeName: "Stroud",
            countryContext: "United Kingdom"
        )

        MockURLProtocol.requestHandler = { urlRequest in
            XCTAssertEqual(urlRequest.url, endpoint)
            XCTAssertEqual(urlRequest.httpMethod, "POST")
            XCTAssertEqual(urlRequest.timeoutInterval, FactProxyContract.iosTimeoutSeconds)
            XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Authorization"), "Bearer proxy-token")
            XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try XCTUnwrap(urlRequest.httpBody)
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            XCTAssertEqual(json?["boundary"] as? String, "town")
            XCTAssertEqual(json?["placeName"] as? String, "Stroud")
            XCTAssertEqual(json?["factMode"] as? String, "shortFacts")
            XCTAssertEqual(json?["countryContext"] as? String, "United Kingdom")
            let hierarchy = try XCTUnwrap(json?["placeHierarchy"] as? [String: Any])
            XCTAssertNil(hierarchy["street"] as? String)
            XCTAssertNil(hierarchy["town"] as? String)
            XCTAssertNil(hierarchy["county"] as? String)
            XCTAssertNil(hierarchy["region"] as? String)
            XCTAssertNil(hierarchy["country"] as? String)

            let response = HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(#"{"fact":"Known for its wool trade."}"#.utf8))
        }

        let generator = ProxyFactGenerator(
            proxyTokenProvider: { "proxy-token" },
            session: makeMockSession(),
            endpoint: endpoint
        )

        let fact = try await generator.fact(for: request)

        XCTAssertEqual(fact, "Known for its wool trade.")
    }

    func testPostsLongFactModeToProxy() async throws {
        let endpoint = self.endpoint
        let request = PlaceFactRequest(
            boundary: .county,
            placeName: "Gloucestershire",
            factMode: .longFacts,
            countryContext: "United Kingdom",
            placeHierarchy: PlaceHierarchy(
                street: "B4066",
                town: "Nailsworth",
                county: "Gloucestershire",
                region: "England",
                country: "United Kingdom"
            )
        )

        MockURLProtocol.requestHandler = { urlRequest in
            let body = try XCTUnwrap(urlRequest.httpBody)
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            XCTAssertEqual(json?["factMode"] as? String, "longFacts")
            let hierarchy = try XCTUnwrap(json?["placeHierarchy"] as? [String: Any])
            XCTAssertEqual(hierarchy["street"] as? String, "B4066")
            XCTAssertEqual(hierarchy["town"] as? String, "Nailsworth")
            XCTAssertEqual(hierarchy["county"] as? String, "Gloucestershire")
            XCTAssertEqual(hierarchy["region"] as? String, "England")
            XCTAssertEqual(hierarchy["country"] as? String, "United Kingdom")

            let response = HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(#"{"fact":"A longer but still bounded place blurb."}"#.utf8))
        }

        let generator = ProxyFactGenerator(
            proxyTokenProvider: { "proxy-token" },
            session: makeMockSession(),
            endpoint: endpoint
        )

        let fact = try await generator.fact(for: request)

        XCTAssertEqual(fact, "A longer but still bounded place blurb.")
    }

    func testDefaultEndpointUsesProductionFlyProxyFromContract() async throws {
        let expectedEndpoint = URL(string: "https://motoguide-fact-proxy.fly.dev/v1/fact")!

        MockURLProtocol.requestHandler = { urlRequest in
            XCTAssertEqual(urlRequest.url, expectedEndpoint)

            let response = HTTPURLResponse(
                url: expectedEndpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(#"{"fact":"Known for its wool trade."}"#.utf8))
        }

        let generator = ProxyFactGenerator(
            proxyTokenProvider: { "proxy-token" },
            session: makeMockSession()
        )

        let fact = try await generator.fact(for: PlaceFactRequest(boundary: .town, placeName: "Stroud", countryContext: nil))

        XCTAssertEqual(fact, "Known for its wool trade.")
    }

    func testCanUseLocalDevelopmentBaseURLFromContract() async throws {
        let expectedEndpoint = URL(string: "http://127.0.0.1:3000/v1/fact")!

        MockURLProtocol.requestHandler = { urlRequest in
            XCTAssertEqual(urlRequest.url, expectedEndpoint)

            let response = HTTPURLResponse(
                url: expectedEndpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(#"{"fact":"Known for its wool trade."}"#.utf8))
        }

        let generator = ProxyFactGenerator(
            proxyTokenProvider: { "proxy-token" },
            session: makeMockSession(),
            baseURL: FactProxyContract.localDevelopmentBaseURL
        )

        let fact = try await generator.fact(for: PlaceFactRequest(boundary: .town, placeName: "Stroud", countryContext: nil))

        XCTAssertEqual(fact, "Known for its wool trade.")
    }

    func testMissingProxyTokenThrowsBeforeNetworkRequest() async {
        let endpoint = self.endpoint
        MockURLProtocol.requestHandler = { _ in
            XCTFail("No network request should be made without a proxy token.")
            let response = HTTPURLResponse(
                url: endpoint,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let generator = ProxyFactGenerator(
            proxyTokenProvider: { nil },
            session: makeMockSession(),
            endpoint: endpoint
        )

        do {
            _ = try await generator.fact(for: PlaceFactRequest(boundary: .town, placeName: "Stroud", countryContext: nil))
            XCTFail("Expected missing proxy token error.")
        } catch let error as PlaceFactError {
            XCTAssertEqual(error, .missingProxyToken)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testProxyHttpErrorIsSurfaced() async {
        let endpoint = self.endpoint
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: endpoint,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let generator = ProxyFactGenerator(
            proxyTokenProvider: { "wrong-token" },
            session: makeMockSession(),
            endpoint: endpoint
        )

        do {
            _ = try await generator.fact(for: PlaceFactRequest(boundary: .town, placeName: "Stroud", countryContext: nil))
            XCTFail("Expected HTTP error.")
        } catch let error as PlaceFactError {
            XCTAssertEqual(error, .httpError(401))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeMockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

final class ProxyHealthCheckerTests: XCTestCase {
    private let endpoint = URL(string: "https://proxy.test/health")!

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testHealthCheckUsesPublicHealthEndpointWithoutBearerToken() async {
        let endpoint = self.endpoint

        MockURLProtocol.requestHandler = { urlRequest in
            XCTAssertEqual(urlRequest.url, endpoint)
            XCTAssertEqual(urlRequest.httpMethod, "GET")
            XCTAssertEqual(urlRequest.timeoutInterval, FactProxyContract.iosTimeoutSeconds)
            XCTAssertNil(urlRequest.value(forHTTPHeaderField: "Authorization"))

            let response = HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/plain"]
            )!
            return (response, Data("ok\n".utf8))
        }

        let checker = ProxyHealthChecker(session: makeMockSession(), endpoint: endpoint)
        let healthy = await checker.isHealthy()

        XCTAssertTrue(healthy)
    }

    func testHealthCheckReturnsFalseForNonOkBody() async {
        let endpoint = self.endpoint

        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/plain"]
            )!
            return (response, Data("starting".utf8))
        }

        let checker = ProxyHealthChecker(session: makeMockSession(), endpoint: endpoint)
        let healthy = await checker.isHealthy()

        XCTAssertFalse(healthy)
    }

    private func makeMockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: PlaceFactError.invalidResponse)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class PlaceFactFetcherTests: XCTestCase {
    func testTimeoutReturnsNilWhenGeneratorIsSlow() async {
        let mock = MockPlaceFactGenerator()
        mock.delayNanoseconds = 5_000_000_000
        let request = PlaceFactRequest(boundary: .town, placeName: "Stroud", countryContext: nil)
        mock.factsByCacheKey[request.cacheKey] = "Too late."

        let fact = await PlaceFactFetcher.fact(for: request, using: mock, timeout: 0.2)

        XCTAssertNil(fact)
    }

    func testReturnsFactWhenGeneratorIsFast() async {
        let mock = MockPlaceFactGenerator()
        let request = PlaceFactRequest(boundary: .town, placeName: "Stroud", countryContext: nil)
        mock.factsByCacheKey[request.cacheKey] = "A market town below the escarpment."

        let fact = await PlaceFactFetcher.fact(for: request, using: mock, timeout: 2)

        XCTAssertEqual(fact, "A market town below the escarpment.")
    }
}

final class ShortFactsAnnouncementTests: XCTestCase {
    private let gloucester = Address(
        street: "High Street",
        town: "Stroud",
        county: "Gloucestershire",
        administrativeArea: "England",
        country: "United Kingdom"
    )

    private let stonehouse = Address(
        street: "Bristol Road",
        town: "Stonehouse",
        county: "Gloucestershire",
        administrativeArea: "England",
        country: "United Kingdom"
    )

    private let walesTown = Address(
        street: "High Street",
        town: "Chepstow",
        county: "Monmouthshire",
        administrativeArea: "Wales",
        country: "United Kingdom"
    )

    func testShortFactsBasePhraseMatchesNatural() {
        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: stonehouse,
            settings: .ridingDefaults,
            mode: .shortFacts
        )

        XCTAssertEqual(plan?.text, "You are in Stonehouse, Gloucestershire")
        XCTAssertEqual(plan?.boundary, .town)
    }

    func testShortFactsWelcomeUsesHighestPriorityBoundaryForFactRequest() {
        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: walesTown,
            settings: .ridingDefaults,
            mode: .shortFacts
        )
        let request = AnnouncementPolicy.factRequest(for: plan!, address: walesTown, mode: .shortFacts)

        XCTAssertEqual(plan?.text, "Welcome to Wales. You are in Chepstow, Monmouthshire")
        XCTAssertEqual(request.boundary, .nation)
        XCTAssertEqual(request.placeName, "Wales")
        XCTAssertEqual(request.factMode, .shortFacts)
        XCTAssertEqual(request.placeHierarchy.region, "Wales")
    }

    func testLongFactsWelcomeUsesLongFactModeForFactRequest() {
        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: walesTown,
            settings: .ridingDefaults,
            mode: .longFacts
        )
        let request = AnnouncementPolicy.factRequest(for: plan!, address: walesTown, mode: .longFacts)

        XCTAssertEqual(plan?.text, "Welcome to Wales. You are in Chepstow, Monmouthshire")
        XCTAssertEqual(request.boundary, .nation)
        XCTAssertEqual(request.factMode, .longFacts)
        XCTAssertEqual(request.placeName, "Wales")
    }

    func testShortFactsUtteranceIncludesGeneratedFact() {
        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: stonehouse,
            settings: .ridingDefaults,
            mode: .shortFacts
        )!

        let spoken = FactPhraseBuilder.utterance(
            basePhrase: plan.text,
            fact: "A canal town beside the Stroudwater Navigation."
        )

        XCTAssertEqual(
            spoken,
            "You are in Stonehouse, Gloucestershire. A canal town beside the Stroudwater Navigation."
        )
    }

    func testNaturalModeDoesNotUseFactBuilder() {
        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: stonehouse,
            settings: .ridingDefaults,
            mode: .natural
        )

        XCTAssertEqual(plan?.text, "You are in Stonehouse, Gloucestershire")
    }

    func testQuietModeProducesNoPlan() {
        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: stonehouse,
            settings: .ridingDefaults,
            mode: .quiet
        )

        XCTAssertNil(plan)
    }
}
