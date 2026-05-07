// SmartCartApp.swift — SmartCart/App/SmartCartApp.swift
// App entry point. Handles:
//   • First-launch routing (onboarding vs. home)
//   • P1-6 FIX: NotificationRouter via AppDelegate for deep-link navigation
//     when a push notification is tapped while the app is in background/terminated.

import SwiftUI
import UserNotifications

@main
struct SmartCartApp: App {
    // P1-6: AppDelegate receives UNUserNotificationCenterDelegate callbacks
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

// MARK: — AppDelegate (P1-6)

/// Handles notification taps and routes them to the correct screen via NotificationRouter.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Called when the user taps a notification while the app is in foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    /// Called when the user taps a notification (foreground, background, or terminated launch).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        let info   = response.notification.request.content.userInfo
        let itemID = info["itemID"] as? Int64
        NotificationRouter.shared.route(itemID: itemID)
        completionHandler()
    }
}

// MARK: — NotificationRouter (P1-6)

/// Observable singleton that HomeView listens to for deep-link navigation.
/// When a notification is tapped, this publishes the target itemID so HomeView
/// can scroll to and expand the matching row — no matter which screen is active.
final class NotificationRouter: ObservableObject {
    static let shared = NotificationRouter()
    @Published var pendingItemID: Int64? = nil
    private init() {}

    func route(itemID: Int64?) {
        DispatchQueue.main.async { self.pendingItemID = itemID }
    }
}

// MARK: — RootView

/// Decides whether to show OnboardingView or HomeView based on the
/// onboarding_complete flag in user_settings.
struct RootView: View {
    @State private var onboardingComplete: Bool =
        DatabaseManager.shared.getSetting(key: "onboarding_complete") == "1"

    var body: some View {
        if onboardingComplete {
            HomeView()
        } else {
            OnboardingView {
                DatabaseManager.shared.setSetting(key: "onboarding_complete", value: "1")
                onboardingComplete = true
            }
        }
    }
}
