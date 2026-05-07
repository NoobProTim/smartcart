// FlippService.swift — SmartCart/Services/FlippService.swift
// Fetches current flyer sale prices from the Flipp unofficial API.
//
// P0-3 FIX: The Flipp API returns two different JSON shapes — a dict-based format
// and an array-based format — depending on the endpoint version. This file handles
// both via a dual-decoder strategy. A third shape (error / unavailable) triggers
// markFlippUnavailable() which sets a user_settings key so the UI can show a
// plain-English "Price data unavailable" banner instead of a crash or silent failure.

import Foundation

// Possible outcomes of a Flipp fetch attempt
enum FlippResult {
    case success([FlyerSale])          // Normalised sale rows ready to insert
    case unavailable(String)           // Flipp API unreachable or returned unexpected shape
    case noSalesFound                  // Request succeeded but retailer has no active sales
}

// P0-3: Dict-based JSON shape (newer Flipp endpoints)
private struct FlippItemDict: Decodable {
    let name: String
    let current_price: Double?
    let sale_story: String?
    let valid_from: String?
    let valid_to: String?
}

// P0-3: Array-based JSON shape (older Flipp endpoints)
private struct FlippItemArray: Decodable {
    let n: String          // name
    let p: Double?         // price
    let vf: String?        // valid_from
    let vt: String?        // valid_to
}

final class FlippService {
    static let shared = FlippService()
    private let session = URLSession.shared
    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    private init() {}

    // MARK: — Public

    /// Fetch sales for a specific item + store combination.
    /// All network calls are async; call from a Task or async context.
    func fetchSales(for itemName: String, storeFlippID: String,
                    postalCode: String) async -> FlippResult {
        guard let url = buildURL(itemName: itemName, storeID: storeFlippID,
                                 postalCode: postalCode) else {
            return .unavailable("Could not build Flipp request URL.")
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode)
            else {
                markFlippUnavailable(reason: "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return .unavailable("Flipp returned an unexpected response.")
            }

            // P0-3: Try dict-shape first, then array-shape
            if let sales = decodeDict(data: data, storeFlippID: storeFlippID) {
                return sales.isEmpty ? .noSalesFound : .success(sales)
            }
            if let sales = decodeArray(data: data, storeFlippID: storeFlippID) {
                return sales.isEmpty ? .noSalesFound : .success(sales)
            }

            markFlippUnavailable(reason: "Unrecognised JSON shape")
            return .unavailable("Price data format changed. Will retry on next sync.")

        } catch {
            markFlippUnavailable(reason: error.localizedDescription)
            return .unavailable("Network error: \(error.localizedDescription)")
        }
    }

    // MARK: — Private decoders (P0-3)

    private func decodeDict(data: Data, storeFlippID: String) -> [FlyerSale]? {
        guard let items = try? JSONDecoder().decode([FlippItemDict].self, from: data)
        else { return nil }
        return items.compactMap { item -> FlyerSale? in
            guard let price = item.current_price else { return nil }
            return FlyerSale(
                id: 0,  // DB assigns real ID
                itemID: 0, storeID: 0,  // Caller resolves real IDs before DB insert
                salePrice: price,
                validFrom: isoFormatter.date(from: item.valid_from ?? "") ?? Date(),
                validTo:   isoFormatter.date(from: item.valid_to   ?? ""),
                source: "flipp",
                fetchedAt: Date()
            )
        }
    }

    private func decodeArray(data: Data, storeFlippID: String) -> [FlyerSale]? {
        guard let items = try? JSONDecoder().decode([FlippItemArray].self, from: data)
        else { return nil }
        return items.compactMap { item -> FlyerSale? in
            guard let price = item.p else { return nil }
            return FlyerSale(
                id: 0, itemID: 0, storeID: 0,
                salePrice: price,
                validFrom: isoFormatter.date(from: item.vf ?? "") ?? Date(),
                validTo:   isoFormatter.date(from: item.vt ?? ""),
                source: "flipp",
                fetchedAt: Date()
            )
        }
    }

    // MARK: — Helpers

    private func buildURL(itemName: String, storeID: String, postalCode: String) -> URL? {
        var comps = URLComponents(string: "https://flippapi.ca/v1/items")
        comps?.queryItems = [
            URLQueryItem(name: "q",           value: itemName),
            URLQueryItem(name: "retailer_id", value: storeID),
            URLQueryItem(name: "postal_code", value: postalCode)
        ]
        return comps?.url
    }

    /// P0-3: Record that Flipp is unavailable so the UI can surface a banner.
    private func markFlippUnavailable(reason: String) {
        DatabaseManager.shared.setSetting(key: "flipp_unavailable",  value: "1")
        DatabaseManager.shared.setSetting(key: "flipp_unavailable_reason", value: reason)
    }
}
