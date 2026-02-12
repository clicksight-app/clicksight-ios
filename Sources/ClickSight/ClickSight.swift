import Foundation

/// ClickSight iOS Analytics SDK
///
/// Usage:
/// ```swift
/// // Initialise in AppDelegate or App struct
/// ClickSight.configure(apiKey: "cs_app_live_xxxxx")
///
/// // Track events
/// ClickSight.track("add_to_cart", properties: ["product_id": "123", "price": 29.99])
///
/// // Track screens
/// ClickSight.screen("ProductDetail", properties: ["product_id": "123"])
///
/// // Identify users
/// ClickSight.identify(userId: "user_456", traits: ["email": "user@example.com"])
///
/// // Check feature flags
/// if ClickSight.featureFlag("new_checkout") { ... }
/// ```
public final class ClickSight {
    
    /// SDK version
    public static let sdkVersion = "1.0.2"
    
    /// Internal core instance
    private static var core: ClickSightCore?
    
    /// Whether the SDK has been configured
    public static var isConfigured: Bool {
        return core != nil
    }
    
    // MARK: - Configuration
    
    /// Initialise the ClickSight SDK with your API key
    ///
    /// Call this once at app launch, before any tracking calls.
    /// Initialization is designed to be non-blocking and safe to call on the main thread.
    ///
    /// - Parameters:
    ///   - apiKey: Your ClickSight project API key (format: cs_app_live_xxxxx)
    ///   - options: Configuration options (optional, uses defaults if not provided)
    public static func configure(apiKey: String, options: ClickSightOptions = ClickSightOptions()) {
        guard core == nil else {
            Logger.log("ClickSight already configured — ignoring duplicate configure() call", level: .warning)
            return
        }
        
        guard !apiKey.isEmpty else {
            Logger.isEnabled = true
            Logger.log("API key is empty — ClickSight will not track events", level: .error)
            return
        }
        
        // Create core synchronously (lightweight) but defer heavy work to background
        core = ClickSightCore(apiKey: apiKey, options: options)
    }
    
    // MARK: - Event Tracking
    
    /// Track a custom event
    public static func track(_ event: String, properties: [String: Any] = [:]) {
        guard let core = core else {
            Logger.isEnabled = true
            Logger.log("ClickSight not configured — call configure() first", level: .error)
            return
        }
        core.track(event, properties: properties)
    }
    
    // MARK: - Screen Tracking
    
    /// Track a screen view
    public static func screen(_ name: String, properties: [String: Any] = [:]) {
        guard let core = core else {
            Logger.isEnabled = true
            Logger.log("ClickSight not configured — call configure() first", level: .error)
            return
        }
        core.screen(name, properties: properties)
    }
    
    // MARK: - User Identity
    
    /// Identify a user — links their anonymous activity to their known identity
    public static func identify(userId: String, traits: [String: Any] = [:]) {
        guard let core = core else {
            Logger.isEnabled = true
            Logger.log("ClickSight not configured — call configure() first", level: .error)
            return
        }
        
        guard !userId.isEmpty else {
            Logger.log("identify() called with empty userId — ignoring", level: .warning)
            return
        }
        
        core.identify(userId: userId, traits: traits)
    }
    
    /// Reset user identity — call this when the user logs out
    public static func reset() {
        guard let core = core else { return }
        core.reset()
    }
    
    // MARK: - Super Properties
    
    /// Register properties that will be sent with every event
    public static func registerSuperProperties(_ properties: [String: Any]) {
        guard let core = core else { return }
        core.registerSuperProperties(properties)
    }
    
    /// Remove a single super property
    public static func unregisterSuperProperty(_ key: String) {
        guard let core = core else { return }
        core.unregisterSuperProperty(key)
    }
    
    /// Clear all super properties
    public static func clearSuperProperties() {
        guard let core = core else { return }
        core.clearSuperProperties()
    }
    
    // MARK: - Feature Flags
    
    /// Check if a feature flag is enabled for the current user
    public static func featureFlag(_ key: String) -> Bool {
        guard let core = core else { return false }
        return core.featureFlag(key)
    }
    
    /// Get the payload for a feature flag
    public static func featureFlagPayload(_ key: String) -> [String: Any]? {
        guard let core = core else { return nil }
        return core.featureFlagPayload(key)
    }
    
    /// Reload feature flags from the server
    public static func reloadFeatureFlags() {
        guard let core = core else { return }
        core.reloadFeatureFlags()
    }
    
    // MARK: - Privacy
    
    /// Opt the user in or out of tracking (for GDPR compliance)
    public static func setOptOut(_ optedOut: Bool) {
        guard let core = core else { return }
        core.setOptOut(optedOut)
    }
    
    /// Report a non-fatal error — useful for caught exceptions and handled errors
    ///
    /// ```swift
    /// do {
    ///     try riskyOperation()
    /// } catch {
    ///     ClickSight.reportError(error, isFatal: false)
    /// }
    /// ```
    public static func reportError(_ error: Error, isFatal: Bool = false) {
        guard let core = core else { return }
        let nsError = error as NSError
        core.sendCrashReport(
            crashType: nsError.domain,
            message: error.localizedDescription,
            stackTrace: Thread.callStackSymbols.joined(separator: "\n"),
            isFatal: isFatal
        )
    }
    
    /// Whether the user has opted out of tracking
    public static var isOptedOut: Bool {
        return Storage.shared.optedOut
    }
    
    // MARK: - Queue Management
    
    /// Force flush all queued events to the server immediately
    public static func flush() {
        guard let core = core else { return }
        core.flush()
    }
    
    // MARK: - Breadcrumbs
    
    /// Add a breadcrumb — records user actions for crash context
    ///
    /// Breadcrumbs are automatically added for screen views and tracked events.
    /// Use this to manually add breadcrumbs for UI interactions, API calls, etc.
    ///
    /// - Parameters:
    ///   - action: Description of the action (e.g. "Tapped checkout", "API call failed")
    ///   - category: Category of the action (e.g. "interaction", "network", "navigation")
    ///
    /// ```swift
    /// ClickSight.addBreadcrumb(action: "Tapped checkout button", category: "interaction")
    /// ClickSight.addBreadcrumb(action: "Payment API returned 500", category: "network")
    /// ```
    public static func addBreadcrumb(action: String, category: String) {
        guard let core = core else { return }
        core.addBreadcrumb(action: action, category: category)
    }
    
    // MARK: - Diagnostics
    
    /// Get the current anonymous or identified user ID
    public static var distinctId: String {
        return Storage.shared.distinctId
    }
    
    /// Number of events queued locally
    public static var queuedEventCount: Int {
        return core?.eventQueue.count ?? 0
    }
    
    // MARK: - Internal
    
    /// Internal access for crash handler — needed because NSSetUncaughtExceptionHandler
    /// captures a C function pointer that can't access private properties
    internal static var crashReportingCore: ClickSightCore? {
        return core
    }
    
    /// Shutdown the SDK (for testing or cleanup)
    static func shutdown() {
        core?.shutdown()
        core = nil
    }
}
