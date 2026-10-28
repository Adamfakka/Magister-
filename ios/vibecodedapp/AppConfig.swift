import Foundation

enum AppConfig {
    private static let plist: NSDictionary? = {
        guard let url = Bundle.main.url(forResource: "AppConfig", withExtension: "plist") else { return nil }
        return NSDictionary(contentsOf: url)
    }()

    static func string(_ key: String) -> String? {
        plist?[key] as? String
    }
}
