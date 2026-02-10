import Foundation

/// Configuration options for ClickSight SDK
public struct ClickSightOptions {
    
    /// Automatically capture screen views (UIKit view controllers)
    public let captureScreenViews: Bool
    
    /// Automatically capture app lifecycle events (open, background, terminate)
    public let captureAppLifecycle: Bool
    
    /// Enable feature flag evaluation
    public let enableFeatureFlags: Bool
    
    /// Capture session metadata (duration, screen flow, device info)
    public let captureSessionMetadata: Bool
    
    /// Enable crash reporting
    public let enableCrashReporting: Bool
    
    /// Session timeout in minutes — a new session starts after this much inactivity
    public let sessionTimeout: Int
    
    /// How often to flush the event queue (in seconds)
    public let flushInterval: Int
    
    /// Maximum number of events to send in a single batch
    public let maxBatchSize: Int
    
    /// Enable debug logging to Xcode console
    public let debug: Bool
    
    /// Custom API endpoint (defaults to ClickSight cloud)
    public let apiHost: String
    
    /// Maximum number of events to queue locally before oldest are dropped
    public let maxQueueSize: Int
    
    public init(
        captureScreenViews: Bool = true,
        captureAppLifecycle: Bool = true,
        enableFeatureFlags: Bool = true,
        captureSessionMetadata: Bool = true,
        enableCrashReporting: Bool = false,
        sessionTimeout: Int = 30,
        flushInterval: Int = 30,
        maxBatchSize: Int = 100,
        debug: Bool = false,
        apiHost: String = "https://app.clicksight.co",
        maxQueueSize: Int = 1000
    ) {
        self.captureScreenViews = captureScreenViews
        self.captureAppLifecycle = captureAppLifecycle
        self.enableFeatureFlags = enableFeatureFlags
        self.captureSessionMetadata = captureSessionMetadata
        self.enableCrashReporting = enableCrashReporting
        self.sessionTimeout = sessionTimeout
        self.flushInterval = flushInterval
        self.maxBatchSize = maxBatchSize
        self.debug = debug
        self.apiHost = apiHost
        self.maxQueueSize = maxQueueSize
    }
}
