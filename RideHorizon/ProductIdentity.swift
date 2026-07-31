import Foundation

enum ProductIdentity {
    static let displayName: String = {
        let info = Bundle.main.infoDictionary
        let displayName = info?["CFBundleDisplayName"] as? String
        let bundleName = info?["CFBundleName"] as? String

        return displayName ?? bundleName ?? "App"
    }()
}

enum ProductLinks {
    static let privacyPolicy = URL(string: "https://ridehorizon.digitalmercenaries.ai/app-privacy-policy")!
}

enum RiderSafetyCopy {
    static let onboarding = "Set up \(ProductIdentity.displayName) while stopped. Do not interact with the phone while moving, and stop using the app if it becomes distracting."
}

enum AppDiagnostics {
    static func log(_ message: @autoclosure () -> String) {
#if DEBUG
        print(message())
#endif
    }
}
