// Item.swift
import Foundation

struct Item: Identifiable, Codable {
    let id: Int64
    var name: String
    var normalizedName: String
    var brand: String?
    var category: String?
}
