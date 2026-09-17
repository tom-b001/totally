//
//  HomeView.swift
//  Totally
//
//  Placeholder home screen. Will grow into the basket/budget screen
//  described in docs/architecture/ui.md.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "cart")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Totally")
                    .font(.largeTitle.bold())
                Text("Your basket will show up here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Basket")
        }
    }
}

#Preview {
    HomeView()
}
