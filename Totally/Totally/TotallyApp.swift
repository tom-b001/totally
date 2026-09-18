//
//  TotallyApp.swift
//  Totally
//
//  App entry point.
//

import SwiftUI
import SwiftData

@main
struct TotallyApp: App {
    private let modelContainer: ModelContainer

    init() {
        modelContainer = try! ModelContainer(for: PersistedTrip.self)
    }

    var body: some Scene {
        WindowGroup {
            HomeView(store: TripStore(modelContext: modelContainer.mainContext))
        }
    }
}
