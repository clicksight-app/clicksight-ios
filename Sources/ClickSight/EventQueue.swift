import Foundation

/// Manages the event queue — batching events locally and flushing to the API on a timer
final class EventQueue {
    
    private var events: [ClickSightEvent] = []
    private let lock = NSLock()
    private var flushTimer: Timer?
    private let networkManager: NetworkManager
    private let maxBatchSize: Int
    private let maxQueueSize: Int
    private let flushInterval: Int
    private var isFlushing = false
    
    init(networkManager: NetworkManager, maxBatchSize: Int, maxQueueSize: Int, flushInterval: Int) {
        self.networkManager = networkManager
        self.maxBatchSize = maxBatchSize
        self.maxQueueSize = maxQueueSize
        self.flushInterval = flushInterval
        
        // Load any persisted events from previous session
        self.events = Storage.shared.loadEventQueue()
        
        startFlushTimer()
    }
    
    // MARK: - Add Event
    
    /// Add an event to the queue
    func enqueue(_ event: ClickSightEvent) {
        lock.lock()
        defer { lock.unlock() }
        
        events.append(event)
        
        // Drop oldest events if we exceed max queue size
        if events.count > maxQueueSize {
            let overflow = events.count - maxQueueSize
            events.removeFirst(overflow)
            Logger.log("Queue overflow — dropped \(overflow) oldest events", level: .warning)
        }
        
        // Persist to disk
        Storage.shared.saveEventQueue(events)
        
        Logger.log("Event queued: \(event.event) (queue size: \(events.count))", level: .debug)
        
        // Auto-flush if we've hit the batch size
        if events.count >= maxBatchSize {
            flush()
        }
    }
    
    // MARK: - Flush
    
    /// Flush all queued events to the API
    func flush() {
        lock.lock()
        
        guard !isFlushing, !events.isEmpty else {
            lock.unlock()
            return
        }
        
        isFlushing = true
        
        // Take a batch of events
        let batchSize = min(events.count, maxBatchSize)
        let batch = Array(events.prefix(batchSize))
        
        lock.unlock()
        
        Logger.log("Flushing \(batch.count) events...", level: .debug)
        
        networkManager.sendBatch(batch) { [weak self] success in
            guard let self = self else { return }
            
            self.lock.lock()
            defer {
                self.isFlushing = false
                self.lock.unlock()
            }
            
            if success {
                // Remove sent events from queue
                self.events.removeFirst(min(batchSize, self.events.count))
                Storage.shared.saveEventQueue(self.events)
                Logger.log("Flush successful — \(batch.count) events sent, \(self.events.count) remaining", level: .debug)
                
                // If there are more events, flush again
                if !self.events.isEmpty {
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1) { [weak self] in
                        self?.flush()
                    }
                }
            } else {
                Logger.log("Flush failed — \(batch.count) events kept in queue for retry", level: .warning)
                // Events stay in queue for retry on next flush
            }
        }
    }
    
    // MARK: - Timer
    
    private func startFlushTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.flushTimer?.invalidate()
            self.flushTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(self.flushInterval), repeats: true) { [weak self] _ in
                self?.flush()
            }
        }
    }
    
    /// Stop the flush timer (called on app termination)
    func stopTimer() {
        flushTimer?.invalidate()
        flushTimer = nil
    }
    
    /// Persist current queue to disk (called on app background)
    func persistToDisk() {
        lock.lock()
        defer { lock.unlock() }
        Storage.shared.saveEventQueue(events)
    }
    
    /// Number of events currently in queue
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return events.count
    }
    
    /// Clear all queued events
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        events.removeAll()
        Storage.shared.clearEventQueue()
    }
}
