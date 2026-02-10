# ClickSight iOS SDK

The official iOS SDK for [ClickSight](https://clicksight.co) — advanced eCommerce analytics and attribution.

Track events, screen views, user journeys, and feature flags in your iOS app with automatic cross-platform attribution linking app activity to your web ad campaigns.

## Requirements

- iOS 15.0+
- Swift 5.9+
- Xcode 15+

## Installation

### Swift Package Manager (Recommended)

In Xcode: **File → Add Package Dependencies** and enter:

```
https://github.com/clicksight/clicksight-ios
```

Or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/clicksight/clicksight-ios", from: "1.0.0")
]
```

### CocoaPods

```ruby
pod 'ClickSight', '~> 1.0'
```

## Quick Start

### 1. Initialise the SDK

**SwiftUI (App struct):**

```swift
import SwiftUI
import ClickSight

@main
struct MyApp: App {
    init() {
        ClickSight.configure(
            apiKey: "YOUR_API_KEY",
            options: ClickSightOptions(
                captureScreenViews: true,
                captureAppLifecycle: true,
                enableFeatureFlags: true,
                debug: true // Set to false in production
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**UIKit (AppDelegate):**

```swift
import UIKit
import ClickSight

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        ClickSight.configure(
            apiKey: "YOUR_API_KEY",
            options: ClickSightOptions(debug: true)
        )
        
        return true
    }
}
```

### 2. Identify Users

Call this when a user logs in so their anonymous activity gets linked to their account:

```swift
ClickSight.identify(userId: "user_456", traits: [
    "email": "ryan@example.com",
    "name": "Ryan",
    "plan": "premium"
])
```

### 3. Track Events

```swift
// Track a purchase
ClickSight.track("purchase_completed", properties: [
    "order_id": "ORD_123",
    "total": 49.99,
    "currency": "GBP",
    "items": 3
])

// Track add to cart
ClickSight.track("add_to_cart", properties: [
    "product_id": "SKU_456",
    "product_name": "Premium Widget",
    "price": 29.99
])

// Track a search
ClickSight.track("product_searched", properties: [
    "query": "running shoes",
    "results_count": 24
])
```

### 4. Track Screen Views

Screen views are captured automatically for UIKit view controllers. For SwiftUI, add manual tracking:

```swift
struct ProductDetailView: View {
    let product: Product
    
    var body: some View {
        ScrollView { /* ... */ }
            .onAppear {
                ClickSight.screen("ProductDetail", properties: [
                    "product_id": product.id,
                    "category": product.category
                ])
            }
    }
}
```

### 5. Feature Flags

```swift
if ClickSight.featureFlag("new_checkout_flow") {
    showNewCheckout()
} else {
    showClassicCheckout()
}

// Get flag payload for remote config
if let config = ClickSight.featureFlagPayload("onboarding_config") {
    let steps = config["steps"] as? Int ?? 3
}
```

### 6. Reset on Logout

```swift
func logout() {
    // Clear user session...
    ClickSight.reset()
}
```

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `captureScreenViews` | `true` | Auto-capture UIKit screen views |
| `captureAppLifecycle` | `true` | Track app open, background, terminate |
| `enableFeatureFlags` | `true` | Enable feature flag evaluation |
| `captureSessionMetadata` | `true` | Track session duration and metadata |
| `enableCrashReporting` | `false` | Capture unhandled exceptions |
| `sessionTimeout` | `30` | Minutes of inactivity before new session |
| `flushInterval` | `30` | Seconds between automatic event flushes |
| `maxBatchSize` | `100` | Max events per API request |
| `debug` | `false` | Enable console logging |
| `apiHost` | `https://api.clicksight.co` | Custom API endpoint |
| `maxQueueSize` | `1000` | Max events queued locally |

## Super Properties

Register properties that are sent with every event:

```swift
ClickSight.registerSuperProperties([
    "app_theme": "dark",
    "user_segment": "premium",
    "ab_test_group": "variant_b"
])

// Remove a single property
ClickSight.unregisterSuperProperty("ab_test_group")

// Clear all
ClickSight.clearSuperProperties()
```

## Privacy & GDPR

```swift
// Opt user out of all tracking
ClickSight.setOptOut(true)

// Check opt-out status
if ClickSight.isOptedOut {
    // Show opt-in prompt
}

// Opt back in
ClickSight.setOptOut(false)
```

## Automatic Events

The SDK automatically captures these events when enabled:

| Event | Description |
|-------|-------------|
| `$app_installed` | First launch of the app |
| `$app_updated` | App version changed since last launch |
| `$app_opened` | App came to foreground |
| `$app_backgrounded` | App moved to background |
| `$session_start` | New session started |
| `$session_end` | Session ended (with duration) |
| `$screen_view` | UIKit view controller appeared |
| `$app_crashed` | Unhandled exception (if crash reporting enabled) |

## Cross-Platform Attribution

ClickSight automatically links app events to your web marketing campaigns. When a user clicks a Google or Meta ad, visits your website, then later opens your app — ClickSight connects the dots via the `identify()` call, giving you full cross-platform attribution.

This is the killer feature: see which ad campaigns drive app installs and in-app purchases.

## Diagnostics

```swift
// Current user ID (anonymous or identified)
let userId = ClickSight.distinctId

// Events waiting to be sent
let pending = ClickSight.queuedEventCount

// Force send all queued events
ClickSight.flush()
```

## Architecture

The SDK is built with:

- **Event batching**: Events are queued locally and sent in batches every 30 seconds
- **Offline resilience**: Events persist to disk and are sent when connectivity returns
- **Session management**: Automatic session tracking with configurable timeout
- **Thread safety**: All queue operations are thread-safe with NSLock
- **Minimal footprint**: Pure Swift, no external dependencies

## License

MIT License — see [LICENSE](LICENSE) for details.

© 2025 ClickSight — RLK LTD
