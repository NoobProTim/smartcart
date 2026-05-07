// AlertLog.swift
import Foundation

struct AlertLog: Identifiable, Codable {
    let id: Int64
    var userItemId: Int64
    var alertType: String   // A: Historical Low, B: Sale Alert, C: Expiry Reminder
    var triggeredAt: Date
    var saleEventId: Int64?
    var dismissed: Bool
}
