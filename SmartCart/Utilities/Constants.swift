// Constants.swift — SmartCart/Utilities/Constants.swift
// App-wide constants. All magic numbers live here.

import Foundation

enum Constants {
    static let defaultReplenishmentDays = 14   // Used when < 2 purchases recorded for an item
    static let restockWindowDays        = 3    // Days before restock date to pin item to top of list
    static let maxDailyAlerts           = 3    // Maximum notifications fired per calendar day
    static let flippSyncIntervalHours   = 24   // Hours between background Flipp syncs
    static let historicalLowWindowDays  = 90   // Days of price history used for "all-time low" check
    static let saleExpiryWarningHours   = 24   // Hours before sale end to fire expiry alert
}
