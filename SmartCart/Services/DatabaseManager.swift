// DatabaseManager.swift — SmartCart/Services/DatabaseManager.swift
// Central SQLite interface. ALL database reads and writes go through here.
// Uses SQLite.swift library. Singleton: DatabaseManager.shared
//
// P0-1 FIX: markPurchased() is now a single atomic transaction — it writes
//   purchase_history AND updates user_items.last_purchased_* in one BEGIN/COMMIT.
//   Previously the two writes were separate, which could leave user_items stale
//   if the app crashed between them.
//
// P1-5 FIX: loadUserItems() now sets UserItem.hasActiveAlert by joining alert_log
//   for today's date — the home-screen alert dot is now driven by real data.
//
// P1-8 FIX: insertFlyerSale() uses INSERT OR IGNORE; a unique index on
//   (item_id, store_id, sale_start_date, sale_price) prevents duplicate rows
//   accumulating on every daily sync.

import Foundation
import SQLite

final class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: Connection!

    // Table handles
    private let stores         = Table("stores")
    private let items          = Table("items")
    private let userItems      = Table("user_items")
    private let purchaseHist   = Table("purchase_history")
    private let priceHist      = Table("price_history")
    private let flyerSales     = Table("flyer_sales")
    private let alertLog       = Table("alert_log")
    private let userSettings   = Table("user_settings")

    // Column expressions
    private let colID              = Expression<Int64>("id")
    private let colItemID          = Expression<Int64>("item_id")
    private let colStoreID         = Expression<Int64>("store_id")
    private let colName            = Expression<String>("name")
    private let colNameNorm        = Expression<String>("name_normalised")
    private let colNameDisplay     = Expression<String>("name_display")
    private let colFlippID         = Expression<String?>("flipp_id")
    private let colIsSelected      = Expression<Bool>("is_selected")
    private let colLastSyncedAt    = Expression<Date?>("last_synced_at")
    private let colCategory        = Expression<String?>("category")
    private let colUnit            = Expression<String?>("unit")
    private let colCreatedAt       = Expression<Date>("created_at")
    private let colPrice           = Expression<Double>("price")
    private let colSalePrice       = Expression<Double>("sale_price")
    private let colObservedAt      = Expression<Date>("observed_at")
    private let colSource          = Expression<String>("source")
    private let colPurchasedAt     = Expression<Date>("purchased_at")
    private let colLastPurchDate   = Expression<Date?>("last_purchased_date")
    private let colLastPurchPrice  = Expression<Double?>("last_purchased_price")
    private let colInfCycleDays    = Expression<Int?>("inferred_cycle_days")
    private let colOverCycleDays   = Expression<Int?>("user_override_cycle_days")
    private let colNextRestock     = Expression<Date?>("next_restock_date")
    private let colValidFrom       = Expression<Date>("sale_start_date")
    private let colValidTo         = Expression<Date?>("sale_end_date")
    private let colFetchedAt       = Expression<Date>("fetched_at")
    private let colAlertType       = Expression<String>("alert_type")
    private let colTriggerPrice    = Expression<Double>("trigger_price")
    private let colFiredAt         = Expression<Date>("fired_at")
    private let colNotifID         = Expression<String?>("notification_id")
    private let colKey             = Expression<String>("key")
    private let colValue           = Expression<String>("value")

    private init() {
        do {
            // Store the database in the app's Documents directory so it persists
            // between launches and is excluded from iCloud backup by default.
            let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let dbURL  = docDir.appendingPathComponent("smartcart.sqlite")
            db = try Connection(dbURL.path)
            db.busyTimeout = 5       // Wait up to 5 s if another thread holds a lock
            db.busyHandler { _ in true }
            try createTables()
        } catch {
            fatalError("[DatabaseManager] Failed to open database: \(error)")
        }
    }

    // MARK: — Schema

    private func createTables() throws {
        // stores
        try db.run(stores.create(ifNotExists: true) { t in
            t.column(colID, primaryKey: .autoincrement)
            t.column(colName, unique: true)
            t.column(colFlippID)
            t.column(colIsSelected, defaultValue: false)
            t.column(colLastSyncedAt)
        })

        // items
        try db.run(items.create(ifNotExists: true) { t in
            t.column(colID, primaryKey: .autoincrement)
            t.column(colNameNorm, unique: true)
            t.column(colNameDisplay)
            t.column(colCategory)
            t.column(colUnit)
            t.column(colCreatedAt, defaultValue: Date())
        })

        // user_items
        try db.run(userItems.create(ifNotExists: true) { t in
            t.column(colID, primaryKey: .autoincrement)
            t.column(colItemID, unique: true, references: items, colID)
            t.column(colLastPurchDate)
            t.column(colLastPurchPrice)
            t.column(colInfCycleDays)
            t.column(colOverCycleDays)
            t.column(colNextRestock)
        })

        // purchase_history
        try db.run(purchaseHist.create(ifNotExists: true) { t in
            t.column(colID, primaryKey: .autoincrement)
            t.column(colItemID, references: items, colID)
            t.column(colPurchasedAt)
            t.column(colPrice)
            t.column(colSource)
            t.column(colStoreID)
        })

        // price_history
        try db.run(priceHist.create(ifNotExists: true) { t in
            t.column(colID, primaryKey: .autoincrement)
            t.column(colItemID, references: items, colID)
            t.column(colStoreID, references: stores, colID)
            t.column(colPrice)
            t.column(colObservedAt)
            t.column(colSource)
        })

        // flyer_sales — P1-8: unique index prevents duplicate rows on re-sync
        try db.run(flyerSales.create(ifNotExists: true) { t in
            t.column(colID, primaryKey: .autoincrement)
            t.column(colItemID, references: items, colID)
            t.column(colStoreID, references: stores, colID)
            t.column(colSalePrice)
            t.column(colValidFrom)
            t.column(colValidTo)
            t.column(colSource)
            t.column(colFetchedAt)
            t.unique(colItemID, colStoreID, colValidFrom, colSalePrice)  // P1-8
        })

        // alert_log
        try db.run(alertLog.create(ifNotExists: true) { t in
            t.column(colID, primaryKey: .autoincrement)
            t.column(colItemID, references: items, colID)
            t.column(colAlertType)
            t.column(colTriggerPrice)
            t.column(colFiredAt)
            t.column(colNotifID)
        })

        // user_settings — generic key-value store for preferences
        try db.run(userSettings.create(ifNotExists: true) { t in
            t.column(colKey, primaryKey: true)
            t.column(colValue)
        })
    }

    // MARK: — Stores

    /// Insert or update a store row. Returns the store's row ID.
    @discardableResult
    func upsertStore(name: String) -> Int64 {
        do {
            let existing = stores.filter(colName == name)
            if let row = try db.pluck(existing) { return row[colID] }
            return try db.run(stores.insert(colName <- name, colIsSelected <- false))
        } catch {
            print("[DatabaseManager] upsertStore error: \(error)"); return -1
        }
    }

    func loadSelectedStores() -> [Store] {
        do {
            return try db.prepare(stores.filter(colIsSelected == true)).map {
                Store(id: $0[colID], name: $0[colName], flippID: $0[colFlippID],
                      isSelected: $0[colIsSelected], lastSyncedAt: $0[colLastSyncedAt])
            }
        } catch { print("[DatabaseManager] loadSelectedStores error: \(error)"); return [] }
    }

    // MARK: — Items

    /// Insert or update an item. Returns the item's row ID.
    @discardableResult
    func upsertItem(normalisedName: String, displayName: String, unit: String? = nil) -> Int64 {
        do {
            let existing = items.filter(colNameNorm == normalisedName)
            if let row = try db.pluck(existing) {
                try db.run(existing.update(colNameDisplay <- displayName))
                return row[colID]
            }
            return try db.run(items.insert(
                colNameNorm    <- normalisedName,
                colNameDisplay <- displayName,
                colUnit        <- unit,
                colCreatedAt   <- Date()
            ))
        } catch {
            print("[DatabaseManager] upsertItem error: \(error)"); return -1
        }
    }

    // MARK: — UserItems

    /// Load all user-tracked items. Joins alert_log to populate hasActiveAlert (P1-5 fix).
    func loadUserItems() -> [UserItem] {
        do {
            // Determine the calendar day boundaries for today's alert check
            let cal       = Calendar.current
            let startOfDay = cal.startOfDay(for: Date())
            let endOfDay   = cal.date(byAdding: .day, value: 1, to: startOfDay)!

            // Fetch all item IDs that fired an alert today
            let todayAlerts = try db.prepare(
                alertLog.filter(colFiredAt >= startOfDay && colFiredAt < endOfDay)
                        .select(colItemID)
            ).map { $0[colItemID] }
            let alertedSet = Set(todayAlerts)

            return try db.prepare(userItems.join(items, on: colItemID == items[colID])).map { row in
                UserItem(
                    id:                   row[userItems[colID]],
                    itemID:               row[colItemID],
                    nameDisplay:          row[colNameDisplay],
                    lastPurchasedDate:    row[colLastPurchDate],
                    lastPurchasedPrice:   row[colLastPurchPrice],
                    inferredCycleDays:    row[colInfCycleDays],
                    userOverrideCycleDays: row[colOverCycleDays],
                    nextRestockDate:      row[colNextRestock],
                    hasActiveAlert:       alertedSet.contains(row[colItemID])  // P1-5
                )
            }
        } catch { print("[DatabaseManager] loadUserItems error: \(error)"); return [] }
    }

    // MARK: — Purchase Recording (P0-1: atomic transaction)

    /// Record a confirmed purchase AND update user_items in a single SQLite transaction.
    /// If either write fails, both are rolled back — no stale state possible.
    func markPurchased(itemID: Int64, price: Double?, storeID: Int64?, source: String) throws {
        try db.transaction {                          // P0-1: single atomic block
            // 1. Append to purchase history
            try db.run(purchaseHist.insert(
                colItemID     <- itemID,
                colPurchasedAt <- Date(),
                colPrice      <- price,
                colSource     <- source,
                colStoreID    <- storeID
            ))

            // 2. Recalculate inferred cycle from all purchases for this item
            let history = try db.prepare(
                purchaseHist.filter(colItemID == itemID).order(colPurchasedAt.asc)
            ).map { $0[colPurchasedAt] }

            var inferredCycle: Int? = nil
            if history.count >= 2 {
                var intervals: [Int] = []
                for i in 1..<history.count {
                    let days = Calendar.current.dateComponents([.day], from: history[i-1], to: history[i]).day ?? 0
                    if days > 0 { intervals.append(days) }
                }
                if !intervals.isEmpty {
                    let sorted = intervals.sorted()
                    inferredCycle = sorted[sorted.count / 2]  // Median
                }
            }

            // 3. Compute next restock date
            let defaultCycle = Constants.defaultReplenishmentDays
            let cycle        = inferredCycle ?? defaultCycle
            let nextRestock  = Calendar.current.date(byAdding: .day, value: cycle, to: Date())

            // 4. Update user_items (upsert pattern)
            let existing = userItems.filter(colItemID == itemID)
            if try db.pluck(existing) != nil {
                try db.run(existing.update(
                    colLastPurchDate  <- Date(),
                    colLastPurchPrice <- price,
                    colInfCycleDays   <- inferredCycle,
                    colNextRestock    <- nextRestock
                ))
            } else {
                try db.run(userItems.insert(
                    colItemID        <- itemID,
                    colLastPurchDate  <- Date(),
                    colLastPurchPrice <- price,
                    colInfCycleDays   <- inferredCycle,
                    colNextRestock    <- nextRestock
                ))
            }
        }  // End P0-1 transaction
    }

    // MARK: — Flyer Sales (P1-8: INSERT OR IGNORE)

    /// Insert a flyer sale. Does nothing if an identical row already exists.
    /// Uniqueness is enforced by the index on (item_id, store_id, sale_start_date, sale_price).
    func insertFlyerSale(itemID: Int64, storeID: Int64, salePrice: Double,
                         validFrom: Date, validTo: Date?, source: String) {
        do {
            // OR IGNORE: if the unique constraint fires, SQLite silently skips the insert.
            try db.run(flyerSales.insert(or: .ignore,
                colItemID   <- itemID,
                colStoreID  <- storeID,
                colSalePrice <- salePrice,
                colValidFrom <- validFrom,
                colValidTo  <- validTo,
                colSource   <- source,
                colFetchedAt <- Date()
            ))
        } catch {
            print("[DatabaseManager] insertFlyerSale error: \(error)")
        }
    }

    // MARK: — Alert Log

    /// Count how many alerts have fired today across ALL items.
    func todayAlertCount() -> Int {
        let cal        = Calendar.current
        let startOfDay = cal.startOfDay(for: Date())
        let endOfDay   = cal.date(byAdding: .day, value: 1, to: startOfDay)!
        return (try? db.scalar(alertLog.filter(colFiredAt >= startOfDay && colFiredAt < endOfDay).count)) ?? 0
    }

    /// Write an alert record. Called by AlertEngine BEFORE scheduling the notification.
    @discardableResult
    func logAlert(itemID: Int64, alertType: String, triggerPrice: Double,
                  notificationID: String?) -> Int64 {
        do {
            return try db.run(alertLog.insert(
                colItemID      <- itemID,
                colAlertType   <- alertType,
                colTriggerPrice <- triggerPrice,
                colFiredAt     <- Date(),
                colNotifID     <- notificationID
            ))
        } catch {
            print("[DatabaseManager] logAlert error: \(error)"); return -1
        }
    }

    // MARK: — User Settings

    func setSetting(key: String, value: String) {
        try? db.run(userSettings.insert(or: .replace, colKey <- key, colValue <- value))
    }

    func getSetting(key: String) -> String? {
        return try? db.pluck(userSettings.filter(colKey == key)).map { $0[colValue] }
    }
}
