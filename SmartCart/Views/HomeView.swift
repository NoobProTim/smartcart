// HomeView.swift — SmartCart/Views/HomeView.swift
// Main screen. Shows the user's tracked item list (Smart List).
//
// P1-6 FIX: Observes NotificationRouter.shared.pendingItemID.
// When a notification is tapped, HomeView scrolls to and highlights
// the target item row automatically.

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject private var router = NotificationRouter.shared
    @State private var showScanner = false
    @State private var showSettings = false
    @State private var showNotifBanner = false
    @State private var highlightedItemID: Int64? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.userItems.isEmpty {
                    EmptyCTAView { showScanner = true }
                } else {
                    itemList
                }
            }
            .navigationTitle("SmartCart")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showScanner = true } label: {
                        Image(systemName: "camera.viewfinder")
                    }
                    .accessibilityLabel("Scan a receipt")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if showNotifBanner {
                    NotificationBannerView(
                        onDismiss: { showNotifBanner = false },
                        onEnable: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showScanner)  { Text("Receipt Scanner — Coming in Task #3") }
        .sheet(isPresented: $showSettings) { Text("Settings — Coming in Task #4") }
        .onAppear {
            viewModel.loadItems()
            checkNotificationStatus()
        }
        // P1-6: Deep-link handler — scroll to item when notification tapped
        .onChange(of: router.pendingItemID) { _, newID in
            guard let id = newID else { return }
            highlightedItemID = id
            router.pendingItemID = nil  // Clear after consuming
        }
    }

    private var itemList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(viewModel.userItems) { item in
                    UserItemRow(item: item, isHighlighted: item.id == highlightedItemID)
                        .id(item.id)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }
            .listStyle(.plain)
            .onChange(of: highlightedItemID) { _, id in
                guard let id else { return }
                withAnimation { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                showNotifBanner = settings.authorizationStatus == .denied
            }
        }
    }
}

// MARK: — UserItemRow

struct UserItemRow: View {
    let item: UserItem
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.nameDisplay).font(.system(size: 15, weight: .medium)).foregroundStyle(.primary)
                    // P1-5: Alert dot — only shown when hasActiveAlert is true
                    if item.hasActiveAlert {
                        Circle().fill(Color.orange).frame(width: 7, height: 7)
                            .accessibilityLabel("Active price alert")
                    }
                }
                if let next = item.nextRestockDate {
                    Text(restockLabel(for: next)).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let price = item.lastPurchasedPrice {
                Text(String(format: "$%.2f", price)).font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
        .background(isHighlighted ? Color.accentColor.opacity(0.08) : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(isHighlighted ? RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor, lineWidth: 1.5) : nil)
        .animation(.easeInOut(duration: 0.3), value: isHighlighted)
    }

    private func restockLabel(for date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days <= 0    { return "Buy soon" }
        if days == 1    { return "Tomorrow" }
        return "In \(days) days"
    }
}
