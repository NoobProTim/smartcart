// DatabaseManager.swift
// Fixed in R1 (P0-1, P1-5, P1-8)
// Patched in Task Ref #2: added updateReplenishmentInferred(itemID:days:)
import Foundation
import SQLite

final class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: Connection?

    private init() {
        // Setup SQLite connection and run migrations
    }

    // MARK: - Replenishment

    /// Updates the inferred replenishment cycle (in days) for a user_item row.
    /// Called from ReceiptReviewViewModel Step 5 and HomeViewModel after manual purchase.
    /// All SQL stays inside DatabaseManager — never call db.run() from a ViewModel.
    func updateReplenishmentInferred(itemID: Int64, days: Int) {
        let sql = "UPDATE user_items SET replenishment_inferred = ? WHERE item_id = ? AND is_active = 1"
        try? db?.run(sql, days, itemID)
    }
}
