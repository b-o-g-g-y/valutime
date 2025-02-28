import Foundation
import Combine

class NotificationSettings: ObservableObject {
    static let shared = NotificationSettings()
    
    // Keys for UserDefaults
    private let inactivityReminderEnabledKey = "inactivityReminderEnabled"
    private let inactivityReminderIntervalKey = "inactivityReminderInterval"
    private let longSessionReminderEnabledKey = "longSessionReminderEnabled"
    private let longSessionReminderIntervalKey = "longSessionReminderInterval"
    
    // Published properties for SwiftUI binding
    @Published var inactivityReminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(inactivityReminderEnabled, forKey: inactivityReminderEnabledKey)
            print("📱 Saved inactivity reminder enabled: \(inactivityReminderEnabled)")
        }
    }
    
    @Published var inactivityReminderInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(inactivityReminderInterval, forKey: inactivityReminderIntervalKey)
            print("📱 Saved inactivity reminder interval: \(inactivityReminderInterval) seconds")
        }
    }
    
    @Published var longSessionReminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(longSessionReminderEnabled, forKey: longSessionReminderEnabledKey)
            print("📱 Saved long session reminder enabled: \(longSessionReminderEnabled)")
        }
    }
    
    @Published var longSessionReminderInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(longSessionReminderInterval, forKey: longSessionReminderIntervalKey)
            print("📱 Saved long session reminder interval: \(longSessionReminderInterval) seconds")
        }
    }
    
    // Default values
    private let defaultInactivityReminderEnabled = true
    private let defaultInactivityReminderInterval: TimeInterval = 30 * 60 // 30 minutes
    private let defaultLongSessionReminderEnabled = true
    private let defaultLongSessionReminderInterval: TimeInterval = 60 * 60 // 1 hour
    
    // Interval options for UI
    let inactivityIntervalOptions: [(label: String, value: TimeInterval)] = [
        ("1 minute", 1 * 60),
        ("5 minutes", 5 * 60),
        ("15 minutes", 15 * 60),
        ("30 minutes", 30 * 60),
        ("1 hour", 60 * 60),
        ("2 hours", 2 * 60 * 60),
        ("4 hours", 4 * 60 * 60)
    ]
    
    let longSessionIntervalOptions: [(label: String, value: TimeInterval)] = [
        ("1 minute", 1 * 60),
        ("5 minutes", 5 * 60),
        ("15 minutes", 15 * 60),
        ("30 minutes", 30 * 60),
        ("1 hour", 60 * 60),
        ("2 hours", 2 * 60 * 60),
        ("4 hours", 4 * 60 * 60),
        ("8 hours", 8 * 60 * 60)
    ]
    
    private init() {
        // Load values from UserDefaults or use defaults
        self.inactivityReminderEnabled = UserDefaults.standard.object(forKey: inactivityReminderEnabledKey) as? Bool ?? defaultInactivityReminderEnabled
        
        self.inactivityReminderInterval = UserDefaults.standard.object(forKey: inactivityReminderIntervalKey) as? TimeInterval ?? defaultInactivityReminderInterval
        
        self.longSessionReminderEnabled = UserDefaults.standard.object(forKey: longSessionReminderEnabledKey) as? Bool ?? defaultLongSessionReminderEnabled
        
        self.longSessionReminderInterval = UserDefaults.standard.object(forKey: longSessionReminderIntervalKey) as? TimeInterval ?? defaultLongSessionReminderInterval
        
        print("📱 NotificationSettings initialized:")
        print("   - Inactivity reminder: \(inactivityReminderEnabled ? "enabled" : "disabled"), interval: \(inactivityReminderInterval) seconds")
        print("   - Long session reminder: \(longSessionReminderEnabled ? "enabled" : "disabled"), interval: \(longSessionReminderInterval) seconds")
    }
    
    // Reset to default values
    func resetToDefaults() {
        inactivityReminderEnabled = defaultInactivityReminderEnabled
        inactivityReminderInterval = defaultInactivityReminderInterval
        longSessionReminderEnabled = defaultLongSessionReminderEnabled
        longSessionReminderInterval = defaultLongSessionReminderInterval
        print("📱 Reset notification settings to defaults")
    }
    
    // Get formatted interval string
    func getFormattedInterval(interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")\(minutes > 0 ? " \(minutes) min" : "")"
        } else {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }
    
    // Find the closest interval option
    func findClosestInactivityInterval() -> Int {
        return findClosestInterval(options: inactivityIntervalOptions, target: inactivityReminderInterval)
    }
    
    func findClosestLongSessionInterval() -> Int {
        return findClosestInterval(options: longSessionIntervalOptions, target: longSessionReminderInterval)
    }
    
    private func findClosestInterval(options: [(label: String, value: TimeInterval)], target: TimeInterval) -> Int {
        var closestIndex = 0
        var smallestDifference = Double.greatestFiniteMagnitude
        
        for (index, option) in options.enumerated() {
            let difference = abs(option.value - target)
            if difference < smallestDifference {
                smallestDifference = difference
                closestIndex = index
            }
        }
        
        return closestIndex
    }
} 