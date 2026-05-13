// ReceiptReviewView.swift
// SmartCart — Views/ReceiptReviewView.swift
//
// Shown after the camera scan completes.
// Lets the user review OCR results before saving them.
//
// Layout:
//   - Header: store picker (which store was this receipt from?)
//   - List: one row per ParsedReceiptItem
//     • Amber flag + warning icon for .low confidence items
//     • Toggle to exclude a line (price OCR'd incorrectly, etc.)
//     • Inline price editor — tap price to correct it
//   - Footer: "Add X items" confirm button
//
// Depends on: ReceiptReviewViewModel, ParsedReceiptItem, DatabaseManager

import SwiftUI

struct ReceiptReviewView: View {

    // The parsed items list from ReceiptParser
    let items: [ParsedReceiptItem]

    // Binding back to ReceiptScannerView — set to false to close the whole scan flow
    @Binding var isPresented: Bool

    @StateObject private var viewModel = ReceiptReviewViewModel()
    @State private var showStorePicker = false
    @State private var editingItemID: UUID? = nil  // which row is in price-edit mode
    @State private var editingPrice: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // --- Store picker header ---
                storeSelectorRow
                    .padding(.horizontal)
                    .padding(.top, 12)
                Divider().padding(.top, 8)

                // --- Items list ---
                if viewModel.items.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach($viewModel.items) { $item in
                            ReviewItemRow(
                                item: $item,
                                isEditing: editingItemID == item.id,
                                editingPrice: $editingPrice,
                                onEditTap: { beginEditing(item: item) },
                                onEditCommit: { commitEdit(item: &$item.wrappedValue) }
                            )
                        }
                    }
                    .listStyle(.plain)
                }

                Divider()

                // --- Confirm footer ---
                confirmFooter
                    .padding()
            }
            .navigationTitle("Review Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
        .onAppear { viewModel.load(items: items) }
        .sheet(isPresented: $showStorePicker) {
            StoreSelectorSheet(selectedStore: $viewModel.selectedStore)
        }
        .alert("Saved", isPresented: $viewModel.showSaveConfirmation) {
            Button("Done") { isPresented = false }
        } message: {
            Text("\(viewModel.confirmedCount) items added to your Smart List.")
        }
    }

    // MARK: - Sub-views

    /// Tappable row showing the currently selected store (or a "Select store" prompt).
    private var storeSelectorRow: some View {
        Button(action: { showStorePicker = true }) {
            HStack {
                Image(systemName: "storefront")
                    .foregroundStyle(.secondary)
                Text(viewModel.selectedStore?.name ?? "Select store...")
                    .foregroundStyle(viewModel.selectedStore == nil ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
            .padding(12)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    /// Shown when ReceiptParser found zero items (very blurry photo, wrong side, etc.).
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No items detected")
                .font(.headline)
            Text("Try scanning again with the receipt flat and well-lit.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    /// Confirm button. Shows count of included items. Disabled if none selected.
    private var confirmFooter: some View {
        let includedCount = viewModel.items.filter { $0.isIncluded }.count
        return Button(action: { viewModel.confirmAndSave() }) {
            Text(includedCount == 0
                 ? "No items selected"
                 : "Add \(includedCount) item\(includedCount == 1 ? "" : "s")")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    includedCount == 0 ? Color.gray : Color.accentColor,
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .foregroundStyle(.white)
        }
        .disabled(includedCount == 0 || viewModel.isSaving)
    }

    // MARK: - Price editing helpers

    /// Puts the given item into inline price-edit mode.
    private func beginEditing(item: ParsedReceiptItem) {
        editingItemID = item.id
        // Pre-fill the text field with the current price, two decimal places.
        editingPrice = String(format: "%.2f", item.parsedPrice ?? 0.0)
    }

    /// Commits the edited price back onto the item and exits edit mode.
    private func commitEdit(item: inout ParsedReceiptItem) {
        if let newPrice = Double(editingPrice), newPrice > 0 {
            item.parsedPrice = newPrice
        }
        editingItemID = nil
        editingPrice = ""
    }
}

// MARK: - ReviewItemRow

/// One row in the receipt review list.
/// Shows: confidence flag | item name (editable) | price (editable) | include toggle
private struct ReviewItemRow: View {
    @Binding var item: ParsedReceiptItem
    let isEditing: Bool
    @Binding var editingPrice: String
    let onEditTap: () -> Void
    let onEditCommit: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {

            // Confidence indicator: amber warning for low-confidence lines
            if item.confidence == .low {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 14))
                    .accessibilityLabel("Low confidence — please review")
            } else {
                // Spacer to keep layout aligned when no warning icon
                Color.clear.frame(width: 14, height: 14)
            }

            // Item name column
            VStack(alignment: .leading, spacing: 2) {
                Text(item.normalisedName.capitalized)
                    .font(.body)
                    .foregroundStyle(item.isIncluded ? .primary : .secondary)
                if item.confidence == .low {
                    // Show the raw OCR string so the user can judge accuracy
                    Text("OCR: \"\(item.rawName)\"")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            // Price — tap to edit inline
            if isEditing {
                TextField("Price", text: $editingPrice)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 72)
                    .onSubmit { onEditCommit() }
            } else {
                Button(action: onEditTap) {
                    Text(String(format: "$%.2f", item.parsedPrice ?? 0.0))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(item.isIncluded ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }

            // Include/exclude toggle
            Toggle("", isOn: $item.isIncluded)
                .labelsHidden()
                .tint(.accentColor)
        }
        .padding(.vertical, 6)
        .opacity(item.isIncluded ? 1.0 : 0.4)
        .listRowBackground(
            // Amber tint for low-confidence rows that are still included
            item.confidence == .low && item.isIncluded
                ? Color.orange.opacity(0.06)
                : Color.clear
        )
    }
}

// MARK: - StoreSelectorSheet

/// A simple bottom sheet listing the user's tracked stores.
/// Tapping a store sets it as the receipt's source store.
private struct StoreSelectorSheet: View {
    @Binding var selectedStore: StoreRow?
    @Environment(\.dismiss) private var dismiss

    // Fetch the user's tracked stores from SQLite at sheet-open time.
    private let stores = DatabaseManager.shared.fetchSelectedStores()

    var body: some View {
        NavigationStack {
            List(stores, id: \.id) { store in
                Button(action: {
                    selectedStore = store
                    dismiss()
                }) {
                    HStack {
                        Text(store.name)
                        Spacer()
                        if selectedStore?.id == store.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Which store?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
