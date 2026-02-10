#if canImport(UIKit)
import UIKit
#endif
import Foundation

/// Collects device and environment information
final class DeviceInfo {
    
    static let shared = DeviceInfo()
    
    private init() {}
    
    /// Persistent device ID stored in UserDefaults
    var deviceId: String {
        let key = "com.clicksight.deviceId"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let newId = UUID().uuidString.lowercased()
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
    
    /// OS name
    var osName: String {
        #if os(iOS)
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #elseif os(watchOS)
        return "watchOS"
        #elseif os(tvOS)
        return "tvOS"
        #else
        return "unknown"
        #endif
    }
    
    /// OS version string
    var osVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
    
    /// Device model identifier (e.g. "iPhone15,2")
    var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return mapDeviceModel(identifier)
    }
    
    /// Device manufacturer
    var manufacturer: String {
        return "Apple"
    }
    
    /// Screen dimensions
    var screenWidth: Int {
        #if canImport(UIKit) && !os(watchOS)
        return Int(UIScreen.main.bounds.width * UIScreen.main.scale)
        #else
        return 0
        #endif
    }
    
    var screenHeight: Int {
        #if canImport(UIKit) && !os(watchOS)
        return Int(UIScreen.main.bounds.height * UIScreen.main.scale)
        #else
        return 0
        #endif
    }
    
    /// Current locale identifier
    var locale: String {
        return Locale.current.identifier
    }
    
    /// Current timezone identifier
    var timezone: String {
        return TimeZone.current.identifier
    }
    
    /// App version from bundle
    var appVersion: String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    /// App build number from bundle
    var appBuild: String? {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }
    
    /// Bundle identifier
    var bundleId: String? {
        return Bundle.main.bundleIdentifier
    }
    
    /// Network type (basic detection)
    var networkType: String {
        // Basic detection — for more accurate results, use NWPathMonitor
        return "unknown"
    }
    
    /// Build the full EventContext
    func buildContext(sessionId: String) -> EventContext {
        return EventContext(
            deviceId: deviceId,
            sessionId: sessionId,
            appVersion: appVersion,
            os: OSInfo(name: osName, version: osVersion),
            device: DeviceDetails(model: deviceModel, manufacturer: manufacturer),
            screen: ScreenInfo(width: screenWidth, height: screenHeight),
            locale: locale,
            timezone: timezone,
            network: NetworkInfo(type: networkType, carrier: nil),
            library: LibraryInfo(name: "clicksight-ios", version: ClickSight.sdkVersion)
        )
    }
    
    // MARK: - Device model mapping
    
    private func mapDeviceModel(_ identifier: String) -> String {
        let modelMap: [String: String] = [
            // iPhone 16 series
            "iPhone17,1": "iPhone 16 Pro",
            "iPhone17,2": "iPhone 16 Pro Max",
            "iPhone17,3": "iPhone 16",
            "iPhone17,4": "iPhone 16 Plus",
            // iPhone 15 series
            "iPhone15,4": "iPhone 15",
            "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
            // iPhone 14 series
            "iPhone14,7": "iPhone 14",
            "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            // iPhone 13 series
            "iPhone14,5": "iPhone 13",
            "iPhone14,4": "iPhone 13 mini",
            "iPhone14,2": "iPhone 13 Pro",
            "iPhone14,3": "iPhone 13 Pro Max",
            // iPhone SE
            "iPhone14,6": "iPhone SE (3rd generation)",
            // iPad models (common ones)
            "iPad14,1": "iPad Pro 11-inch (4th generation)",
            "iPad14,2": "iPad Pro 12.9-inch (6th generation)",
            // Simulator
            "x86_64": "Simulator",
            "arm64": "Simulator",
        ]
        
        return modelMap[identifier] ?? identifier
    }
}
