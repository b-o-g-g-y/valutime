import Foundation
import UserNotifications
import UIKit

class TimerManager: ObservableObject {
    static let shared = TimerManager()
    
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var currentSession: ActivitySession?
    @Published var elapsedTime: TimeInterval = 0
    @Published var currentEarnings: Double = 0
    @Published var pausedTime: Date?
    @Published var hourlyRate: Double = 0
    
    private var timer: Timer?
    private var backgroundDate: Date?
    
    // Notification identifiers
    private let inactivityReminderIdentifier = "inactivityReminder"
    private let longSessionReminderIdentifier = "longSessionReminder"
    private let backgroundTrackingIdentifier = "trackingNotification"
    
    // Last time inactivity notification was sent
    private var lastInactivityNotificationTime: Date?
    
    // Timer for checking long sessions
    private var longSessionCheckTimer: Timer?
    
    private init() {
        // Request notification permissions
        requestNotificationPermissions()
        
        // Check for any active sessions when app starts
        checkForActiveSessions()
        
        // Set up notification for when app enters background
        NotificationCenter.default.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        // Set up notification for when app comes to foreground
        NotificationCenter.default.addObserver(self, selector: #selector(appMovedToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        longSessionCheckTimer?.invalidate()
    }
    
    // Request notification permissions
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("❌ Error requesting notification permissions: \(error)")
            } else if granted {
                print("✅ Notification permissions granted in TimerManager")
            } else {
                print("⚠️ Notification permissions denied in TimerManager")
            }
        }
    }
    
    // Check for any active sessions when app starts
    private func checkForActiveSessions() {
        let activeSessions = CoreDataManager.shared.getActiveSessions()
        if let activeSession = activeSessions.first {
            self.currentSession = activeSession
            
            // Check if the session is paused
            if activeSession.isPaused {
                self.isPaused = true
                self.pausedTime = activeSession.pauseTime
                print("📝 Found paused session for activity: \(activeSession.activity?.name ?? "Unknown")")
            } else {
                self.isRunning = true
                
                // Start the timer
                startTimer()
                
                // Schedule long session reminder if enabled
                if NotificationSettings.shared.longSessionReminderEnabled {
                    scheduleLongSessionReminder()
                }
                
                print("📝 Resumed active session for activity: \(activeSession.activity?.name ?? "Unknown")")
            }
            
            // Get the hourly rate for this session
            if let activity = activeSession.activity, let project = activity.project {
                self.hourlyRate = project.hourlyRate
            } else {
                // Use default hourly rate if no project is associated
                self.hourlyRate = CoreDataManager.shared.getUser()?.defaultHourlyRate ?? 0
            }
        } else {
            // No active session, schedule inactivity reminder if enabled
            if NotificationSettings.shared.inactivityReminderEnabled {
                scheduleInactivityReminder()
                print("⏰ Scheduled inactivity reminder on app start")
            }
        }
    }
    
    // Start tracking time for an activity
    func startTracking(activity: Activity) {
        print("▶️ Starting tracking for activity: \(activity.name ?? "Unknown")")
        
        // Stop any current tracking
        if isRunning {
            stopTracking()
        }
        
        // Create a new session
        let session = CoreDataManager.shared.createActivitySession(activity: activity, startTime: Date())
        self.currentSession = session
        
        // Set the hourly rate - prioritize activity's rate if available
        if activity.hourlyRate > 0 {
            self.hourlyRate = activity.hourlyRate
        } else if let project = activity.project, project.hourlyRate > 0 {
            self.hourlyRate = project.hourlyRate
        } else {
            // Use default hourly rate if no specific rate is available
            self.hourlyRate = CoreDataManager.shared.getUser()?.defaultHourlyRate ?? 0
        }
        
        // Start the timer
        isRunning = true
        startTimer()
        
        // Cancel any inactivity reminders
        cancelInactivityReminder()
        
        // Schedule a notification for background tracking
        scheduleTrackingNotification(activity: activity)
        
        // Schedule long session reminder if enabled
        if NotificationSettings.shared.longSessionReminderEnabled {
            scheduleLongSessionReminder()
        }
    }
    
    // Pause tracking time
    func pauseTracking() {
        guard isRunning, !isPaused, let session = currentSession else { return }
        
        print("⏸️ Pausing tracking for activity: \(session.activity?.name ?? "Unknown")")
        
        // Stop the timer but keep the session
        isPaused = true
        stopTimer()
        
        // Store the pause time
        pausedTime = Date()
        
        // Cancel long session reminder while paused
        cancelLongSessionReminder()
        
        // Update the session in Core Data to mark it as paused
        CoreDataManager.shared.updateActivitySession(session, isPaused: true, pauseTime: pausedTime)
    }
    
    // Resume tracking time
    func resumeTracking() {
        guard let session = currentSession else { return }
        
        print("▶️ Resuming tracking for activity: \(session.activity?.name ?? "Unknown")")
        
        // Calculate additional time that passed during pause
        if let pauseTime = session.pauseTime ?? self.pausedTime, let startTime = session.startTime {
            let pauseDuration = Date().timeIntervalSince(pauseTime)
            
            // Adjust the start time to account for the pause
            let newStartTime = startTime.addingTimeInterval(pauseDuration)
            CoreDataManager.shared.updateActivitySession(session, startTime: newStartTime, isPaused: false, pauseTime: nil)
        }
        
        // Reset pause state
        isPaused = false
        pausedTime = nil
        
        // Set running state
        isRunning = true
        
        // Restart the timer
        startTimer()
        
        // Schedule long session reminder if enabled
        if NotificationSettings.shared.longSessionReminderEnabled {
            scheduleLongSessionReminder()
        }
    }
    
    // Resume a specific paused session
    func resumePausedSession(_ session: ActivitySession) {
        // Stop any current tracking
        if isRunning {
            stopTracking()
        }
        
        // Set this session as the current session
        currentSession = session
        
        // Resume tracking
        resumeTracking()
    }
    
    // Stop tracking time
    func stopTracking(notes: String? = nil) {
        guard let session = currentSession else { return }
        
        print("⏹️ Stopping tracking for activity: \(session.activity?.name ?? "Unknown")")
        
        // End the session
        CoreDataManager.shared.endActivitySession(session, endTime: Date(), notes: notes)
        
        // Stop the timer
        isRunning = false
        isPaused = false
        stopTimer()
        
        // Reset values
        currentSession = nil
        elapsedTime = 0
        currentEarnings = 0
        pausedTime = nil
        
        // Remove any scheduled notifications
        cancelLongSessionReminder()
        
        // Schedule inactivity reminder if enabled
        if NotificationSettings.shared.inactivityReminderEnabled {
            scheduleInactivityReminder()
        }
    }
    
    // Start the timer
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let session = self.currentSession, let startTime = session.startTime else { return }
            
            // Calculate elapsed time
            self.elapsedTime = Date().timeIntervalSince(startTime)
            
            // Calculate current earnings
            self.currentEarnings = TimeCalculator.calculateEarnings(hourlyRate: self.hourlyRate, timeSpentInSeconds: self.elapsedTime)
        }
    }
    
    // Stop the timer
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        longSessionCheckTimer?.invalidate()
        longSessionCheckTimer = nil
    }
    
    // App moved to background
    @objc private func appMovedToBackground() {
        // Store the current date when app moves to background
        backgroundDate = Date()
        print("📱 App moved to background")
        
        // When app goes to background, we need to schedule local notifications
        // since our in-app timers won't run reliably
        if isRunning {
            if NotificationSettings.shared.longSessionReminderEnabled {
                // Schedule a local notification for long session check
                scheduleLongSessionLocalNotification()
            }
        } else {
            if NotificationSettings.shared.inactivityReminderEnabled {
                // Schedule a local notification for inactivity reminder
                scheduleInactivityLocalNotification()
            }
        }
    }
    
    // App moved to foreground
    @objc private func appMovedToForeground() {
        guard let backgroundDate = backgroundDate else { return }
        
        print("📱 App moved to foreground")
        
        if isRunning {
            // Calculate time spent in background
            let timeInBackground = Date().timeIntervalSince(backgroundDate)
            
            // Update elapsed time
            if let startTime = currentSession?.startTime {
                elapsedTime = Date().timeIntervalSince(startTime)
                
                // Update current earnings
                currentEarnings = TimeCalculator.calculateEarnings(hourlyRate: hourlyRate, timeSpentInSeconds: elapsedTime)
                
                print("⏱️ Updated elapsed time after background: \(elapsedTime) seconds")
            }
        } else {
            // If not tracking, check if we need to schedule an inactivity reminder
            if NotificationSettings.shared.inactivityReminderEnabled {
                scheduleInactivityReminder()
                print("⏰ Rescheduled inactivity reminder on return to foreground")
            }
        }
        
        // Reset background date
        self.backgroundDate = nil
    }
    
    // MARK: - Notification Methods
    
    // Schedule a notification for background tracking
    private func scheduleTrackingNotification(activity: Activity) {
        let content = UNMutableNotificationContent()
        content.title = "ValuTime - Tracking Active"
        content.body = "Currently tracking: \(activity.name ?? "Activity")"
        content.sound = UNNotificationSound.default
        
        // Show notification after 1 hour if app is still in background
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
        
        let request = UNNotificationRequest(identifier: backgroundTrackingIdentifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling tracking notification: \(error)")
            } else {
                print("✅ Scheduled tracking notification for \(activity.name ?? "Activity")")
            }
        }
    }
    
    // Schedule inactivity reminder
    private func scheduleInactivityReminder() {
        // Don't schedule if tracking is active
        if isRunning { return }
        
        print("⏰ Attempting to schedule inactivity reminder")
        
        // Check if we've recently sent a notification
        if let lastTime = lastInactivityNotificationTime {
            let timeSinceLastNotification = Date().timeIntervalSince(lastTime)
            if timeSinceLastNotification < NotificationSettings.shared.inactivityReminderInterval {
                // Schedule for the remaining time
                let remainingTime = NotificationSettings.shared.inactivityReminderInterval - timeSinceLastNotification
                scheduleInactivityReminderWithDelay(delay: remainingTime)
                print("⏰ Scheduling inactivity reminder with remaining time: \(remainingTime) seconds")
                return
            }
        }
        
        // Schedule with the full interval
        let interval = NotificationSettings.shared.inactivityReminderInterval
        scheduleInactivityReminderWithDelay(delay: interval)
        print("⏰ Scheduling inactivity reminder with full interval: \(interval) seconds")
    }
    
    private func scheduleInactivityReminderWithDelay(delay: TimeInterval) {
        // For in-app reminders, use a timer
        DispatchQueue.main.async {
            Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                guard let self = self, !self.isRunning else { return }
                
                print("⏰ In-app inactivity reminder triggered")
                
                // Show a local notification if the app is in the background
                if UIApplication.shared.applicationState != .active {
                    self.scheduleInactivityLocalNotification(withDelay: 1) // Small delay to ensure it shows
                } else {
                    // If app is active, show an in-app alert or banner
                    self.showInAppInactivityReminder()
                }
                
                // Update the last notification time
                self.lastInactivityNotificationTime = Date()
                
                // Schedule the next reminder
                self.scheduleInactivityReminder()
            }
        }
    }
    
    private func scheduleInactivityLocalNotification(withDelay delay: TimeInterval = 0) {
        let content = UNMutableNotificationContent()
        content.title = "ValuTime - No Activity Tracking"
        content.body = "You haven't been tracking any activity. Start tracking to log your time!"
        content.sound = UNNotificationSound.default
        
        // Add action to open app
        content.categoryIdentifier = "INACTIVITY_REMINDER"
        
        // Create the trigger with the specified delay
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        
        // Create the request with a unique identifier based on time
        let identifier = "\(inactivityReminderIdentifier)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        // Schedule the notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling inactivity local notification: \(error)")
            } else {
                print("✅ Scheduled inactivity local notification with ID: \(identifier)")
            }
        }
    }
    
    private func showInAppInactivityReminder() {
        // This would typically show an in-app alert or banner
        // For now, we'll just post a notification that other parts of the app can observe
        NotificationCenter.default.post(name: NSNotification.Name("InactivityReminderTriggered"), object: nil)
        print("📲 Posted in-app inactivity reminder notification")
    }
    
    // Cancel inactivity reminder
    private func cancelInactivityReminder() {
        // Cancel any pending local notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [inactivityReminderIdentifier])
        print("🚫 Cancelled inactivity reminders")
    }
    
    // Schedule long session reminder
    private func scheduleLongSessionReminder() {
        guard isRunning, let activity = currentSession?.activity else { return }
        
        print("⏱️ Setting up long session reminder for \(activity.name ?? "Activity")")
        
        // Cancel any existing timer
        longSessionCheckTimer?.invalidate()
        
        // Create a timer that will fire after the specified interval
        let interval = NotificationSettings.shared.longSessionReminderInterval
        longSessionCheckTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self = self, self.isRunning else { return }
            
            print("⏱️ Long session check timer fired for \(activity.name ?? "Activity")")
            
            // Show a local notification if the app is in the background
            if UIApplication.shared.applicationState != .active {
                self.scheduleLongSessionLocalNotification(withDelay: 1) // Small delay to ensure it shows
            } else {
                // If app is active, show an in-app alert or banner
                self.showInAppLongSessionReminder()
            }
        }
    }
    
    private func scheduleLongSessionLocalNotification(withDelay delay: TimeInterval = 0) {
        guard let activity = currentSession?.activity else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "ValuTime - Long Session Check"
        content.body = "You've been tracking \(activity.name ?? "an activity") for a while. Are you still working on it?"
        content.sound = UNNotificationSound.default
        
        // Add actions
        content.categoryIdentifier = "LONG_SESSION_CHECK"
        
        // Create the trigger with the specified delay
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        
        // Create the request with a unique identifier based on time
        let identifier = "\(longSessionReminderIdentifier)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        // Schedule the notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling long session local notification: \(error)")
            } else {
                print("✅ Scheduled long session local notification with ID: \(identifier)")
                
                // Schedule the next check if the user doesn't respond
                DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
                    guard let self = self, self.isRunning else { return }
                    self.scheduleLongSessionReminder()
                }
            }
        }
    }
    
    private func showInAppLongSessionReminder() {
        // This would typically show an in-app alert or banner
        // For now, we'll just post a notification that other parts of the app can observe
        NotificationCenter.default.post(name: NSNotification.Name("LongSessionReminderTriggered"), object: nil)
        print("📲 Posted in-app long session reminder notification")
        
        // Schedule the next check
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self = self, self.isRunning else { return }
            self.scheduleLongSessionReminder()
        }
    }
    
    // Cancel long session reminder
    private func cancelLongSessionReminder() {
        // Cancel the timer
        longSessionCheckTimer?.invalidate()
        longSessionCheckTimer = nil
        
        // Cancel any pending local notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [longSessionReminderIdentifier])
        print("🚫 Cancelled long session reminders")
    }
    
    // Handle notification response
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        print("👆 Handling notification response: \(response.actionIdentifier)")
        
        switch response.actionIdentifier {
        case "STILL_WORKING":
            // User is still working, reschedule the long session reminder
            if isRunning && NotificationSettings.shared.longSessionReminderEnabled {
                scheduleLongSessionReminder()
                print("🔄 Rescheduled long session reminder after 'Still Working' response")
            }
            
        case "STOP_TRACKING":
            // User wants to stop tracking
            if isRunning {
                stopTracking()
                print("⏹️ Stopped tracking after notification response")
            }
            
        case "START_TRACKING":
            // User wants to start tracking, app will open to the timer view
            print("▶️ User wants to start tracking from notification")
            // The app will navigate to the timer view
            
        default:
            print("ℹ️ Default notification response handling for: \(response.actionIdentifier)")
            break
        }
    }
    
    // Get formatted elapsed time
    func getFormattedElapsedTime() -> String {
        return TimeCalculator.formatTimeInterval(elapsedTime)
    }
    
    // Get formatted current earnings
    func getFormattedCurrentEarnings(currencyCode: String = "USD") -> String {
        return TimeCalculator.formatCurrency(currentEarnings, currencyCode: currencyCode)
    }
} 