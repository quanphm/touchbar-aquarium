import Foundation

/// Where the TypeSafe API key comes from.
///
/// A `.app` launched from Finder inherits no shell environment, so the primary
/// source is a key file on disk (`~/.config/tools/jev.key`), with the env var
/// and `UserDefaults` as overrides. No secret is ever baked into the build.
public enum JevKey {
    /// Default key file: `~/.config/tools/jev.key`.
    public static var defaultKeyFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/tools/jev.key")
    }

    public static let userDefaultsKey = "typesafe.apiKey"

    /// Resolution order: `TYPESAFE_API_KEY` env → key file → `UserDefaults`.
    /// Returns nil if none holds a non-empty value.
    public static func load(environment: [String: String] = ProcessInfo.processInfo.environment,
                            keyFile: URL = defaultKeyFileURL,
                            defaults: UserDefaults = .standard) -> String? {
        if let v = clean(environment["TYPESAFE_API_KEY"]) { return v }
        if let raw = try? String(contentsOf: keyFile, encoding: .utf8), let v = clean(raw) { return v }
        if let v = clean(defaults.string(forKey: userDefaultsKey)) { return v }
        return nil
    }

    private static func clean(_ value: String?) -> String? {
        guard let t = value?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }
}
