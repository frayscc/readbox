import Foundation

enum ReadBoxSettings {
    static let appGroupID = "group.com.example.readbox"
    static let apiBaseURLKey = "apiBaseURL"
    static let apiTokenKey = "apiToken"
    static let usernameKey = "username"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static var apiBaseURL: String {
        get { defaults.string(forKey: apiBaseURLKey) ?? "" }
        set { defaults.set(normalizeBaseURL(newValue), forKey: apiBaseURLKey) }
    }

    static var apiToken: String {
        get { defaults.string(forKey: apiTokenKey) ?? "" }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: apiTokenKey) }
    }

    static var username: String {
        get { defaults.string(forKey: usernameKey) ?? "readbox" }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: usernameKey) }
    }

    static var isConfigured: Bool {
        !apiBaseURL.isEmpty && !apiToken.isEmpty
    }

    static func normalizeBaseURL(_ value: String) -> String {
        var normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        return normalized
    }
}
