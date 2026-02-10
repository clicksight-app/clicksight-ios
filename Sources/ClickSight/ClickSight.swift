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
    public static let sdkVersion = "1.0.0"
    
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
        
        core = ClickSightCore(apiKey: apiKey, options: options)
    }
    
    // MARK: - Event Tracking
    
    /// Track a custom event
    ///
    /// - Parameters:
    ///   - event: Event name (use snake_case, e.g. "add_to_cart")
    ///   - properties: Optional dictionary of event properties
    ///
    /// ```swift
    /// ClickSight.track("purchase_completed", properties: [
    ///     "order_id": "ORD_123",
    ///     "total": 49.99,
    ///     "currency": "GBP"
    /// ])
    /// ```
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
    ///
    /// Screen views are automatically captured for UIKit view controllers if
    /// `captureScreenViews` is enabled. Use this method for SwiftUI views or
    /// when you need to add custom properties.
    ///
    /// - Parameters:
    ///   - name: Screen name (e.g. "ProductDetail", "Cart", "Checkout")
    ///   - properties: Optional dictionary of screen properties
    ///
    /// ```swift
    /// // In SwiftUI .onAppear
    /// ClickSight.screen("ProductDetail", properties: ["product_id": "SKU123"])
    /// ```
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
    ///
    /// Call this when a user logs in or when you know who they are.
    /// All previous anonymous events will be linked to this user.
    ///
    /// - Parameters:
    ///   - userId: Your unique user identifier (string)
    ///   - traits: Optional user properties (email, name, plan, etc.)
    ///
    /// ```swift
    /// ClickSight.identify(userId: "user_456", traits: [
    ///     "email": "ryan@example.com",
    ///     "name": "Ryan",
    ///     "plan": "premium"
    /// ])
    /// ```
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
    ///
    /// This generates a new anonymous ID and clears stored user data.
    /// Future events will be tracked under the new anonymous identity.
    public static func reset() {
        guard let core = core else { return }
        core.reset()
    }
    
    // MARK: - Super Properties
    
    /// Register properties that will be sent with every event
    ///
    /// Useful for properties like app theme, user segment, or A/B test group.
    ///
    /// - Parameter properties: Dictionary of properties to include in all events
    ///
    /// ```swift
    /// ClickSight.registerSuperProperties([
    ///     "app_theme": "dark",
    ///     "user_segment": "premium"
    /// ])
    /// ```
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
    ///
    /// Returns the cached value. Call `reloadFeatureFlags()` to refresh.
    ///
    /// - Parameter key: The feature flag key
    /// - Returns: Whether the flag is enabled
    ///
    /// ```swift
    /// if ClickSight.featureFlag("new_checkout_flow") {
    ///     showNewCheckout()
    /// }
    /// ```
    public static func featureFlag(_ key: String) -> Bool {
        guard let core = core else { return false }
        return core.featureFlag(key)
    }
    
    /// Get the payload for a feature flag
    ///
    /// Some feature flags include a JSON payload with additional configuration.
    ///
    /// - Parameter key: The feature flag key
    /// - Returns: The payload dictionary, or nil if not set
    public static func featureFlagPayload(_ key: String) -> [String: Any]? {
        guard let core = core else { return nil }
        return core.featureFlagPayload(key)
    }
    
    /// Reload feature flags from the server
    ///
    /// Call this after identify() or when you need fresh flag values.
    public static func reloadFeatureFlags() {
        guard let core = core else { return }
        core.reloadFeatureFlags()
    }
    
    // MARK: - Privacy
    
    /// Opt the user in or out of tracking
    ///
    /// When opted out, no events will be captured or sent.
    /// Use this for GDPR compliance.
    ///
    /// - Parameter optedOut: Whether to disable tracking
    public static func setOptOut(_ optedOut: Bool) {
        guard let core = core else { return }
        core.setOptOut(optedOut)
    }
    
    /// Whether the user has opted out of tracking
    public static var isOptedOut: Bool {
        return Storage.shared.optedOut
    }
    
    // MARK: - Queue Management
    
    /// Force flush all queued events to the server immediately
    ///
    /// Events are normally flushed automatically on a timer.
    /// Call this when you need events sent immediately (e.g. before the app closes).
    public static func flush() {
        guard let core = core else { return }
        core.flush()
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
    
    /// Shutdown the SDK (for testing or cleanup)
    static func shutdown() {
        core?.shutdown()
        core = nil
    }
}
