import XCTest
@testable import RideHorizon

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
        let long = String(repeating: "a", count: 1_200)
        let sanitized = FactPhraseBuilder.sanitize(long)
        XCTAssertEqual(sanitized?.count, 1_100)
    }

    func testLongFactsUseLongerBoundedSanitizer() {
        let long = String(repeating: "a", count: 1_600)
        let sanitized = FactPhraseBuilder.sanitize(long, mode: .longFacts)
        XCTAssertEqual(sanitized?.count, 1500)
    }
}

final class PlaceFactCacheTests: XCTestCase {
    func testCacheStoresAndReturnsFacts() {
        let cache = PlaceFactCache(loadPersisted: false)
        let request = PlaceFactRequest(boundary: .town, placeName: "Stroud", countryContext: "United Kingdom")

        cache.store("A market town.", forKey: request.cacheKey)
        XCTAssertEqual(cache.fact(forKey: request.cacheKey), "A market town.")
    }

    func testCacheClearRemovesStoredFacts() {
        let cache = PlaceFactCache(loadPersisted: false)
        let request = PlaceFactRequest(boundary: .town, placeName: "Stroud", countryContext: "United Kingdom")
        cache.store("A market town.", forKey: request.cacheKey)

        cache.clear()

        XCTAssertNil(cache.fact(forKey: request.cacheKey))
    }

    func testCacheExpiresFactsAfterThirtyDays() {
        var now = Date(timeIntervalSince1970: 1_000)
        let cache = PlaceFactCache(loadPersisted: false, now: { now })
        let request = PlaceFactRequest(boundary: .town, placeName: "Stroud", countryContext: "United Kingdom")
        cache.store("A market town.", forKey: request.cacheKey)

        now = now.addingTimeInterval(30 * 24 * 60 * 60 + 1)

        XCTAssertNil(cache.fact(forKey: request.cacheKey))
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
    func testProductionProxyUsesStableRideHorizonEdge() {
        XCTAssertEqual(
            FactProxyContract.productionBaseURL,
            URL(string: "https://ridehorizon.digitalmercenaries.ai")
        )
    }

    // Contract coverage: see /Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml.
    private let endpoint = URL(string: "https://proxy.test/v1/fact")!

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testRiderNetworkBudgetOutlastsProxyUpstreamDeadline() {
        let proxyUpstreamDeadline: TimeInterval = 30

        XCTAssertGreaterThan(FactProxyContract.factTimeoutSeconds, proxyUpstreamDeadline)
        XCTAssertGreaterThan(FactProxyContract.speechTimeoutSeconds, proxyUpstreamDeadline)
        XCTAssertEqual(FactProxyContract.iosTimeoutSeconds, 60)
        XCTAssertLessThan(FactProxyContract.factTimeoutSeconds, FactProxyContract.iosTimeoutSeconds)
        XCTAssertLessThan(FactProxyContract.speechTimeoutSeconds, FactProxyContract.iosTimeoutSeconds)
        XCTAssertEqual(FactProxyContract.retryDelaysSeconds, [3, 10])
        XCTAssertEqual(FactProxyContract.sessionTimeoutSeconds, 12)
        XCTAssertEqual(FactProxyContract.sessionOperationTimeoutSeconds, 30)
    }

    func testOperationDeadlineCancelsSlowWorkAtItsWallClockLimit() async {
        let started = Date()

        do {
            _ = try await ProxyOperationDeadline.run(seconds: 0.05) {
                try await Task.sleep(nanoseconds: 5_000_000_000)
                return "too late"
            }
            XCTFail("Expected the operation deadline to expire.")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .timedOut)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertLessThan(Date().timeIntervalSince(started), 0.5)
    }

    func testOperationDeadlineReturnsPromptlyWhenWorkIgnoresCancellation() async {
        let started = Date()

        do {
            _ = try await ProxyOperationDeadline.run(seconds: 0.05) {
                await withCheckedContinuation { continuation in
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                        continuation.resume(returning: "too late")
                    }
                }
            }
            XCTFail("Expected the operation deadline to expire.")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .timedOut)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertLessThan(Date().timeIntervalSince(started), 0.2)
    }

    func testFactDeadlineReturnsPromptlyWhenSessionProvisioningIgnoresCancellation() async {
        let started = Date()
        let generator = ProxyFactGenerator(
            proxyTokenProvider: { nil },
            credentialRefresher: {
                await withCheckedContinuation { continuation in
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                        continuation.resume()
                    }
                }
            },
            session: makeMockSession(),
            endpoint: endpoint,
            retryDelays: [],
            operationTimeoutSeconds: 0.05
        )

        do {
            _ = try await generator.fact(
                for: PlaceFactRequest(boundary: .town, placeName: "Stroud", countryContext: nil)
            )
            XCTFail("Expected the overall fact deadline to expire.")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .timedOut)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertLessThan(Date().timeIntervalSince(started), 0.2)
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
            XCTAssertEqual(urlRequest.timeoutInterval, FactProxyContract.factTimeoutSeconds)
            XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Authorization"), "Bearer proxy-token")
            XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertNil(urlRequest.value(forHTTPHeaderField: "X-RideHorizon-Device-Id"))

            let body = try self.requestBodyData(from: urlRequest)
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
            deviceIdProvider: { nil },
            session: makeMockSession(),
            endpoint: endpoint
        )

        let fact = try await generator.fact(for: request)

        XCTAssertEqual(fact, "Known for its wool trade.")
    }

    func testPostsDeviceIdHeaderWhenConfigured() async throws {
        let endpoint = self.endpoint
        let request = PlaceFactRequest(
            boundary: .town,
            placeName: "Stroud",
            countryContext: "United Kingdom"
        )

        MockURLProtocol.requestHandler = { urlRequest in
            XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "X-RideHorizon-Device-Id"), "helmet-001")

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
            deviceIdProvider: { " helmet-001 " },
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
            let body = try self.requestBodyData(from: urlRequest)
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

    func testPostsRiderContextToProxy() async throws {
        let endpoint = self.endpoint
        let request = PlaceFactRequest(
            boundary: .town,
            placeName: "Stroud",
            factMode: .shortFacts,
            countryContext: "United Kingdom",
            placeHierarchy: PlaceHierarchy(
                street: nil,
                town: "Stroud",
                county: "Gloucestershire",
                region: "England",
                country: "United Kingdom"
            ),
            riderContext: RiderContext(
                homeCountry: "United Kingdom",
                homeRegion: "West Midlands",
                familiarRegions: ["England", "Cotswolds"],
                factInterestCategories: [.geographyBasics, .locationFacts, .history],
                customFactInstructions: "engineering and old roads"
            )
        )

        MockURLProtocol.requestHandler = { urlRequest in
            let body = try self.requestBodyData(from: urlRequest)
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

            let riderContext = try XCTUnwrap(json?["riderContext"] as? [String: Any])
            XCTAssertEqual(riderContext["homeCountry"] as? String, "united kingdom")
            XCTAssertEqual(riderContext["homeRegion"] as? String, "west midlands")
            XCTAssertEqual(riderContext["familiarRegions"] as? [String], ["england", "cotswolds"])
            XCTAssertEqual(riderContext["customFactInstructions"] as? String, "engineering and old roads")
            XCTAssertEqual(riderContext["factInterestCategories"] as? [String], [
                "geographyBasics",
                "locationFacts",
                "history"
            ])

            let response = HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(#"{"fact":"Great spot for a ride."}"#.utf8))
        }

        let generator = ProxyFactGenerator(
            proxyTokenProvider: { "proxy-token" },
            session: makeMockSession(),
            endpoint: endpoint
        )

        let fact = try await generator.fact(for: request)

        XCTAssertEqual(fact, "Great spot for a ride.")
    }

    func testDefaultEndpointUsesStableRideHorizonEdgeFromContract() async throws {
        let expectedEndpoint = URL(string: "https://ridehorizon.digitalmercenaries.ai/v1/fact")!

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

    func testFactRequestRetriesTransientNetworkAndGatewayFailures() async throws {
        let endpoint = self.endpoint
        var requestCount = 0
        MockURLProtocol.requestHandler = { _ in
            requestCount += 1
            switch requestCount {
            case 1:
                throw URLError(.notConnectedToInternet)
            case 2:
                let response = HTTPURLResponse(
                    url: endpoint,
                    statusCode: 503,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data())
            default:
                let response = HTTPURLResponse(
                    url: endpoint,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data(#"{"fact":"Known for its wool trade."}"#.utf8))
            }
        }

        let generator = ProxyFactGenerator(
            proxyTokenProvider: { "proxy-token" },
            session: makeMockSession(),
            endpoint: endpoint,
            retryDelays: [0, 0]
        )

        let fact = try await generator.fact(
            for: PlaceFactRequest(boundary: .town, placeName: "Stroud", countryContext: nil)
        )

        XCTAssertEqual(requestCount, 3)
        XCTAssertEqual(fact, "Known for its wool trade.")
    }

    func testFactRetryBackoffStopsPromptlyWhenAnnouncementIsCancelled() async {
        let endpoint = self.endpoint
        var requestCount = 0
        MockURLProtocol.requestHandler = { _ in
            requestCount += 1
            throw URLError(.notConnectedToInternet)
        }
        let generator = ProxyFactGenerator(
            proxyTokenProvider: { "proxy-token" },
            session: makeMockSession(),
            endpoint: endpoint,
            retryDelays: [30, 30]
        )
        let task = Task {
            try await generator.fact(
                for: PlaceFactRequest(boundary: .town, placeName: "Stroud", countryContext: nil)
            )
        }

        try? await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation during retry backoff.")
        } catch is CancellationError {
            // Expected: a superseded announcement must not wait for another network attempt.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(requestCount, 1)
    }

    func testFactRequestDoesNotRetryPermanentClientFailure() async {
        let endpoint = self.endpoint
        var requestCount = 0
        MockURLProtocol.requestHandler = { _ in
            requestCount += 1
            let response = HTTPURLResponse(
                url: endpoint,
                statusCode: 400,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }
        let generator = ProxyFactGenerator(
            proxyTokenProvider: { "proxy-token" },
            session: makeMockSession(),
            endpoint: endpoint,
            retryDelays: [0, 0]
        )

        do {
            _ = try await generator.fact(
                for: PlaceFactRequest(boundary: .town, placeName: "Stroud", countryContext: nil)
            )
            XCTFail("Expected a permanent client failure.")
        } catch let error as PlaceFactError {
            XCTAssertEqual(error, .httpError(400))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(requestCount, 1)
    }

    func testProxySpeechGeneratorPostsTextAndReturnsAudio() async throws {
        let endpoint = URL(string: "https://example.test/v1/speech")!

        MockURLProtocol.requestHandler = { urlRequest in
            XCTAssertEqual(urlRequest.url, endpoint)
            XCTAssertEqual(urlRequest.httpMethod, "POST")
            XCTAssertEqual(urlRequest.timeoutInterval, FactProxyContract.speechTimeoutSeconds)
            XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Authorization"), "Bearer proxy-token")
            XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try self.requestBodyData(from: urlRequest)
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            XCTAssertEqual(json?["text"] as? String, "Known for its wool trade.")

            let response = HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "audio/mpeg"]
            )!
            return (response, Data([1, 2, 3]))
        }

        let generator = ProxySpeechGenerator(
            proxyTokenProvider: { "proxy-token" },
            session: makeMockSession(),
            endpoint: endpoint
        )

        let audio = try await generator.speechAudio(for: "Known for its wool trade.")

        XCTAssertEqual(audio, Data([1, 2, 3]))
    }

    func testProxySpeechGeneratorUsesProductionSpeechEndpointByDefault() async throws {
        let expectedEndpoint = URL(string: "https://ridehorizon.digitalmercenaries.ai/v1/speech")!

        MockURLProtocol.requestHandler = { urlRequest in
            XCTAssertEqual(urlRequest.url, expectedEndpoint)
            let response = HTTPURLResponse(
                url: expectedEndpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "audio/mpeg"]
            )!
            return (response, Data([4, 5, 6]))
        }

        let generator = ProxySpeechGenerator(
            proxyTokenProvider: { "proxy-token" },
            session: makeMockSession()
        )

        let audio = try await generator.speechAudio(for: "Known for its wool trade.")

        XCTAssertEqual(audio, Data([4, 5, 6]))
    }

    func testProxySpeechGeneratorTruncatesLongTextToSpeechLimit() async throws {
        let endpoint = URL(string: "https://example.test/v1/speech")!

        let longText = String(repeating: "A", count: 1600)
        MockURLProtocol.requestHandler = { urlRequest in
            XCTAssertEqual(urlRequest.url, endpoint)
            XCTAssertEqual(urlRequest.httpMethod, "POST")

            let body = try self.requestBodyData(from: urlRequest)
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            let text = try XCTUnwrap(json?["text"] as? String)
            XCTAssertLessThanOrEqual(text.count, 1400)

            let response = HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "audio/mpeg"]
            )!
            return (response, Data([1, 2, 3]))
        }

        let generator = ProxySpeechGenerator(
            proxyTokenProvider: { "proxy-token" },
            session: makeMockSession(),
            endpoint: endpoint
        )

        let audio = try await generator.speechAudio(for: longText)

        XCTAssertEqual(audio, Data([1, 2, 3]))
    }

    func testProxySpeechGeneratorSplitsLongTextIntoMultipleSpeechRequests() async throws {
        let endpoint = URL(string: "https://example.test/v1/speech")!
        let longText = String(repeating: "A", count: 1600)
        var requestCount = 0

        MockURLProtocol.requestHandler = { urlRequest in
            requestCount += 1
            XCTAssertEqual(urlRequest.url, endpoint)
            XCTAssertEqual(urlRequest.httpMethod, "POST")

            let response = HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "audio/mpeg"]
            )!
            return (response, Data([1, 2, 3]))
        }

        let generator = ProxySpeechGenerator(
            proxyTokenProvider: { "proxy-token" },
            session: makeMockSession(),
            endpoint: endpoint
        )

        let audioChunks = try await generator.speechAudios(for: longText)

        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(audioChunks.count, 2)
        XCTAssertEqual(audioChunks.first, Data([1, 2, 3]))
        XCTAssertEqual(audioChunks.last, Data([1, 2, 3]))
    }

    func testProxySpeechGeneratorRejectsUnexpectedSpeechContentType() async {
        let endpoint = URL(string: "https://example.test/v1/speech")!

        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"fact":"unexpected"}"#.utf8))
        }

        let generator = ProxySpeechGenerator(
            proxyTokenProvider: { "proxy-token" },
            session: makeMockSession(),
            endpoint: endpoint
        )

        do {
            _ = try await generator.speechAudio(for: "Known for its wool trade.")
            XCTFail("Expected invalidResponse for non-audio content type.")
        } catch let error as PlaceFactError {
            XCTAssertEqual(error, .invalidResponse)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testProxySpeechGeneratorSurfacesHttpStatusBeforeContentType() async {
        let endpoint = URL(string: "https://example.test/v1/speech")!

        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: endpoint,
                statusCode: 429,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"error":"rate limited"}"#.utf8))
        }

        let generator = ProxySpeechGenerator(
            proxyTokenProvider: { "proxy-token" },
            session: makeMockSession(),
            endpoint: endpoint
        )

        do {
            _ = try await generator.speechAudio(for: "Known for its wool trade.")
            XCTFail("Expected HTTP error.")
        } catch let error as PlaceFactError {
            XCTAssertEqual(error, .httpError(429))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testProxySpeechGeneratorReprovisionsAndRetriesOnceOnUnauthorized() async throws {
        let endpoint = URL(string: "https://example.test/v1/speech")!
        var invalidated = false
        var token = "expired-token"
        var requestCount = 0
        MockURLProtocol.requestHandler = { request in
            requestCount += 1
            if requestCount == 1 {
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer expired-token")
                let response = HTTPURLResponse(url: endpoint, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer refreshed-token")
            let response = HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "audio/mpeg"]
            )!
            return (response, Data([7, 8, 9]))
        }
        let generator = ProxySpeechGenerator(
            proxyTokenProvider: { token },
            credentialInvalidator: { invalidated = true },
            credentialRefresher: { token = "refreshed-token" },
            session: makeMockSession(),
            endpoint: endpoint
        )

        let audio = try await generator.speechAudio(for: "Test")

        XCTAssertTrue(invalidated)
        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(audio, Data([7, 8, 9]))
    }

    func testProxySpeechGeneratorPreservesRiderSafeDiagnosticCode() async {
        let endpoint = URL(string: "https://example.test/v1/speech")!
        var requestCount = 0

        MockURLProtocol.requestHandler = { _ in
            requestCount += 1
            let response = HTTPURLResponse(
                url: endpoint,
                statusCode: 502,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (
                response,
                Data(#"{"error":"Premium voice is temporarily unavailable.","code":"RH-TTS-02"}"#.utf8)
            )
        }

        let generator = ProxySpeechGenerator(
            proxyTokenProvider: { "proxy-token" },
            session: makeMockSession(),
            endpoint: endpoint
        )

        do {
            _ = try await generator.speechAudio(for: "Known for its wool trade.")
            XCTFail("Expected coded speech provider error.")
        } catch let error as PlaceFactError {
            XCTAssertEqual(error, .speechServiceUnavailable(code: "RH-TTS-02"))
            XCTAssertEqual(
                error.localizedDescription,
                "Premium voice is temporarily unavailable. [RH-TTS-02]"
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(requestCount, 1)
    }

    func testProxySpeechRetriesGenericTransientFailureThenReturnsAudio() async throws {
        let endpoint = URL(string: "https://example.test/v1/speech")!
        var requestCount = 0
        MockURLProtocol.requestHandler = { _ in
            requestCount += 1
            if requestCount == 1 {
                let response = HTTPURLResponse(
                    url: endpoint,
                    statusCode: 502,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (
                    response,
                    Data(#"{"error":"Premium voice is temporarily unavailable.","code":"RH-TTS-04"}"#.utf8)
                )
            }
            let response = HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "audio/mpeg"]
            )!
            return (response, Data([7, 8, 9]))
        }

        let generator = ProxySpeechGenerator(
            proxyTokenProvider: { "proxy-token" },
            session: makeMockSession(),
            endpoint: endpoint,
            retryDelays: [0, 0]
        )

        let audio = try await generator.speechAudio(for: "Known for its wool trade.")

        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(audio, Data([7, 8, 9]))
    }

    func testMissingProxyTokenAttemptsAutomaticProvisioningBeforeFailing() async {
        let endpoint = self.endpoint
        var refreshCount = 0
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
            credentialRefresher: { refreshCount += 1 },
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
        XCTAssertEqual(refreshCount, 1)
    }

    func testProxyUnauthorizedReprovisionsAndRetriesOnce() async throws {
        let endpoint = self.endpoint
        var invalidated = false
        var token = "expired-token"
        var requestCount = 0
        MockURLProtocol.requestHandler = { request in
            requestCount += 1
            if requestCount == 1 {
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer expired-token")
                let response = HTTPURLResponse(
                    url: endpoint,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data())
            }
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer refreshed-token")
            let response = HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(#"{"fact":"Known for its wool trade."}"#.utf8))
        }

        let generator = ProxyFactGenerator(
            proxyTokenProvider: { token },
            credentialInvalidator: { invalidated = true },
            credentialRefresher: { token = "refreshed-token" },
            session: makeMockSession(),
            endpoint: endpoint
        )

        let fact = try await generator.fact(
            for: PlaceFactRequest(boundary: .town, placeName: "Stroud", countryContext: nil)
        )

        XCTAssertTrue(invalidated)
        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(fact, "Known for its wool trade.")
    }

    private func makeMockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func requestBodyData(from request: URLRequest) throws -> Data {
        if let body = request.httpBody {
            return body
        }

        let stream = try XCTUnwrap(request.httpBodyStream)
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1_024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let bytesRead = stream.read(buffer, maxLength: bufferSize)
            if bytesRead < 0 {
                throw stream.streamError ?? PlaceFactError.invalidResponse
            }
            if bytesRead == 0 {
                break
            }
            data.append(buffer, count: bytesRead)
        }

        return data
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
            XCTAssertEqual(urlRequest.timeoutInterval, FactProxyContract.healthTimeoutSeconds)
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
