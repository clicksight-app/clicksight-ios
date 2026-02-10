import Foundation

/// Manages user sessions with timeout-based session splitting
final class SessionManager {
    
    private var currentSessionId: String?
    private var sessionStartTime: Date?
    private var lastActivityTime: Date?
    private let timeoutMinutes: Int
    private let onSessionStart: (String) -> Void
    private let onSessionEnd: (String, Int) -> Void
    
    init(
        timeoutMinutes: Int,
        onSessionStart: @escaping (String) -> Void,
        onSessionEnd: @escaping (String, Int) -> Void
    ) {
        self.timeoutMinutes = timeoutMinutes
        self.onSessionStart = onSessionStart
        self.onSessionEnd = onSessionEnd
    }
    
    /// Get the current session ID, starting a new session if needed
    var sessionId: String {
        if let current = currentSessionId, !isSessionExpired {
            lastActivityTime = Date()
            return current
        }
        return startNewSession()
    }
    
    /// Whether the current session has timed out
    private var isSessionExpired: Bool {
        guard let lastActivity = lastActivityTime else { return true }
        let elapsed = Date().timeIntervalSince(lastActivity)
        return elapsed > Double(timeoutMinutes * 60)
    }
    
    /// Start a new session
    @discardableResult
    func startNewSession() -> String {
        // End previous session if one exists
        if let previousId = currentSessionId, let startTime = sessionStartTime {
            let duration = Int(Date().timeIntervalSince(startTime))
            onSessionEnd(previousId, duration)
        }
        
        let newId = "sess_\(UUID().uuidString.lowercased().prefix(12))"
        currentSessionId = newId
        sessionStartTime = Date()
        lastActivityTime = Date()
        
        onSessionStart(newId)
        
        return newId
    }
    
    /// Called when the app goes to background
    func appDidEnterBackground() {
        lastActivityTime = Date()
        Storage.shared.lastSessionEnd = Date()
    }
    
    /// Called when the app comes to foreground
    func appWillEnterForeground() {
        // Check if session expired while in background
        if let lastEnd = Storage.shared.lastSessionEnd {
            let elapsed = Date().timeIntervalSince(lastEnd)
            if elapsed > Double(timeoutMinutes * 60) {
                startNewSession()
            } else {
                lastActivityTime = Date()
            }
        } else {
            startNewSession()
        }
    }
    
    /// End the current session explicitly
    func endSession() {
        guard let sessionId = currentSessionId, let startTime = sessionStartTime else { return }
        let duration = Int(Date().timeIntervalSince(startTime))
        onSessionEnd(sessionId, duration)
        currentSessionId = nil
        sessionStartTime = nil
        lastActivityTime = nil
    }
    
    /// Get current session duration in seconds
    var currentSessionDuration: Int? {
        guard let startTime = sessionStartTime else { return nil }
        return Int(Date().timeIntervalSince(startTime))
    }
}
