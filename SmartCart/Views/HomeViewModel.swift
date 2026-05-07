// HomeViewModel.swift
// Fixed in R1 (P0-1, P1-5)
import Foundation
import Combine

final class HomeViewModel: ObservableObject {
    @Published var items: [UserItem] = []
    @Published var alerts: [AlertLog] = []

    func loadData() {
        // Load from DatabaseManager
    }
}
