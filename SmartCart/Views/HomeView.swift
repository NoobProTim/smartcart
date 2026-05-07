// HomeView.swift
// Fixed in R1 (P1-6)
import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        Text("Home")
    }
}
