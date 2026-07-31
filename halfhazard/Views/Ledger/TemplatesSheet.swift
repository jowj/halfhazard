//
//  TemplatesSheet.swift
//  halfhazard
//

import SwiftUI

/// The recurring sets of expenses, and the button that writes one into the ledger.
struct TemplatesSheet: View {
    let store: LedgerStore
    @Environment(\.dismiss) private var dismiss

    @State private var editing: Template?
    @State private var applied: String?

    var body: some View {
        NavigationStack {
            SwiftUI.Group {
                if store.templates.isEmpty {
                    ContentUnavailableView(
                        "No templates",
                        systemImage: "doc.on.doc",
                        description: Text("A template is a set of expenses you record together — rent, bills, the weekly shop.")
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Templates")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editing = store.newTemplate()
                    } label: {
                        Label("New template", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editing) { template in
                TemplateEditor(store: store, template: template)
            }
        }
        .frame(minWidth: 380, minHeight: 420)
    }

    private var list: some View {
        List {
            ForEach(store.templates) { template in
                Section {
                    ForEach(template.lines) { line in
                        HStack {
                            Text(line.note.isEmpty ? "Untitled" : line.note)
                            Spacer()
                            Text(line.amount.formatted())
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .font(.callout)
                    }

                    HStack {
                        Button("Record \(template.total.formatted())") {
                            Task {
                                if await store.apply(template) != nil {
                                    applied = template.name
                                    dismiss()
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer()

                        Button("Edit") { editing = template }
                        Button("Delete", role: .destructive) {
                            Task { await store.delete(template) }
                        }
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
                } header: {
                    Text(template.name.isEmpty ? "Untitled template" : template.name)
                }
            }
        }
    }
}

/// Writes one template: a name and its lines.
struct TemplateEditor: View {
    let store: LedgerStore
    @State var template: Template
    @Environment(\.dismiss) private var dismiss

    private var members: [String] { store.ledger?.memberIds ?? [] }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $template.name)
                }

                ForEach($template.lines) { $line in
                    Section {
                        TemplateLineEditor(line: $line, store: store)
                    }
                }

                Section {
                    Button {
                        template.lines.append(TemplateLine(note: "", amount: .zero))
                    } label: {
                        Label("Add a line", systemImage: "plus")
                    }
                    if !template.lines.isEmpty {
                        LabeledContent("Total", value: template.total.formatted())
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(template.name.isEmpty ? "New template" : template.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await store.save(template)
                            dismiss()
                        }
                    }
                    .disabled(template.name.isEmpty || template.lines.isEmpty)
                }
            }
        }
        .frame(minWidth: 380, minHeight: 460)
    }
}

/// One line of a template: what it is, how much, who pays, how it divides.
private struct TemplateLineEditor: View {
    @Binding var line: TemplateLine
    let store: LedgerStore

    @State private var amountText = ""

    private var partnerId: String? { store.partnerId }

    var body: some View {
        TextField("What for?", text: $line.note)

        TextField("Amount", text: $amountText)
            #if os(iOS)
            .keyboardType(.decimalPad)
            #endif
            .onAppear { amountText = line.amount.isZero ? "" : String(format: "%.2f", line.amount.dollars) }
            .onChange(of: amountText) { _, text in
                if let money = Money(parsingDollars: text) { line.amount = money }
            }

        Picker("Paid by", selection: payerBinding) {
            Text("Whoever records it").tag("")
            Text("You").tag(store.viewerId)
            if let partnerId {
                Text(store.name(for: partnerId)).tag(partnerId)
            }
        }

        Picker("Split", selection: splitBinding) {
            Text("Evenly").tag("equal")
            Text("You cover it").tag("mine")
            if partnerId != nil {
                Text("They cover it").tag("theirs")
            }
        }
    }

    /// An empty tag means `.applier`; anything else is that member.
    private var payerBinding: Binding<String> {
        Binding(
            get: {
                switch line.payer {
                case .applier: return ""
                case .member(let id): return id
                }
            },
            set: { line.payer = $0.isEmpty ? .applier : .member($0) }
        )
    }

    /// The three splits worth offering for two people. Percentages and shares exist in the
    /// model and survive a round trip; there is just no reason to build a keypad for them
    /// until somebody wants one.
    private var splitBinding: Binding<String> {
        Binding(
            get: {
                guard let partnerId else { return "equal" }
                switch line.split {
                case .equal: return "equal"
                case .exact(let amounts):
                    if amounts[store.viewerId] == line.amount { return "mine" }
                    if amounts[partnerId] == line.amount { return "theirs" }
                    return "equal"
                default: return "equal"
                }
            },
            set: { choice in
                guard let partnerId else { return }
                switch choice {
                case "mine":
                    line.split = .exact([store.viewerId: line.amount, partnerId: .zero])
                case "theirs":
                    line.split = .exact([store.viewerId: .zero, partnerId: line.amount])
                default:
                    line.split = .equal
                }
            }
        )
    }
}
