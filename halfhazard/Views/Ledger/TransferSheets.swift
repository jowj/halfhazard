//
//  TransferSheets.swift
//  halfhazard
//

import SwiftUI
import UniformTypeIdentifiers

/// A ledger export on its way to a file.
struct LedgerDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .json] }

    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// Choose a format, then a place to put it.
struct ExportSheet: View {
    let store: LedgerStore
    @Environment(\.dismiss) private var dismiss

    @State private var format: LedgerStore.ExportFormat = .csv
    @State private var isExporting = false

    private var document: LedgerDocument? {
        store.exported(as: format).map(LedgerDocument.init)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Segmented rather than a drill-down: two options, and the footer below
                    // explains whichever is selected. A collapsed picker would hide the one
                    // you are not choosing, which is the half that needs explaining.
                    Picker("Format", selection: $format) {
                        Text("CSV").tag(LedgerStore.ExportFormat.csv)
                        Text("JSON").tag(LedgerStore.ExportFormat.json)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                } footer: {
                    Text(format == .csv
                         ? "One row per entry, with a column for what each of you paid and owed. Readable anywhere, but it records the amounts rather than the rule behind them."
                         : "Everything, exactly as the ledger holds it — split rules included. The one to keep as a backup.")
                }

                Section {
                    LabeledContent("Entries", value: "\(store.entries.count)")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Export")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") { isExporting = true }
                        .disabled(store.entries.isEmpty)
                }
            }
            .fileExporter(
                isPresented: $isExporting,
                document: document,
                contentType: format == .csv ? .commaSeparatedText : .json,
                defaultFilename: "halfhazard-\(Self.today).\(format.fileExtension)"
            ) { _ in
                dismiss()
            }
        }
        .frame(minWidth: 360, minHeight: 300)
    }

    private static var today: String {
        LedgerExport.dateFormatter.string(from: Date())
    }
}

/// Pick a file, see what is in it, then decide.
struct ImportSheet: View {
    let store: LedgerStore
    @Environment(\.dismiss) private var dismiss

    @State private var isPicking = true
    @State private var result: LedgerExport.ImportResult?
    @State private var filename = ""
    @State private var isWriting = false
    @State private var written: Int?

    var body: some View {
        NavigationStack {
            SwiftUI.Group {
                if let written {
                    ContentUnavailableView(
                        "Imported \(written) \(written == 1 ? "entry" : "entries")",
                        systemImage: "checkmark.circle",
                        description: Text("They are in the ledger for both of you.")
                    )
                } else if let result {
                    preview(result)
                } else {
                    ContentUnavailableView(
                        "Choose a file",
                        systemImage: "square.and.arrow.down",
                        description: Text("A CSV or a JSON file exported from halfhazard.")
                    )
                }
            }
            .navigationTitle("Import")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(written == nil ? "Cancel" : "Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let result, written == nil {
                        Button("Import \(result.entries.count)") {
                            Task {
                                isWriting = true
                                written = await store.importEntries(result.entries)
                                isWriting = false
                            }
                        }
                        .disabled(result.entries.isEmpty || isWriting)
                    }
                }
            }
            .fileImporter(
                isPresented: $isPicking,
                allowedContentTypes: [.commaSeparatedText, .json, .plainText]
            ) { outcome in
                switch outcome {
                case .success(let url):
                    load(url)
                case .failure:
                    dismiss()
                }
            }
        }
        .frame(minWidth: 380, minHeight: 380)
    }

    /// What the file holds, before anything is written.
    private func preview(_ result: LedgerExport.ImportResult) -> some View {
        List {
            Section {
                LabeledContent("File", value: filename)
                LabeledContent("Ready to import", value: "\(result.entries.count)")
                if !result.issues.isEmpty {
                    LabeledContent("Skipped", value: "\(result.issues.count)")
                        .foregroundStyle(.orange)
                }
            } footer: {
                if result.entries.contains(where: { entry in store.entries.contains { $0.id == entry.id } }) {
                    Text("Some of these are already in the ledger and will be replaced rather than added again.")
                }
            }

            if !result.issues.isEmpty {
                Section("Rows that could not be read") {
                    ForEach(result.issues, id: \.self) { issue in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(issue.row > 0 ? "Row \(issue.row)" : "File")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(issue.message).font(.callout)
                        }
                    }
                }
            }

            if !result.entries.isEmpty {
                Section("Entries") {
                    ForEach(result.entries.prefix(20)) { entry in
                        EntryRow(entry: entry, viewerId: store.viewerId, name: store.name(for:))
                    }
                    if result.entries.count > 20 {
                        Text("and \(result.entries.count - 20) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func load(_ url: URL) {
        // A file chosen from outside the sandbox is only readable while its security scope is
        // open, and only if the open succeeded.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            result = .init(entries: [], issues: [.init(row: 0, message: "That file could not be read.")])
            return
        }
        filename = url.lastPathComponent
        result = store.preview(data, named: filename)
    }
}
