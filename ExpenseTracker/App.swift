import SwiftUI

@main
struct ExpenseTrackerApp: App {
    var body: some Scene {
        WindowGroup { StoreLoaderView() }
    }
}

private struct StoreLoaderView: View {
    @State private var store: ExpenseStore?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let store {
                ContentView(store: store)
            } else {
                VStack(spacing: 16) {
                    Text("Expense Tracker").font(.title)
                    if let errorMessage {
                        Text("Could not open local expenses.").font(.headline)
                        Text(errorMessage)
                        Button("Retry", action: load)
                    } else {
                        ProgressView()
                    }
                }.padding()
            }
        }
        .task { if store == nil { load() } }
    }

    private func load() {
        do {
            store = try ExpenseStore(fileURL: ExpenseStore.defaultFileURL())
            errorMessage = nil
        } catch {
            // Never replace unreadable data with an empty store.
            errorMessage = error.localizedDescription
        }
    }
}
