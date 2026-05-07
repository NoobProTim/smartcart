// ParsedReceiptItem.swift
import Foundation

struct ParsedReceiptItem: Identifiable, Codable {
    let id: UUID
    var rawName: String
    var normalizedName: String?
    var price: Double?
    var confidence: Float
    var matched: Bool
}
