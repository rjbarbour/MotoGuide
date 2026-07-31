import XCTest

final class RideHorizonUITestsLaunchTests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    func testCleanInstallLaunchShowsBrandedSafetyScreen() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ai.digitalmercenaries.ridehorizon.firstRun.hasCompletedOnboarding", "NO",
            "-ai.digitalmercenaries.ridehorizon.firstRun.hasSeenPermissionExplanation", "NO",
            "-ai.digitalmercenaries.ridehorizon.privacy.aiSharingDecision", "notDetermined"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["RideHorizon"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Place awareness for your ride"].exists)
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Set up RideHorizon while stopped")
        ).firstMatch.exists)
        XCTAssertTrue(app.otherElements["Onboarding page 1 of 4"].exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "RideHorizon clean-install onboarding"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
