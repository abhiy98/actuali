//
//  ContentView.swift
//  Actuali
//
//  Created by Matt Farrell on 9/12/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var budgetStore: BudgetStore

    /// Presents whenever the store publishes an error; dismissing clears it
    /// so the next failure can present again.
    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { budgetStore.error != nil },
            set: { if !$0 { budgetStore.error = nil } }
        )
    }

    var body: some View {
        MainTabView()
            .alert("Something Went Wrong", isPresented: errorAlertBinding) {
                Button("OK") {}
            } message: {
                Text(budgetStore.error ?? "")
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(BudgetStore.previewInstance())
}
