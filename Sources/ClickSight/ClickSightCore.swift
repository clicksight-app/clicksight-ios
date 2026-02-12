import Foundation

/// Internal core of the ClickSight SDK — holds all state and logic
/// The public `ClickSight` class delegates to this
final class ClickSightCore {
    
    let apiKey: String
    let options: ClickSightOptions
    let networkManager: NetworkManager
    let eventQueue: EventQueue
    private(set) var sessionManager: SessionManager!
    private var autoCapture: AutoCapture?
    
    private var superProperties: [String: AnyCodable] = [:]
    
    /// Breadcrumbs for crash reporting — records recent user actions
    private var breadcrumbs: [Breadcrumb] = []
    private let breadcrumbLock = NSLock()
    private let maxBreadcrumbs = 50
    
    /// Background queue for SDK work — never blocks the main thread
    private let sdkQueue = DispatchQueue(label: "co.clicksight.sdk", qos: .utility)
    
    init(apiKey: String, options: ClickSightOptions) {
        self.apiKey = apiKey
        self.options = options
        
        Logger.isEnabled = options.debug
        Logger.log("Initialising ClickSight SDK v\(ClickSight.sdkVersion)", level: .info)
        Logger.log("API Key: \(String(apiKey.prefix(20)))...", level: .debug)
        Logger.log("API Host: \(options.apiHost)", level: .debug)
        
        // Initialise network manager
        self.networkManager = NetworkManager(apiKey: apiKey, apiHost: options.apiHost)
        
        // Initialise event queue first (before session manager captures self)
        self.eventQueue = EventQueue(
            networkManager: networkManager,
            maxBatchSize: options.maxBatchSize,
            maxQueueSize: options.maxQueueSize,
            flushInterval: options.flushInterval
        )
        
        // Now all stored properties are set, so self can be captured safely
        self.sessionManager = SessionManager(
            timeoutMinutes: options.sessionTimeout,
            onSessionStart: { [weak self] sessionId in
                self?.trackInternal("$session_start", properties: [
                    "$session_id": AnyCodable(sessionId)
                ])
            },
            onSessionEnd: { [weak self] sessionId, duration in
                self?.trackInternal("$session_end", properties: [
                    "$session_id": AnyCodable(sessionId),
                    "$session_duration": AnyCodable(duration)
                ])
            }
        )
        
        // Load super properties
        self.superProperties = Storage.shared.superProperties
        
        // Start a session
        _ = sessionManager.sessionId
        
        // Set up automatic capture on the main thread (needs UIKit)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.autoCapture = AutoCapture(clickSight: self, options: options)
        }
        
        // Fetch feature flags on background thread — never block main thread
        if options.enableFeatureFlags {
            sdkQueue.async { [weak self] in
                self?.reloadFeatureFlags()
            }
        }
        
        Logger.log("ClickSight SDK initialised successfully", level: .info)
    }
    
    // MARK: - Track
    
    func track(_ event: String, properties: [String: Any]) {
        guard !Storage.shared.optedOut else {
            Logger.log("Tracking disabled — user opted out", level: .debug)
            return
        }
        
        var allProperties = superProperties
        for (key, value) in properties {
            allProperties[key] = AnyCodable(value)
        }
        
        let clickSightEvent = ClickSightEvent(
            type: "track",
            event: event,
            distinctId: Storage.shared.distinctId,
            properties: allProperties,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            context: DeviceInfo.shared.buildContext(sessionId: sessionManager.sessionId)
        )
        
        eventQueue.enqueue(clickSightEvent)
        
        // Auto-record breadcrumb for crash context
        addBreadcrumb(action: event, category: "event")
    }
    
    /// Internal tracking (for system events with AnyCodable properties)
    func trackInternal(_ event: String, properties: [String: AnyCodable]) {
        guard !Storage.shared.optedOut else { return }
        
        var allProperties = superProperties
        for (key, value) in properties {
            allProperties[key] = value
        }
        
        let clickSightEvent = ClickSightEvent(
            type: "track",
            event: event,
            distinctId: Storage.shared.distinctId,
            properties: allProperties,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            context: DeviceInfo.shared.buildContext(sessionId: sessionManager.sessionId)
        )
        
        eventQueue.enqueue(clickSightEvent)
    }
    
    // MARK: - Screen
    
    func screen(_ name: String, properties: [String: Any]) {
        var screenProperties: [String: Any] = ["$screen_name": name]
        for (key, value) in properties {
            screenProperties[key] = value
        }
        track("$screen_view", properties: screenProperties)
        
        // Record screen navigation as breadcrumb
        addBreadcrumb(action: "Viewed \(name)", category: "navigation")
    }
    
    // MARK: - Identify
    
    func identify(userId: String, traits: [String: Any]) {
        let previousDistinctId = Storage.shared.distinctId
        
        // Update local identity
        Storage.shared.distinctId = userId
        
        var codableTraits: [String: AnyCodable] = [:]
        for (key, value) in traits {
            codableTraits[key] = AnyCodable(value)
        }
        
        // Merge with existing traits
        var existingTraits = Storage.shared.userTraits
        for (key, value) in codableTraits {
            existingTraits[key] = value
        }
        Storage.shared.userTraits = existingTraits
        
        // Send identify to server (on background)
        networkManager.sendIdentify(
            distinctId: previousDistinctId,
            userId: userId,
            traits: existingTraits
        ) { success in
            if success {
                Logger.log("User identified: \(userId)", level: .info)
            }
        }
        
        // Track identify event
        trackInternal("$identify", properties: [
            "$user_id": AnyCodable(userId),
            "$previous_distinct_id": AnyCodable(previousDistinctId)
        ])
        
        // Reload feature flags with new identity
        if options.enableFeatureFlags {
            sdkQueue.async { [weak self] in
                self?.reloadFeatureFlags()
            }
        }
    }
    
    // MARK: - Reset
    
    func reset() {
        Logger.log("Resetting user identity", level: .info)
        
        // Flush remaining events before reset
        eventQueue.flush()
        
        // Reset storage
        Storage.shared.reset()
        
        // Start new session
        sessionManager.startNewSession()
        
        // Reload feature flags
        if options.enableFeatureFlags {
            sdkQueue.async { [weak self] in
                self?.reloadFeatureFlags()
            }
        }
    }
    
    // MARK: - Super Properties
    
    func registerSuperProperties(_ properties: [String: Any]) {
        for (key, value) in properties {
            superProperties[key] = AnyCodable(value)
        }
        Storage.shared.superProperties = superProperties
        Logger.log("Super properties updated: \(properties.keys.joined(separator: ", "))", level: .debug)
    }
    
    func unregisterSuperProperty(_ key: String) {
        superProperties.removeValue(forKey: key)
        Storage.shared.superProperties = superProperties
    }
    
    func clearSuperProperties() {
        superProperties.removeAll()
        Storage.shared.superProperties = [:]
    }
    
    // MARK: - Feature Flags
    
    func featureFlag(_ key: String) -> Bool {
        let flags = Storage.shared.featureFlags
        return flags[key]?.isEnabled ?? false
    }
    
    func featureFlagPayload(_ key: String) -> [String: Any]? {
        let flags = Storage.shared.featureFlags
        guard let payload = flags[key]?.payload else { return nil }
        return payload.mapValues { $0.value }
    }
    
    func reloadFeatureFlags() {
        let properties: [String: AnyCodable] = [
            "app_version": AnyCodable(DeviceInfo.shared.appVersion ?? "unknown"),
            "os": AnyCodable(DeviceInfo.shared.osName),
            "os_version": AnyCodable(DeviceInfo.shared.osVersion),
            "device_model": AnyCodable(DeviceInfo.shared.deviceModel)
        ]
        
        networkManager.fetchFeatureFlags(
            distinctId: Storage.shared.distinctId,
            properties: properties
        ) { result in
            switch result {
            case .success(let flags):
                Storage.shared.featureFlags = flags
                Logger.log("Feature flags loaded: \(flags.count) flags", level: .debug)
            case .failure(let error):
                Logger.log("Failed to load feature flags: \(error.localizedDescription)", level: .warning)
            }
        }
    }
    
    // MARK: - Breadcrumbs
    
    /// Add a breadcrumb for crash context
    func addBreadcrumb(action: String, category: String) {
        let crumb = Breadcrumb(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            action: action,
            category: category
        )
        
        breadcrumbLock.lock()
        breadcrumbs.append(crumb)
        if breadcrumbs.count > maxBreadcrumbs {
            breadcrumbs.removeFirst(breadcrumbs.count - maxBreadcrumbs)
        }
        breadcrumbLock.unlock()
    }
    
    /// Get current breadcrumbs (thread-safe copy)
    func currentBreadcrumbs() -> [Breadcrumb] {
        breadcrumbLock.lock()
        defer { breadcrumbLock.unlock() }
        return breadcrumbs
    }
    
    // MARK: - Crash Reporting
    
    /// Send a crash report to the dedicated crash endpoint
    func sendCrashReport(
        crashType: String,
        message: String,
        stackTrace: String,
        isFatal: Bool
    ) {
        let payload = CrashPayload(
            apiKey: apiKey,
            distinctId: Storage.shared.distinctId,
            crashType: crashType,
            message: message,
            stackTrace: stackTrace,
            isFatal: isFatal,
            breadcrumbs: currentBreadcrumbs(),
            context: CrashContext(
                appVersion: DeviceInfo.shared.appVersion ?? "unknown",
                os: OSInfo(
                    name: DeviceInfo.shared.osName,
                    version: DeviceInfo.shared.osVersion
                ),
                device: DeviceDetails(
                    model: DeviceInfo.shared.deviceModel,
                    manufacturer: "Apple"
                )
            )
        )
        
        networkManager.sendCrash(payload) { success in
            Logger.log("Crash report sent: \(success)", level: .info)
        }
    }
    
    // MARK: - Opt Out
    
    func setOptOut(_ optedOut: Bool) {
        Storage.shared.optedOut = optedOut
        Logger.log("Opt-out set to: \(optedOut)", level: .info)
        
        if optedOut {
            eventQueue.clear()
        }
    }
    
    // MARK: - Flush
    
    func flush() {
        eventQueue.flush()
    }
    
    // MARK: - Cleanup
    
    func shutdown() {
        eventQueue.persistToDisk()
        eventQueue.stopTimer()
        sessionManager.endSession()
    }
}
