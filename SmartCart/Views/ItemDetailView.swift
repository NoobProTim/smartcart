// ItemDetailView.swift — SmartCart/Views/ItemDetailView.swift
// Shows price history chart, active sales, and purchase history for one item.
//
// P0-3 FIX: If flipp_unavailable == "1" in user_settings, a plain-English
// amber banner is shown instead of an empty chart. The banner shows the
// stored reason string so developers can diagnose during testing.

import SwiftUI

struct ItemDetailView: View {
    let item: UserItem

    @State private var flippUnavailable = false
    @State private var flippUnavailableReason: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // P0-3: Flipp unavailable banner
                if flippUnavailable {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Price data unavailable")
                                .font(.system(size: 13, weight: .semibold))
                            if let reason = flippUnavailableReason {
                                Text(reason).font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)
                }

                // Price history placeholder (chart rendered in Sprint 2)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Price History").font(.system(size: 17, weight: .semibold)).padding(.horizontal, 16)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground)).frame(height: 160)
                        .overlay(Text("Chart — Sprint 2").foregroundStyle(.secondary))
                        .padding(.horizontal, 16)
                }

                // Last purchase info
                if let price = item.lastPurchasedPrice, let date = item.lastPurchasedDate {
                    HStack {
                        Label("Last bought", systemImage: "cart").font(.system(size: 14)).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(String(format: "$%.2f", price)) on \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 14)).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                }

                // Next restock
                if let restock = item.nextRestockDate {
                    HStack {
                        Label("Next restock", systemImage: "arrow.clockwise").font(.system(size: 14)).foregroundStyle(.secondary)
                        Spacer()
                        Text(restock.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 14)).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 16)
        }
        .navigationTitle(item.nameDisplay)
        .navigationBarTitleDisplayMode(.large)
        .onAppear { loadFlippStatus() }
    }

    private func loadFlippStatus() {
        flippUnavailable = DatabaseManager.shared.getSetting(key: "flipp_unavailable") == "1"
        flippUnavailableReason = DatabaseManager.shared.getSetting(key: "flipp_unavailable_reason")
    }
}
