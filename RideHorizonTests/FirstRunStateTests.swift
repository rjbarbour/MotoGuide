import XCTest
@testable import RideHorizon

final class FirstRunStateTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "FirstRunStateTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testFreshInstallNeedsOnboarding() {
        let state = FirstRunState(defaults: defaults)

        XCTAssertTrue(state.needsOnboarding)
        XCTAssertFalse(state.hasCompletedOnboarding)
        XCTAssertFalse(state.hasSeenPermissionExplanation)
    }

    func testCompleteOnboardingClearsNeedsOnboarding() {
        let state = FirstRunState(defaults: defaults)

        state.completeOnboarding()

        XCTAssertFalse(state.needsOnboarding)
        XCTAssertTrue(state.hasCompletedOnboarding)

        let reloaded = FirstRunState(defaults: defaults)
        XCTAssertTrue(reloaded.hasCompletedOnboarding)
    }

    func testMarkPermissionExplanationSeenPersists() {
        let state = FirstRunState(defaults: defaults)

        state.markPermissionExplanationSeen()

        XCTAssertTrue(state.hasSeenPermissionExplanation)

        let reloaded = FirstRunState(defaults: defaults)
        XCTAssertTrue(reloaded.hasSeenPermissionExplanation)
    }

    func testResetClearsAllFlags() {
        let state = FirstRunState(defaults: defaults)
        state.markPermissionExplanationSeen()
        state.completeOnboarding()

        state.reset()

        XCTAssertTrue(state.needsOnboarding)
        XCTAssertFalse(state.hasCompletedOnboarding)
        XCTAssertFalse(state.hasSeenPermissionExplanation)

        for key in FirstRunState.Key.allCases {
            let storageKey = FirstRunState.storagePrefix + key.rawValue
            XCTAssertNil(defaults.object(forKey: storageKey))
        }

        let reloaded = FirstRunState(defaults: defaults)
        XCTAssertTrue(reloaded.needsOnboarding)
        XCTAssertFalse(reloaded.hasCompletedOnboarding)
        XCTAssertFalse(reloaded.hasSeenPermissionExplanation)
    }
}

final class AISharingConsentStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AISharingConsentStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testFreshInstallHasNoAISharingDecision() {
        let store = AISharingConsentStore(defaults: defaults)

        XCTAssertEqual(store.decision, .notDetermined)
        XCTAssertFalse(store.isGranted)
    }

    func testGrantAndDeclinePersistExplicitDecision() {
        let store = AISharingConsentStore(defaults: defaults)

        store.grant()
        XCTAssertEqual(AISharingConsentStore(defaults: defaults).decision, .granted)

        store.decline()
        XCTAssertEqual(AISharingConsentStore(defaults: defaults).decision, .declined)
        XCTAssertFalse(store.isGranted)
    }

    func testResetRemovesAISharingDecision() {
        let store = AISharingConsentStore(defaults: defaults)
        store.grant()

        store.reset()

        XCTAssertEqual(store.decision, .notDetermined)
        XCTAssertNil(defaults.object(forKey: AISharingConsentStore.storageKey))
    }
}
