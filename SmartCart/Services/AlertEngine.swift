// AlertEngine.swift — SmartCart/Services/AlertEngine.swift
// Evaluates whether a tracked item deserves a price alert and fires it.
// Called by BackgroundSyncManager after every Flipp sync.
//
// Alert types:
//   historical_low — regular shelf price is the lowest ever recorded (90-day window)
//   sale           — active flyer sale at a user-selected store
//   expiry         — active sale expires within 24 h AND item is in restock window
//
// Daily cap: max Constants.maxDailyAlerts across all items (default 3).
// Dedup: one alert per (item, type) per calendar day.

import Foundation
import UserNotifications

final class AlertEngine {
    static let shared = AlertEngine()
    private init() {}

    /// Run the full alert evaluation for all user items.
    func evaluate() async {
        guard DatabaseManager.shared.todayAlertCount() < Constants.maxDailyAlerts else { return }
        let items = DatabaseManager.shared.loadUserItems()
        for item in items where item.isInRestockWindow {
            await evaluateItem(item)
            if DatabaseManager.shared.todayAlertCount() >= Constants.maxDailyAlerts { break }
        }
    }

    private func evaluateItem(_ item: UserItem) async {
        // Placeholder: real price comparison logic wired in Sprint 2
        // For now, log intent without firing a real notification
        print("[AlertEngine] Evaluating \(item.nameDisplay)")
    }

    /// Schedule a local notification and log it to alert_log.
    func fireAlert(itemID: Int64, type: String, price: Double, title: String, body: String) {
        let notifID = "alert-\(type)-\(itemID)"
        DatabaseManager.shared.logAlert(itemID: itemID, alertType: type,
                                        triggerPrice: price, notificationID: notifID)

        let content      = UNMutableNotificationContent()
        content.title    = title
        content.body     = body
        content.sound    = .default
        content.userInfo = ["itemID": itemID, "alertType": type]

        let trigger  = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request  = UNNotificationRequest(identifier: notifID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("[AlertEngine] Notification error: \(error)") }
        }
    }
}
