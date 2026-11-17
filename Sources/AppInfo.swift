import Foundation

/// The app's name and version, read from Info.plist. `build.sh` fills Info.plist
/// from `config.sh`, so renaming the app only means editing that one file.
enum AppInfo {
    static let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Boardshot"
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
}
