import Foundation

enum ProductIdentity {
    static let displayName: String = {
        let info = Bundle.main.infoDictionary
        let displayName = info?["CFBundleDisplayName"] as? String
        let bundleName = info?["CFBundleName"] as? String

        return displayName ?? bundleName ?? "App"
    }()
}

enum AppDiagnostics {
    static func log(_ message: @autoclosure () -> String) {
#if DEBUG
        print(message())
#endif
    }
}
