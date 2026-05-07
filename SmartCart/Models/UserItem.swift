// UserItem.swift
import Foundation

struct UserItem: Identifiable, Codable {
    let id: Int64
    var itemId: Int64
    var preferredStoreId: Int64?
    var replenishmentDays: Int?
    var alertEnabled: Bool
}
