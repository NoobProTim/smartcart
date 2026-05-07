// FlyerSale.swift
import Foundation

struct FlyerSale: Identifiable, Codable {
    let id: Int64
    var itemId: Int64
    var storeId: Int64
    var salePrice: Double
    var originalPrice: Double?
    var startDate: Date
    var endDate: Date
    var source: String
}
