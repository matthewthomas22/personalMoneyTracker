import SwiftUI

struct PaymentSourcePicker: View {
    let sources: [PaymentSource]
    @Binding var selection: UUID?

    var body: some View {
        Picker("Payment source", selection: $selection) {
            Text("Choose a source").tag(nil as UUID?)
            ForEach(sources.filter { !$0.isArchived || $0.id == selection }) { source in
                Text(source.name + (source.isArchived ? " (archived)" : ""))
                    .tag(Optional(source.id))
            }
        }
    }
}

/// Entry integration: channel remains a separate field owned by the expense form.
struct PaymentSourceEntry: View {
    @ObservedObject var store: ExpenseStore
    @Binding var selection: UUID?
    @State private var sourceText = ""
    @State private var proposedName: String?
    @State private var confirmingCreation = false
    @State private var managing = false
    @State private var errorMessage: String?

    var body: some View {
        PaymentSourcePicker(sources: store.sources, selection: $selection)
        TextField("Source name or known alias", text: $sourceText)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .onChange(of: sourceText) { _, value in
                if !PaymentSourceRules.cleaned(value).isEmpty { selection = nil }
            }
            .onSubmit(resolve)
        Button("Use source name or alias", action: resolve)
            .disabled(PaymentSourceRules.cleaned(sourceText).isEmpty)
        Button("Manage sources") { managing = true }
            .sheet(isPresented: $managing) { PaymentSourcesView(store: store) }
            .alert("Create payment source?", isPresented: $confirmingCreation) {
                Button("Cancel", role: .cancel) { proposedName = nil }
                Button("Create and select") { createConfirmedSource() }
            } message: {
                Text("Add ‘\(proposedName ?? "")’ to your saved payment sources?")
            }
            .alert("Payment source", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
    }

    private func resolve() {
        do {
            if let source = try PaymentSourceRules.resolve(sourceText, in: store.sources) {
                selection = source.id
                sourceText = ""
            } else {
                proposedName = PaymentSourceRules.cleaned(sourceText)
                confirmingCreation = true
            }
        } catch { errorMessage = error.localizedDescription }
    }

    private func createConfirmedSource() {
        guard let name = proposedName else { return }
        defer { proposedName = nil }
        do {
            // Re-resolve after confirmation in case management changed the source list.
            if let existing = try PaymentSourceRules.resolve(name, in: store.sources) {
                selection = existing.id
            } else {
                let candidate = try PaymentSourceRules.normalized(PaymentSource(name: name), in: store.sources)
                selection = try store.addSource(candidate).id
            }
            sourceText = ""
        } catch { errorMessage = error.localizedDescription }
    }
}

struct PaymentSourcesView: View {
    @ObservedObject var store: ExpenseStore
    @Environment(\.dismiss) private var dismiss
    @State private var editing: PaymentSource?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.sources) { source in
                        VStack(alignment: .leading, spacing: 6) {
                            Button { editing = source } label: {
                                VStack(alignment: .leading) {
                                    Text(source.name)
                                    if !source.aliases.isEmpty {
                                        Text(source.aliases.joined(separator: ", "))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            if source.isArchived { Text("Archived").font(.caption).foregroundStyle(.secondary) }
                            HStack {
                                Button(source.isArchived ? "Restore" : "Archive") {
                                    perform {
                                        var changed = source
                                        changed.isArchived.toggle()
                                        try store.updateSource(changed)
                                    }
                                }
                                if !store.expenses.contains(where: { $0.sourceID == source.id }) {
                                    Button("Remove", role: .destructive) {
                                        perform { try store.deleteSource(id: source.id) }
                                    }
                                }
                            }.buttonStyle(.borderless)
                        }
                    }
                } footer: {
                    Text("Archived sources remain on past expenses. Sources used by expenses can be archived, but cannot be removed. Names and aliases stay reserved while archived. Renaming keeps the same source on past expenses.")
                }
            }
            .navigationTitle("Payment sources")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add", systemImage: "plus") { editing = PaymentSource(name: "") }
                }
            }
            .sheet(item: $editing) { source in PaymentSourceEditor(store: store, source: source) }
            .alert("Could not change source", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) { Button("OK", role: .cancel) { errorMessage = nil } }
            message: { Text(errorMessage ?? "") }
        }
    }

    private func perform(_ action: () throws -> Void) {
        do { try action() } catch { errorMessage = error.localizedDescription }
    }
}

private struct PaymentSourceEditor: View {
    @ObservedObject var store: ExpenseStore
    let source: PaymentSource
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var aliases: [String]
    @State private var errorMessage: String?

    init(store: ExpenseStore, source: PaymentSource) {
        self.store = store
        self.source = source
        _name = State(initialValue: source.name)
        _aliases = State(initialValue: source.aliases)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Source name", text: $name)
                Section {
                    ForEach(aliases.indices, id: \.self) { index in
                        TextField("Alias", text: $aliases[index])
                    }
                    .onDelete { aliases.remove(atOffsets: $0) }
                    Button("Add alias") { aliases.append("") }
                } header: { Text("Known aliases") }
                footer: { Text("Use a different name or alias for each source. Swipe an alias to remove it.") }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle(store.sources.contains { $0.id == source.id } ? "Edit source" : "New source")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
        }
    }

    private func save() {
        do {
            var candidate = source
            candidate.name = name
            candidate.aliases = aliases
            candidate = try PaymentSourceRules.normalized(candidate, in: store.sources)
            if store.sources.contains(where: { $0.id == source.id }) {
                try store.updateSource(candidate)
            } else {
                try store.addSource(candidate)
            }
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
