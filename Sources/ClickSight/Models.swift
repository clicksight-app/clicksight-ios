import Foundation

// MARK: - Event Types

/// Represents a single analytics event
public struct ClickSightEvent: Codable {
    public let type: String
    public let event: String
    public let distinctId: String
    public let properties: [String: AnyCodable]
    public let timestamp: String
    public let context: EventContext
    
    enum CodingKeys: String, CodingKey {
        case type, event, properties, timestamp, context
        case distinctId = "distinct_id"
    }
}

/// Device and environment context sent with every event
public struct EventContext: Codable {
    public let deviceId: String
    public let sessionId: String
    public let appVersion: String?
    public let os: OSInfo
    public let device: DeviceDetails
    public let screen: ScreenInfo
    public let locale: String?
    public let timezone: String?
    public let network: NetworkInfo
    public let library: LibraryInfo
    
    enum CodingKeys: String, CodingKey {
        case os, device, screen, locale, timezone, network, library
        case deviceId = "device_id"
        case sessionId = "session_id"
        case appVersion = "app_version"
    }
}

public struct OSInfo: Codable {
    public let name: String
    public let version: String
}

public struct DeviceDetails: Codable {
    public let model: String
    public let manufacturer: String
}

public struct ScreenInfo: Codable {
    public let width: Int
    public let height: Int
}

public struct NetworkInfo: Codable {
    public let type: String
    public let carrier: String?
}

public struct LibraryInfo: Codable {
    public let name: String
    public let version: String
}

// MARK: - API Payloads

/// Batch event payload sent to the ClickSight API
struct BatchPayload: Codable {
    let apiKey: String
    let batch: [ClickSightEvent]
    
    enum CodingKeys: String, CodingKey {
        case batch
        case apiKey = "api_key"
    }
}

/// Identify payload
struct IdentifyPayload: Codable {
    let apiKey: String
    let distinctId: String
    let userId: String
    let traits: [String: AnyCodable]
    
    enum CodingKeys: String, CodingKey {
        case traits
        case apiKey = "api_key"
        case distinctId = "distinct_id"
        case userId = "user_id"
    }
}

/// Feature flag decide payload
struct DecidePayload: Codable {
    let apiKey: String
    let distinctId: String
    let properties: [String: AnyCodable]
    
    enum CodingKeys: String, CodingKey {
        case properties
        case apiKey = "api_key"
        case distinctId = "distinct_id"
    }
}

/// Feature flag decide response
struct DecideResponse: Codable {
    let featureFlags: [String: FeatureFlagValue]
    
    enum CodingKeys: String, CodingKey {
        case featureFlags = "feature_flags"
    }
}

/// Feature flag value — can be a simple bool or an object with payload
public enum FeatureFlagValue: Codable {
    case bool(Bool)
    case object(FeatureFlagDetail)
    
    public var isEnabled: Bool {
        switch self {
        case .bool(let value): return value
        case .object(let detail): return detail.enabled
        }
    }
    
    public var payload: [String: AnyCodable]? {
        switch self {
        case .bool: return nil
        case .object(let detail): return detail.payload
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let detail = try? container.decode(FeatureFlagDetail.self) {
            self = .object(detail)
        } else {
            self = .bool(false)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value): try container.encode(value)
        case .object(let detail): try container.encode(detail)
        }
    }
}

public struct FeatureFlagDetail: Codable {
    public let enabled: Bool
    public let payload: [String: AnyCodable]?
}

// MARK: - AnyCodable wrapper for heterogeneous dictionaries

public struct AnyCodable: Codable, Equatable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        case is NSNull:
            try container.encodeNil()
        default:
            try container.encode(String(describing: value))
        }
    }
    
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }
}

// MARK: - Crash Report Payload

/// Crash report sent to the dedicated /api/app-analytics/crash endpoint
struct CrashPayload: Codable {
    let apiKey: String
    let distinctId: String
    let crashType: String
    let message: String
    let stackTrace: String
    let isFatal: Bool
    let breadcrumbs: [Breadcrumb]
    let context: CrashContext
    
    enum CodingKeys: String, CodingKey {
        case breadcrumbs, context, message
        case apiKey = "api_key"
        case distinctId = "distinct_id"
        case crashType = "crash_type"
        case stackTrace = "stack_trace"
        case isFatal = "is_fatal"
    }
}

/// A breadcrumb records a user action leading up to a crash
public struct Breadcrumb: Codable {
    public let timestamp: String
    public let action: String
    public let category: String
    
    public init(timestamp: String, action: String, category: String) {
        self.timestamp = timestamp
        self.action = action
        self.category = category
    }
}

/// Context included with crash reports
struct CrashContext: Codable {
    let appVersion: String
    let os: OSInfo
    let device: DeviceDetails
    
    enum CodingKeys: String, CodingKey {
        case os, device
        case appVersion = "app_version"
    }
}

// MARK: - Dictionary extension for easy AnyCodable conversion

public extension Dictionary where Key == String, Value == Any {
    var asAnyCodable: [String: AnyCodable] {
        mapValues { AnyCodable($0) }
    }
}
