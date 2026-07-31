//
//  LedgerScreen.swift
//  halfhazard
//

import SwiftUI

/// The whole app, on one screen: what you stand at, and everything that got you there.
///
/// Replaces the group list, the group detail, the expense list and the tab bar. There is
/// one ledger and it is always the one on screen, so there is nothing to select and no
/// "choose a group" empty state to land in.
struct LedgerScreen: View {
    @State private var store: LedgerStore
    @State private var showingAdd = false
    @State private var showingSettle = false
    @State private var showingTemplates = false
    @State private var showingProfile = false
    @State private var userService = UserService()

    /// Signing out is the only thing left over from the old chrome that still needs a home.
    private let onSignOut: (() -> Void)?

    init(
        viewerId: String,
        source: LedgerDataSource = FirestoreLedgerService(),
        onSignOut: (() -> Void)? = nil
    ) {
        _store = State(initialValue: LedgerStore(source: source, viewerId: viewerId))
        self.onSignOut = onSignOut
    }

    /// For previews and tests, which supply their own store.
    init(store: LedgerStore, onSignOut: (() -> Void)? = nil) {
        _store = State(initialValue: store)
        self.onSignOut = onSignOut
    }

    /// Directly in the bar rather than `.secondaryAction`, which on iOS folds the item into
    /// the system overflow menu — putting this menu inside another menu.
    private var menuPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .automatic
        #endif
    }

    private var partnerName: String {
        store.partnerId.map { store.name(for: $0) } ?? "them"
    }

    var body: some View {
        NavigationStack {
            // Qualified because the app's own `Group` model shadows SwiftUI's. Phase 5
            // deletes that type and this can go back to reading normally.
            SwiftUI.Group {
                if store.isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.ledger == nil {
                    noLedger
                } else {
                    feed
                }
            }
            .navigationTitle("halfhazard")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: {
                        Label("Add expense", systemImage: "plus")
                    }
                    .disabled(store.ledger == nil)
                    .keyboardShortcut("n", modifiers: .command)
                }
                ToolbarItem(placement: menuPlacement) {
                    Menu {
                        Button {
                            showingTemplates = true
                        } label: {
                            Label("Templates", systemImage: "doc.on.doc")
                        }
                        .disabled(store.ledger == nil)

                        Button {
                            showingProfile = true
                        } label: {
                            Label("Your profile", systemImage: "person.crop.circle")
                        }
                        .disabled(store.viewer == nil)

                        if let onSignOut {
                            Divider()
                            Button("Sign out", role: .destructive, action: onSignOut)
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) { AddExpenseSheet(store: store) }
            .sheet(isPresented: $showingSettle) { SettleSheet(store: store) }
            .sheet(isPresented: $showingTemplates) { TemplatesSheet(store: store) }
            .sheet(isPresented: $showingProfile) {
                if let viewer = store.viewer {
                    EditProfileView(userService: userService, user: viewer) {
                        // Republish, so the name reaches the other person's screen.
                        Task { await store.refreshProfile() }
                    }
                }
            }
        }
        .task { await store.start() }
    }

    private var feed: some View {
        List {
            Section {
                BalanceHeader(
                    standing: store.standing,
                    partnerName: partnerName,
                    onSettle: { showingSettle = true }
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if let errorMessage = store.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }

            if store.entries.isEmpty {
                Section { emptyFeed }
            } else {
                ForEach(store.entriesByDay, id: \.day) { day, entries in
                    Section(day.formatted(.dateTime.weekday(.wide).month().day())) {
                        ForEach(entries) { entry in
                            EntryRow(entry: entry, viewerId: store.viewerId, name: store.name(for:))
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await store.delete(entry) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .refreshable { await store.start() }
    }

    private var emptyFeed: some View {
        ContentUnavailableView(
            "Nothing yet",
            systemImage: "cart",
            description: Text("Add the first expense and it will show up here for both of you.")
        )
    }

    private var noLedger: some View {
        ContentUnavailableView(
            "No ledger yet",
            systemImage: "book.closed",
            description: Text("You and \(partnerName) are not sharing a ledger on this account.")
        )
    }
}
