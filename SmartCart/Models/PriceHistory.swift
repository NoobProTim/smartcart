// PriceHistory.swift
import Foundation

struct PriceHistory: Identifiable, Codable {
    let id: Int64
    var itemId: Int64
    var storeId: Int64
    var price: Double
    var recordedAt: Date
    var source: String
}
