//
//  ValueTimeApp.swift
//  ValueTime
//
//  Created by Bogdan on 2/28/25.
//

import SwiftUI
import CoreData
import UserNotifications

@main
struct ValueTimeApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject private var timerManager = TimerManager.shared
    
    init() {
        // Request notification permissions with more robust handling
        requestNotificationPermissions()
        
        // Create default user if needed
        _ = CoreDataManager.shared.getUser()
        
        // Set up appearance
        setupAppearance()
    }
    
    private func requestNotificationPermissions() {
        // First check current authorization status
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("Current notification settings: \(settings.authorizationStatus.rawValue)")
            
            switch settings.authorizationStatus {
            case .notDetermined:
                // Request permissions if not determined yet
                self.requestNewPermissions()
            case .denied:
                // Alert the user that notifications are disabled
                print("⚠️ Notifications are disabled. User needs to enable them in Settings")
            case .authorized, .provisional, .ephemeral:
                print("✅ Notifications are authorized")
            @unknown default:
                // Request permissions for any unknown status
                self.requestNewPermissions()
            }
        }
    }
    
    private func requestNewPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
                
                // Register notification categories for actions
                self.registerNotificationCategories()
            } else if let error = error {
                print("❌ Notification permission error: \(error)")
            } else {
                print("❌ Notification permission denied by user")
            }
        }
    }
    
    private func registerNotificationCategories() {
        // Create the custom actions for inactivity reminder
        let startTrackingAction = UNNotificationAction(
            identifier: "START_TRACKING",
            title: "Start Tracking",
            options: .foreground
        )
        
        // Define the inactivity reminder category
        let inactivityCategory = UNNotificationCategory(
            identifier: "INACTIVITY_REMINDER",
            actions: [startTrackingAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Create the custom actions for long session check
        let stillWorkingAction = UNNotificationAction(
            identifier: "STILL_WORKING",
            title: "Still Working",
            options: .foreground
        )
        
        let stopTrackingAction = UNNotificationAction(
            identifier: "STOP_TRACKING",
            title: "Stop Tracking",
            options: .foreground
        )
        
        // Define the long session check category
        let longSessionCategory = UNNotificationCategory(
            identifier: "LONG_SESSION_CHECK",
            actions: [stillWorkingAction, stopTrackingAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Register the categories
        UNUserNotificationCenter.current().setNotificationCategories([inactivityCategory, longSessionCategory])
        print("✅ Notification categories registered")
    }
    
    private func setupAppearance() {
        // Set up navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(ColorTheme.primary)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Set up tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.systemBackground
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
                .environmentObject(timerManager)
                .onAppear {
                    checkNotificationStatus()
                }
        }
    }
    
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                print("📱 Notification settings: \(settings.authorizationStatus.rawValue)")
                
                // If not determined, request permissions
                if settings.authorizationStatus == .notDetermined {
                    self.requestNotificationPermissions()
                } else if settings.authorizationStatus == .denied {
                    print("⚠️ Notifications are disabled. User should enable them in settings.")
                } else if settings.authorizationStatus == .authorized {
                    print("✅ Notifications are authorized")
                    
                    // For debugging, check pending notifications
                    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                        print("📝 Pending notifications: \(requests.count)")
                        for request in requests {
                            print("   - \(request.identifier): \(request.content.title)")
                        }
                    }
                }
            }
        }
    }
}

// App Delegate to handle notification responses
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Set the notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        print("📱 App launched")
        return true
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("📱 Received notification in foreground: \(notification.request.identifier)")
        
        // Show the notification even when the app is in the foreground
        completionHandler([.banner, .sound])
    }
    
    // Handle notification response
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("📱 Handling notification response: \(response.actionIdentifier)")
        
        // Pass the response to the timer manager
        TimerManager.shared.handleNotificationResponse(response)
        
        completionHandler()
    }
}
