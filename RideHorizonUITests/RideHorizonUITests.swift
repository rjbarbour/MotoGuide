import XCTest

final class RideHorizonUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-ai.digitalmercenaries.ridehorizon.firstRun.hasCompletedOnboarding", "NO",
            "-ai.digitalmercenaries.ridehorizon.firstRun.hasSeenPermissionExplanation", "NO",
            "-ai.digitalmercenaries.ridehorizon.privacy.aiSharingDecision", "notDetermined",
            "-RideHorizonTestMode", "NO"
        ]
    }

    func testCleanInstallCompletesOnDeviceOnlyOnboardingWithoutCredentials() throws {
        addUIInterruptionMonitor(withDescription: "Location permission") { alert in
            for label in ["Allow While Using App", "Allow Once"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
        addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
            if alert.buttons["Allow"].exists {
                alert.buttons["Allow"].tap()
                return true
            }
            return false
        }

        app.launch()

        XCTAssertTrue(app.staticTexts["Place awareness for your ride"].waitForExistence(timeout: 5))
        let safetyCopy = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Set up RideHorizon while stopped")
        ).firstMatch
        XCTAssertTrue(safetyCopy.exists)
        XCTAssertGreaterThanOrEqual(safetyCopy.frame.minX, app.frame.minX - 1)
        XCTAssertLessThanOrEqual(safetyCopy.frame.maxX, app.frame.maxX + 1)
        XCTAssertTrue(app.otherElements["Onboarding page 1 of 4"].exists)
        let backButton = app.buttons["Back"]
        XCTAssertTrue(backButton.exists)
        XCTAssertFalse(backButton.isHittable)
        let firstPageBackFrame = backButton.frame
        for forbiddenCredentialLabel in ["proxy token", "invite code", "API key"] {
            XCTAssertFalse(app.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS[c] %@", forbiddenCredentialLabel)
            ).firstMatch.exists)
        }

        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Location and audio"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.otherElements["Onboarding page 2 of 4"].exists)
        XCTAssertTrue(backButton.exists)
        XCTAssertEqual(backButton.frame.minX, firstPageBackFrame.minX, accuracy: 1)
        XCTAssertEqual(backButton.frame.minY, firstPageBackFrame.minY, accuracy: 1)

        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Choose how facts are made"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.otherElements["Onboarding page 3 of 4"].exists)
        XCTAssertTrue(app.buttons["Allow AI features"].exists)
        XCTAssertTrue(app.buttons["Use on-device features only"].exists)

        app.buttons["Read privacy details"].tap()
        XCTAssertTrue(app.navigationBars["Privacy notice"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Optional AI features"].exists)
        let privacyPolicyLink = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "Read the RideHorizon Privacy Policy")
        ).firstMatch
        for _ in 0..<4 where !privacyPolicyLink.exists {
            app.swipeUp()
        }
        XCTAssertTrue(privacyPolicyLink.exists)
        app.buttons["Done"].tap()

        app.buttons["Use on-device features only"].tap()
        XCTAssertTrue(app.staticTexts["Welcome to Italy"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.otherElements["Onboarding page 4 of 4"].exists)

        app.buttons["Get Started"].tap()

        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Log"].exists)
        XCTAssertTrue(app.buttons["Start ride"].exists)
        XCTAssertFalse(app.buttons["End ride"].exists)
        XCTAssertFalse(app.buttons["Allow AI features"].exists)

        app.buttons["Start ride"].tap()
        app.tap()
        app.tap()
        XCTAssertTrue(app.buttons["End ride"].waitForExistence(timeout: 5))

        app.buttons["End ride"].tap()
        XCTAssertTrue(app.buttons["Start ride"].waitForExistence(timeout: 2))
    }

    func testLandscapeOnboardingKeepsControlsFixedAndSafetyContentScrollable() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        addTeardownBlock {
            XCUIDevice.shared.orientation = .portrait
        }
        app.launch()

        let landscapeFrame = NSPredicate { [weak app] _, _ in
            guard let frame = app?.frame else { return false }
            return frame.width > frame.height
        }
        let landscapeExpectation = XCTNSPredicateExpectation(
            predicate: landscapeFrame,
            object: app
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [landscapeExpectation], timeout: 5),
            .completed,
            "The app must settle into a true landscape layout before assertions run."
        )

        let safetyCopy = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Set up RideHorizon while stopped")
        ).firstMatch
        XCTAssertTrue(safetyCopy.waitForExistence(timeout: 5))
        let nextButton = app.buttons["Next"]
        XCTAssertTrue(nextButton.isHittable)
        let initialNextFrame = nextButton.frame
        XCTAssertTrue(app.buttons["Back"].exists)
        XCTAssertFalse(app.buttons["Back"].isHittable)

        let initialSafetyPosition = safetyCopy.frame.minY
        app.swipeUp()
        XCTAssertLessThan(safetyCopy.frame.minY, initialSafetyPosition - 5)
        XCTAssertGreaterThanOrEqual(safetyCopy.frame.minX, app.frame.minX - 1)
        XCTAssertLessThanOrEqual(safetyCopy.frame.maxX, app.frame.maxX + 1)
        XCTAssertTrue(nextButton.isHittable)
        XCTAssertEqual(nextButton.frame.minX, initialNextFrame.minX, accuracy: 1)
        XCTAssertEqual(nextButton.frame.minY, initialNextFrame.minY, accuracy: 1)

        nextButton.tap()
        XCTAssertTrue(app.staticTexts["Location and audio"].waitForExistence(timeout: 2))
        nextButton.tap()
        XCTAssertTrue(app.staticTexts["Choose how facts are made"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Allow AI features"].isHittable)
        XCTAssertTrue(app.buttons["Use on-device features only"].isHittable)

        let privacyDisclosure = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH[c] %@", "If you allow AI features")
        ).firstMatch
        XCTAssertTrue(privacyDisclosure.exists)
        let privacyDetailsButton = app.buttons["Read privacy details"]
        for _ in 0..<4 where !privacyDetailsButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(privacyDetailsButton.isHittable)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Settled compact landscape AI consent"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        privacyDetailsButton.tap()
        XCTAssertTrue(app.navigationBars["Privacy notice"].waitForExistence(timeout: 2))
    }
}
