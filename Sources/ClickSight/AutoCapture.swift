#if canImport(UIKit)
import UIKit
#endif
import Foundation

/// Handles automatic event capture for app lifecycle, screen views, and crashes
final class AutoCapture {
    
    private weak var clickSight: ClickSightCore?
    private let options: ClickSightOptions
    
    init(clickSight: ClickSightCore, options: ClickSightOptions) {
        self.clickSight = clickSight
        self.options = options
        
        setupLifecycleObservers()
        
        if options.captureScreenViews {
            setupScreenViewSwizzling()
        }
        
        if options.enableCrashReporting {
            setupCrashReporting()
        }
        
        // Track first launch / app update
        trackInstallOrUpdate()
    }
    
    // MARK: - App Lifecycle
    
    private func setupLifecycleObservers() {
        #if canImport(UIKit) && !os(watchOS)
        let center = NotificationCenter.default
        
        if options.captureAppLifecycle {
            center.addObserver(
                self,
                selector: #selector(appDidBecomeActive),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
            
            center.addObserver(
                self,
                selector: #selector(appDidEnterBackground),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )
            
            center.addObserver(
                self,
                selector: #selector(appWillTerminate),
                name: UIApplication.willTerminateNotification,
                object: nil
            )
        }
        #endif
    }
    
    @objc private func appDidBecomeActive() {
        Logger.log("App became active", level: .debug)
        clickSight?.sessionManager.appWillEnterForeground()
        clickSight?.trackInternal("$app_opened", properties: [
            "$from_background": AnyCodable(true)
        ])
    }
    
    @objc private func appDidEnterBackground() {
        Logger.log("App entered background", level: .debug)
        clickSight?.trackInternal("$app_backgrounded", properties: [:])
        clickSight?.sessionManager.appDidEnterBackground()
        clickSight?.eventQueue.persistToDisk()
        clickSight?.eventQueue.flush()
    }
    
    @objc private func appWillTerminate() {
        Logger.log("App will terminate", level: .debug)
        clickSight?.eventQueue.persistToDisk()
    }
    
    // MARK: - First Launch / Update Detection
    
    private func trackInstallOrUpdate() {
        let storage = Storage.shared
        
        if storage.isFirstLaunch {
            clickSight?.trackInternal("$app_installed", properties: [
                "$app_version": AnyCodable(DeviceInfo.shared.appVersion ?? "unknown"),
                "$app_build": AnyCodable(DeviceInfo.shared.appBuild ?? "unknown")
            ])
        } else if storage.appWasUpdated {
            clickSight?.trackInternal("$app_updated", properties: [
                "$app_version": AnyCodable(DeviceInfo.shared.appVersion ?? "unknown"),
                "$previous_version": AnyCodable(storage.lastAppVersion ?? "unknown"),
                "$app_build": AnyCodable(DeviceInfo.shared.appBuild ?? "unknown")
            ])
        }
    }
    
    // MARK: - Screen View Swizzling
    
    private static var swizzled = false
    
    private func setupScreenViewSwizzling() {
        #if canImport(UIKit) && !os(watchOS)
        guard !AutoCapture.swizzled else { return }
        AutoCapture.swizzled = true
        
        let originalSelector = #selector(UIViewController.viewDidAppear(_:))
        let swizzledSelector = #selector(UIViewController.clicksight_viewDidAppear(_:))
        
        guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector) else {
            Logger.log("Failed to set up screen view swizzling", level: .error)
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
        Logger.log("Screen view auto-capture enabled", level: .debug)
        #endif
    }
    
    // MARK: - Crash Reporting
    
    private func setupCrashReporting() {
        NSSetUncaughtExceptionHandler { exception in
            let properties: [String: AnyCodable] = [
                "$exception_name": AnyCodable(exception.name.rawValue),
                "$exception_reason": AnyCodable(exception.reason ?? "unknown"),
                "$exception_stack": AnyCodable(exception.callStackSymbols.joined(separator: "\n"))
            ]
            
            // Try to send crash event synchronously
            ClickSight.track("$app_crashed", properties: properties.mapValues { $0.value })
            ClickSight.flush()
            
            // Give network request a moment to complete
            Thread.sleep(forTimeInterval: 2.0)
        }
        
        Logger.log("Crash reporting enabled", level: .debug)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UIViewController Swizzling Extension

#if canImport(UIKit) && !os(watchOS)
extension UIViewController {
    
    @objc func clicksight_viewDidAppear(_ animated: Bool) {
        // Call original implementation (they're swapped)
        clicksight_viewDidAppear(animated)
        
        // Skip system view controllers
        let className = String(describing: type(of: self))
        let systemPrefixes = [
            "UI", "_UI", "NS", "_NS", "SFSafari", "MFMail", "MFMessage",
            "CK", "CN", "PKPayment", "SLComposeService", "AVPlayerView"
        ]
        
        let isSystem = systemPrefixes.contains { className.hasPrefix($0) }
        if isSystem { return }
        
        // Track screen view
        let screenName = className
            .replacingOccurrences(of: "ViewController", with: "")
            .replacingOccurrences(of: "Controller", with: "")
        
        guard !screenName.isEmpty else { return }
        
        ClickSight.screen(screenName)
    }
}
#endif
