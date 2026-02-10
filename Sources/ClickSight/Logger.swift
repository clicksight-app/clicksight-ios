import Foundation
import os.log

/// Internal logger for ClickSight SDK
final class Logger {
    
    enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
    
    static var isEnabled = false
    
    private static let osLog = OSLog(subsystem: "com.clicksight.sdk", category: "ClickSight")
    
    /// Log a message if debug mode is enabled
    static func log(_ message: String, level: Level = .info) {
        guard isEnabled else { return }
        
        let prefix = "[ClickSight][\(level.rawValue)]"
        let fullMessage = "\(prefix) \(message)"
        
        switch level {
        case .debug:
            os_log(.debug, log: osLog, "%{public}@", fullMessage)
        case .info:
            os_log(.info, log: osLog, "%{public}@", fullMessage)
        case .warning:
            os_log(.default, log: osLog, "%{public}@", fullMessage)
        case .error:
            os_log(.error, log: osLog, "%{public}@", fullMessage)
        }
        
        #if DEBUG
        print(fullMessage)
        #endif
    }
}
