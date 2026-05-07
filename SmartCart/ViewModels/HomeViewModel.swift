// HomeViewModel.swift — SmartCart/ViewModels/HomeViewModel.swift
// Drives HomeView. Calls DatabaseManager to load user items.
// Items are sorted: restock-window items pinned to top, then by next restock date.

import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var userItems: [UserItem] = []

    /// Load (or reload) all user items from SQLite, then sort them.
    /// P0-1 + P1-5: loadUserItems() is now atomic and returns hasActiveAlert correctly.
    func loadItems() {
        let raw = DatabaseManager.shared.loadUserItems()
        userItems = raw.sorted { a, b in
            // Restock-window items always float to the top
            if a.isInRestockWindow != b.isInRestockWindow { return a.isInRestockWindow }
            // Within each group, sort by soonest restock date
            switch (a.nextRestockDate, b.nextRestockDate) {
            case let (ad?, bd?): return ad < bd
            case (.some, .none): return true
            case (.none, .some): return false
            default:             return a.nameDisplay < b.nameDisplay
            }
        }
    }
}
