//
//  HomeView.swift
//  Totally
//
//  Root basket/budget screen. Holds no business logic: it renders `Trip`
//  values and calls domain operations. Money is displayed in pounds and
//  pence but always stored as integer pence. See docs/architecture/ui.md.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    let store: TripStore

    private var trip: Trip { store.trip }

    @State private var showManualEntry = false
    @State private var showBudgetEditor = false
    @State private var showNewTripConfirm = false
    @State private var budgetText = ""
    @State private var scanner = VisionKitScanner()
    private let captureFeedback: CaptureFeedbackPlaying = CaptureFeedback()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                summaryHeader
                Divider()
                basketList
                bottomBar
            }
            .navigationTitle("Basket")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New trip") { showNewTripConfirm = true }
                        .disabled(trip.items.isEmpty && trip.budgetInPence == 0)
                }
            }
            .sheet(isPresented: $showManualEntry) {
                ManualEntryView { name, unitPriceInPence, quantity in
                    store.add(name: name, unitPriceInPence: unitPriceInPence, quantity: quantity)
                }
            }
            .fullScreenCover(isPresented: Bindable(scanner).isPresenting) {
                ScannerCameraView(
                    onRecognizedText: { lines in scanner.handleRecognizedText(lines) },
                    onCancel: { scanner.handleCancel() }
                )
                .ignoresSafeArea()
            }
            .alert("Set budget", isPresented: $showBudgetEditor) {
                TextField("0.00", text: $budgetText)
                    .keyboardType(.decimalPad)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    if let pence = Money.pence(fromPoundsString: budgetText) {
                        store.setBudget(pence)
                    }
                }
            } message: {
                Text("Enter your budget in pounds.")
            }
            .confirmationDialog(
                "Start a new trip?",
                isPresented: $showNewTripConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear basket", role: .destructive) {
                    store.startNewTrip()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This empties the basket. Your budget stays the same.")
            }
        }
    }

    // MARK: - Summary header

    private var summaryHeader: some View {
        VStack(spacing: 4) {
            Text(remainingHeadline)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(trip.isOverBudget ? Color.red : Color.primary)
                .contentTransition(.numericText())
            Text(remainingSubtitle)
                .font(.subheadline)
                .foregroundStyle(trip.isOverBudget ? Color.red : Color.secondary)

            HStack(spacing: 24) {
                labelledValue("Total", Money.string(fromPence: trip.totalInPence))
                Button {
                    budgetText = trip.budgetInPence > 0
                        ? Money.string(fromPence: trip.budgetInPence).replacingOccurrences(of: "£", with: "")
                        : ""
                    showBudgetEditor = true
                } label: {
                    labelledValue("Budget", Money.string(fromPence: trip.budgetInPence))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func labelledValue(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
        }
    }

    private var remainingHeadline: String {
        if trip.isOverBudget {
            return "\(Money.string(fromPence: abs(trip.remainingInPence))) over"
        }
        return "\(Money.string(fromPence: trip.remainingInPence)) left"
    }

    private var remainingSubtitle: String {
        trip.isOverBudget ? "You're over budget" : "remaining of your budget"
    }

    // MARK: - Basket list

    @ViewBuilder
    private var basketList: some View {
        if trip.items.isEmpty {
            emptyState
        } else {
            List {
                ForEach(trip.items) { item in
                    basketRow(item)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        store.remove(id: trip.items[index].id)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private func basketRow(_ item: BasketItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                Text("\(Money.string(fromPence: item.unitPriceInPence)) each")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    store.setQuantity(item.quantity - 1, for: item.id)
                } label: {
                    Image(systemName: "minus.circle")
                }
                Text("\(item.quantity)")
                    .font(.body.monospacedDigit())
                    .frame(minWidth: 20)
                Button {
                    store.setQuantity(item.quantity + 1, for: item.id)
                } label: {
                    Image(systemName: "plus.circle")
                }
            }
            .buttonStyle(.borderless)

            Text(Money.string(fromPence: item.lineTotalInPence))
                .font(.body.monospacedDigit())
                .frame(minWidth: 64, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "cart")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Your basket is empty")
                .font(.headline)
            Text("Set a budget, then scan or add your first item.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bottom bar

    private func scanNextItem() async {
        let result = await scanner.scanNextItem()
        guard let capture = result.captureToAutoAdd else { return }
        store.add(name: capture.name, unitPriceInPence: capture.priceInPence)
        captureFeedback.playAutoAddFeedback()
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                Task { await scanNextItem() }
            } label: {
                Label("Scan next item", systemImage: "camera.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                showManualEntry = true
            } label: {
                Label("Add manually", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.bar)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: PersistedTrip.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    HomeView(store: TripStore(modelContext: container.mainContext))
}
