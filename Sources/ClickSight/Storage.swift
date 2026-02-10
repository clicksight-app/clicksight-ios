import Foundation

/// Handles local persistence of events and user identity
final class Storage {
    
    static let shared = Storage()
    
    private let defaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private let queue = DispatchQueue(label: "com.clicksight.storage", qos: .utility)
    
    // Keys
    private let distinctIdKey = "com.clicksight.distinctId"
    private let anonymousIdKey = "com.clicksight.anonymousId"
    private let userTraitsKey = "com.clicksight.userTraits"
    private let superPropertiesKey = "com.clicksight.superProperties"
    private let featureFlagsKey = "com.clicksight.featureFlags"
    private let eventQueueKey = "com.clicksight.eventQueue"
    private let optedOutKey = "com.clicksight.optedOut"
    private let firstLaunchKey = "com.clicksight.firstLaunch"
    private let lastAppVersionKey = "com.clicksight.lastAppVersion"
    private let lastSessionEndKey = "com.clicksight.lastSessionEnd"
    
    private init() {}
    
    // MARK: - Identity
    
    /// The current distinct ID (either anonymous or identified)
    var distinctId: String {
        get {
            if let id = defaults.string(forKey: distinctIdKey) {
                return id
            }
            return anonymousId
        }
        set {
            defaults.set(newValue, forKey: distinctIdKey)
        }
    }
    
    /// Persistent anonymous ID generated on first launch
    var anonymousId: String {
        if let id = defaults.string(forKey: anonymousIdKey) {
            return id
        }
        let newId = "anon_\(UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: ""))"
        defaults.set(newId, forKey: anonymousIdKey)
        return newId
    }
    
    /// Whether the user has been identified
    var isIdentified: Bool {
        guard let distinctId = defaults.string(forKey: distinctIdKey) else { return false }
        return !distinctId.hasPrefix("anon_")
    }
    
    /// User traits from identify() calls
    var userTraits: [String: AnyCodable] {
        get {
            guard let data = defaults.data(forKey: userTraitsKey),
                  let traits = try? decoder.decode([String: AnyCodable].self, from: data) else {
                return [:]
            }
            return traits
        }
        set {
            if let data = try? encoder.encode(newValue) {
                defaults.set(data, forKey: userTraitsKey)
            }
        }
    }
    
    // MARK: - Super Properties
    
    /// Properties sent with every event
    var superProperties: [String: AnyCodable] {
        get {
            guard let data = defaults.data(forKey: superPropertiesKey),
                  let props = try? decoder.decode([String: AnyCodable].self, from: data) else {
                return [:]
            }
            return props
        }
        set {
            if let data = try? encoder.encode(newValue) {
                defaults.set(data, forKey: superPropertiesKey)
            }
        }
    }
    
    // MARK: - Feature Flags
    
    /// Cached feature flag values
    var featureFlags: [String: FeatureFlagValue] {
        get {
            guard let data = defaults.data(forKey: featureFlagsKey),
                  let flags = try? decoder.decode([String: FeatureFlagValue].self, from: data) else {
                return [:]
            }
            return flags
        }
        set {
            if let data = try? encoder.encode(newValue) {
                defaults.set(data, forKey: featureFlagsKey)
            }
        }
    }
    
    // MARK: - Event Queue (File-based for larger data)
    
    private var eventQueueURL: URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("clicksight_events.json")
    }
    
    /// Load queued events from disk
    func loadEventQueue() -> [ClickSightEvent] {
        return queue.sync {
            guard let url = eventQueueURL,
                  let data = try? Data(contentsOf: url),
                  let events = try? decoder.decode([ClickSightEvent].self, from: data) else {
                return []
            }
            return events
        }
    }
    
    /// Save queued events to disk
    func saveEventQueue(_ events: [ClickSightEvent]) {
        queue.async { [weak self] in
            guard let self = self, let url = self.eventQueueURL else { return }
            if let data = try? self.encoder.encode(events) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
    
    /// Clear the event queue
    func clearEventQueue() {
        queue.async { [weak self] in
            guard let self = self, let url = self.eventQueueURL else { return }
            try? self.fileManager.removeItem(at: url)
        }
    }
    
    // MARK: - App Lifecycle Detection
    
    /// Whether this is the first ever launch of the app
    var isFirstLaunch: Bool {
        if defaults.bool(forKey: firstLaunchKey) {
            return false
        }
        defaults.set(true, forKey: firstLaunchKey)
        return true
    }
    
    /// Detect if the app was updated since last launch
    var appWasUpdated: Bool {
        let currentVersion = DeviceInfo.shared.appVersion ?? "unknown"
        let lastVersion = defaults.string(forKey: lastAppVersionKey)
        defaults.set(currentVersion, forKey: lastAppVersionKey)
        
        if let lastVersion = lastVersion, lastVersion != currentVersion {
            return true
        }
        return false
    }
    
    /// Last stored app version
    var lastAppVersion: String? {
        return defaults.string(forKey: lastAppVersionKey)
    }
    
    // MARK: - Session
    
    /// Timestamp of the last session end
    var lastSessionEnd: Date? {
        get {
            let timestamp = defaults.double(forKey: lastSessionEndKey)
            return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
        }
        set {
            defaults.set(newValue?.timeIntervalSince1970 ?? 0, forKey: lastSessionEndKey)
        }
    }
    
    // MARK: - Opt Out
    
    /// Whether the user has opted out of tracking
    var optedOut: Bool {
        get { defaults.bool(forKey: optedOutKey) }
        set { defaults.set(newValue, forKey: optedOutKey) }
    }
    
    // MARK: - Reset
    
    /// Reset all stored data (called on logout)
    func reset() {
        let anonymousId = self.anonymousId // preserve anonymous ID generation
        
        defaults.removeObject(forKey: distinctIdKey)
        defaults.removeObject(forKey: userTraitsKey)
        defaults.removeObject(forKey: superPropertiesKey)
        defaults.removeObject(forKey: featureFlagsKey)
        defaults.removeObject(forKey: lastSessionEndKey)
        
        // Generate a new anonymous ID after reset
        let newAnonymousId = "anon_\(UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: ""))"
        defaults.set(newAnonymousId, forKey: anonymousIdKey)
        
        clearEventQueue()
    }
}
