// UserStore.swift
import Foundation

struct UserStore: Identifiable, Codable {
    let id: Int64
    var storeId: Int64
    var isPrimary: Bool
    var addedAt: Date
}
