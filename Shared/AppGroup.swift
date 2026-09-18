import Foundation

/// The App Group shared between the main app and the widget extension.
///
/// The identifier is injected at build time via the `APP_GROUP_ID` build setting
/// (exposed through Info.plist), which resolves to `<team>.com.burakcokyildirim.clawde`
/// — the form Apple documents for macOS, and the one every build shares, so what
/// a development build keeps is what a signed one reads. The fallback below is
/// only reached if that key is missing from the bundle.
nonisolated enum AppGroup {

    static let identifier: String = {
        if let id = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
           !id.isEmpty {
            return id
        }
        return "TXQN7T6NNQ.com.burakcokyildirim.clawde"
    }()

    /// Shared defaults suite backed by the app group.
    static let defaults = UserDefaults(suiteName: identifier)

    /// Shared container directory for files exchanged with the widget.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
