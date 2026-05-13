// ReceiptReviewViewModel.swift
// SmartCart — Views/ReceiptReviewViewModel.swift
//
// State and save logic for ReceiptReviewView.
//
// Save pipeline (called when user taps "Add X items"):
//   For each included ParsedReceiptItem:
//   1. Find or create the item in the `items` table (by normalised name)
//   2. Add to `user_items` watchlist if not already there
//   3. Write a `purchase_history` row (source: 'receipt')
//   4. Update user_items.last_purchased_date + last_purchased_price
//   5. Recalculate replenishment cycle median
//
// Depends on: DatabaseManager, ParsedReceiptItem, DateHelper

import Foundation
import Combine

@MainActor
final class ReceiptReviewViewModel: ObservableObject {

    // MARK: - Published state

    /// The mutable list of parsed items. Bound to the list in ReceiptReviewView.
    @Published var items: [ParsedReceiptItem] = []

    /// The store this receipt came from. nil = user hasn't selected one yet.
    @Published var selectedStore: StoreRow? = nil

    /// True while the DB write is in progress (disables confirm button).
    @Published var isSaving: Bool = false

    /// Set to true when save completes — triggers the "Saved" alert in the View.
    @Published var showSaveConfirmation: Bool = false

    /// How many items were actually written (for the confirmation message).
    @Published var confirmedCount: Int = 0

    // MARK: - Load

    /// Called from ReceiptReviewView.onAppear. Seeds the items list from the parser output.
    func load(items: [ParsedReceiptItem]) {
        self.items = items
    }

    // MARK: - Save pipeline

    /// Iterates over every included ParsedReceiptItem and writes it to SQLite.
    /// Runs on a background thread (Task.detached) to keep the UI responsive.
    /// Sets showSaveConfirmation = true when all writes are complete.
    func confirmAndSave() {
        guard !isSaving else { return }
        isSaving = true

        let includedItems = items.filter { $0.isIncluded }
        let storeID: Int64? = selectedStore.map { $0.id }
        let today = DateHelper.todayString()

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            var savedCount = 0
            let db = DatabaseManager.shared

            for parsedItem in includedItems {

                // Step 1: Find or create the items row by normalised name.
                // Capitalise each word for the display name stored in the DB.
                let displayName = parsedItem.normalisedName
                    .split(separator: " ")
                    .map { $0.capitalized }
                    .joined(separator: " ")

                let itemID: Int64
                if let existing = db.findItem(normalisedName: parsedItem.normalisedName) {
                    itemID = existing
                } else {
                    itemID = db.insertItem(
                        normalisedName: parsedItem.normalisedName,
                        displayName: displayName
                    )
                }

                // Step 2: Add to watchlist if not already tracked.
                // addToWatchlist is idempotent — safe to call every time.
                db.addToWatchlist(itemID: itemID)

                // Step 3: Write a purchase_history row.
                // parsedPrice may be nil if OCR couldn't read it; store nil gracefully.
                db.insertPurchase(
                    itemID: itemID,
                    storeID: storeID,
                    price: parsedItem.parsedPrice ?? 0.0,
                    date: today,
                    source: "receipt"
                )

                // Step 4: Update last_purchased_date + last_purchased_price on user_items.
                // We need the user_items.id for markPurchased — fetch the active row.
                let userItems = db.fetchUserItems()
                if let userItem = userItems.first(where: { $0.itemID == itemID }),
                   let sid = storeID {
                    db.markPurchased(
                        userItemID: userItem.id,
                        storeID: sid,
                        price: parsedItem.parsedPrice ?? 0.0
                    )
                }

                // Step 5: Recalculate the replenishment cycle median.
                // updateReplenishmentInferred keeps all SQL inside DatabaseManager.
                if let newCycle = db.recalculateReplenishment(itemID: itemID) {
                    db.updateReplenishmentInferred(itemID: itemID, days: newCycle)
                }

                savedCount += 1
            }

            // Back to main thread to update published UI state.
            await MainActor.run {
                self.confirmedCount = savedCount
                self.isSaving = false
                self.showSaveConfirmation = true
            }
        }
    }
}
