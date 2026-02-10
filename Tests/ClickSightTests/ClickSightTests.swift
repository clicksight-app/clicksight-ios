import XCTest
@testable import ClickSight

final class ClickSightTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        ClickSight.shutdown()
        // Clear UserDefaults for clean test state
        let domain = Bundle.main.bundleIdentifier ?? "com.clicksight.tests"
        UserDefaults.standard.removePersistentDomain(forName: domain)
    }
    
    override func tearDown() {
        ClickSight.shutdown()
        super.tearDown()
    }
    
    // MARK: - Configuration Tests
    
    func testConfigureSetupCorrectly() {
        ClickSight.configure(apiKey: "cs_app_live_test123", options: ClickSightOptions(debug: true))
        XCTAssertTrue(ClickSight.isConfigured)
    }
    
    func testConfigureWithEmptyKeyDoesNotConfigure() {
        ClickSight.configure(apiKey: "")
        XCTAssertFalse(ClickSight.isConfigured)
    }
    
    func testDuplicateConfigureIsIgnored() {
        ClickSight.configure(apiKey: "cs_app_live_test123")
        ClickSight.configure(apiKey: "cs_app_live_different")
        XCTAssertTrue(ClickSight.isConfigured)
    }
    
    // MARK: - Identity Tests
    
    func testAnonymousIdIsGenerated() {
        let id = Storage.shared.anonymousId
        XCTAssertTrue(id.hasPrefix("anon_"))
        XCTAssertFalse(id.isEmpty)
    }
    
    func testAnonymousIdIsPersistent() {
        let id1 = Storage.shared.anonymousId
        let id2 = Storage.shared.anonymousId
        XCTAssertEqual(id1, id2)
    }
    
    func testIdentifySetsDistinctId() {
        ClickSight.configure(
            apiKey: "cs_app_live_test123",
            options: ClickSightOptions(
                captureAppLifecycle: false,
                enableFeatureFlags: false,
                debug: true,
                apiHost: "http://localhost:9999"
            )
        )
        
        ClickSight.identify(userId: "user_456", traits: ["email": "test@example.com"])
        XCTAssertEqual(ClickSight.distinctId, "user_456")
    }
    
    func testResetGeneratesNewAnonymousId() {
        ClickSight.configure(
            apiKey: "cs_app_live_test123",
            options: ClickSightOptions(
                captureAppLifecycle: false,
                enableFeatureFlags: false,
                apiHost: "http://localhost:9999"
            )
        )
        
        ClickSight.identify(userId: "user_456")
        XCTAssertEqual(ClickSight.distinctId, "user_456")
        
        ClickSight.reset()
        XCTAssertTrue(ClickSight.distinctId.hasPrefix("anon_"))
        XCTAssertNotEqual(ClickSight.distinctId, "user_456")
    }
    
    // MARK: - Opt Out Tests
    
    func testOptOutStopsTracking() {
        ClickSight.configure(
            apiKey: "cs_app_live_test123",
            options: ClickSightOptions(
                captureAppLifecycle: false,
                enableFeatureFlags: false,
                apiHost: "http://localhost:9999"
            )
        )
        
        ClickSight.setOptOut(true)
        XCTAssertTrue(ClickSight.isOptedOut)
        
        ClickSight.track("test_event")
        XCTAssertEqual(ClickSight.queuedEventCount, 0)
    }
    
    // MARK: - AnyCodable Tests
    
    func testAnyCodableEncodesString() throws {
        let value = AnyCodable("hello")
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertEqual(decoded.value as? String, "hello")
    }
    
    func testAnyCodableEncodesInt() throws {
        let value = AnyCodable(42)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertEqual(decoded.value as? Int, 42)
    }
    
    func testAnyCodableEncodesDouble() throws {
        let value = AnyCodable(3.14)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertEqual(decoded.value as? Double, 3.14)
    }
    
    func testAnyCodableEncodesBool() throws {
        let value = AnyCodable(true)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertEqual(decoded.value as? Bool, true)
    }
    
    // MARK: - Device Info Tests
    
    func testDeviceIdIsPersistent() {
        let id1 = DeviceInfo.shared.deviceId
        let id2 = DeviceInfo.shared.deviceId
        XCTAssertEqual(id1, id2)
    }
    
    func testOSNameIsSet() {
        let osName = DeviceInfo.shared.osName
        XCTAssertFalse(osName.isEmpty)
    }
    
    func testOSVersionIsSet() {
        let osVersion = DeviceInfo.shared.osVersion
        XCTAssertFalse(osVersion.isEmpty)
    }
    
    // MARK: - Storage Tests
    
    func testSuperPropertiesPersist() {
        let storage = Storage.shared
        storage.superProperties = ["theme": AnyCodable("dark"), "version": AnyCodable(2)]
        
        let loaded = storage.superProperties
        XCTAssertEqual(loaded["theme"]?.value as? String, "dark")
        XCTAssertEqual(loaded["version"]?.value as? Int, 2)
    }
}
