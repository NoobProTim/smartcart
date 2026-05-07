// Store.swift
import Foundation

struct Store: Identifiable, Codable {
    let id: Int64
    var name: String
    var chain: String?
    var postalCode: String?
}
