// PurchaseHistory.swift
import Foundation

struct PurchaseHistory: Identifiable, Codable {
    let id: Int64
    var userItemId: Int64
    var storeId: Int64
    var purchaseDate: Date
    var price: Double
    var quantity: Int
}
