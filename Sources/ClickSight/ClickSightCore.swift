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
        
        // Set up automatic capture
        self.autoCapture = AutoCapture(clickSight: self, options: options)
        
        // Fetch feature flags if enabled
        if options.enableFeatureFlags {
            reloadFeatureFlags()
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
        
        // Send identify to server
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
            reloadFeatureFlags()
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
            reloadFeatureFlags()
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
