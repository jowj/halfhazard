//
//  iOSContentView.swift
//  halfhazard_ios
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// Helper view for tab items
struct TabItemView<Content: View>: View {
    let label: String
    let systemImage: String
    let content: () -> Content
    
    init(label: String, systemImage: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.systemImage = systemImage
        self.content = content
    }
    
    var body: some View {
        content()
            .tabItem {
                Label(label, systemImage: systemImage)
            }
    }
}

// Helper view for tab content
struct TabContentWrapper: View {
    let tab: AppNavigation.TabSelection
    let groupViewModel: GroupViewModel
    let expenseViewModel: ExpenseViewModel
    let currentUser: User?
    let appNavigation: AppNavigation
    let signOutAction: () async -> Void
    
    var body: some View {
        VStack {
            switch tab {
            case .groups:
                // Groups tab content
                GroupListView(
                    groupViewModel: groupViewModel,
                    expenseViewModel: expenseViewModel,
                    appNavigationRef: appNavigation
                )
                .navigationBarTitleDisplayMode(.inline)
                
            case .expenses:
                // Expenses tab content
                if let selectedGroup = groupViewModel.selectedGroup {
                    ExpenseListView(
                        group: selectedGroup,
                        expenseViewModel: expenseViewModel,
                        groupViewModel: groupViewModel,
                        appNavigationRef: appNavigation
                    )
                    .navigationBarTitleDisplayMode(.inline)
                } else {
                    ContentUnavailableView("Select a Group",
                                           systemImage: "list.bullet.circle",
                                           description: Text("Choose a group from the Groups tab"))
                }
                
            case .profile:
                // Profile tab content
                List {
                    if let user = currentUser {
                        Section(header: Text("Account")) {
                            VStack(alignment: .leading) {
                                Text(user.displayName ?? "User")
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    
                    Section {
                        Button("Sign Out") {
                            Task {
                                await signOutAction()
                            }
                        }
                        .foregroundColor(.red)
                    }
                }
                .navigationTitle("Profile")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Helper view for navigation destinations
struct NavigationDestinationWrapper: View {
    let destination: AppNavigation.Destination
    let groupViewModel: GroupViewModel
    let expenseViewModel: ExpenseViewModel
    
    var body: some View {
        switch destination {
        // Group destinations
        case .createGroup:
            CreateGroupForm(viewModel: groupViewModel)
                .navigationTitle("Create Group")
                
        case .joinGroup:
            JoinGroupForm(viewModel: groupViewModel)
                .navigationTitle("Join Group")
                
        case .manageGroup(let group):
            ManageGroupSheet(group: group, viewModel: groupViewModel)
                .navigationTitle("Manage Group")
            
        // Expense destinations
        case .createExpense:
            CreateExpenseForm(viewModel: expenseViewModel)
                .navigationTitle("Add Expense")
                
        case .editExpense:
            EditExpenseForm(viewModel: expenseViewModel)
                .navigationTitle("Edit Expense")
                
        case .expenseDetail(let expense):
            if let group = groupViewModel.selectedGroup {
                ExpenseDetailView(expense: expense, group: group, expenseViewModel: expenseViewModel)
                    .navigationTitle("Expense Details")
            } else {
                Text("Error: Missing group for expense detail")
            }
        }
    }
}

struct iOSContentView: View {
    @StateObject private var userService = UserService()
    @StateObject private var groupViewModel = GroupViewModel(currentUser: nil)
    @StateObject private var expenseViewModel = ExpenseViewModel(currentUser: nil)
    @StateObject private var appNavigation = AppNavigation()
    
    // Dev mode state
    @State private var useDevMode = false
    @State private var showingLoginSheet = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isRegistering = false
    @State private var currentUser: User?
    @State private var errorMessage: String?
    
    // We need a separate binding for the alert to work correctly
    var showError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
    
    var body: some View {
        if currentUser == nil {
            authView
                .onAppear {
                    Task {
                        await checkForExistingUser()
                    }
                }
                .alert("Error", isPresented: showError) {
                    Button("OK", action: {})
                } message: {
                    if let message = errorMessage {
                        Text(message)
                    }
                }
        } else {
            mainAppView
                .alert("Error", isPresented: showError) {
                    Button("OK", action: {})
                } message: {
                    if let message = errorMessage {
                        Text(message)
                    }
                }
        }
    }
    
    // iOS-specific main view with NavigationStack
    var mainAppView: some View {
        NavigationStack(path: $appNavigation.path) {
            CustomTabView(selection: $appNavigation.tabSelection) { tab in
                TabContentWrapper(
                    tab: tab,
                    groupViewModel: groupViewModel,
                    expenseViewModel: expenseViewModel,
                    currentUser: currentUser,
                    appNavigation: appNavigation,
                    signOutAction: signOut
                )
            }
            
            // Navigation destinations
            .navigationDestination(for: AppNavigation.Destination.self) { destination in
                NavigationDestinationWrapper(
                    destination: destination,
                    groupViewModel: groupViewModel,
                    expenseViewModel: expenseViewModel
                )
            }
        }
        .onAppear {
            // Setup app navigation with view models
            appNavigation.setViewModels(groupViewModel: groupViewModel, expenseViewModel: expenseViewModel)
            
            // Update ViewModels with current user and dev mode
            updateViewModels(user: currentUser, devMode: useDevMode)
            
            Task {
                await groupViewModel.loadGroups()
            }
        }
        .onChange(of: groupViewModel._selectedGroup) { _, newValue in
            if let group = newValue {
                expenseViewModel.updateContext(user: currentUser, groupId: group.id, devMode: useDevMode)
                Task {
                    await expenseViewModel.loadExpenses(forGroupId: group.id)
                }
            }
        }
        // When tab selection changes, we need to handle the navigation
        .onChange(of: appNavigation.tabSelection) { _, newValue in
            // If switching to expenses tab, make sure a group is selected
            if newValue == .expenses && groupViewModel.selectedGroup == nil && !groupViewModel.groups.isEmpty {
                groupViewModel.selectedGroup = groupViewModel.groups.first
                
                // Load expenses for the selected group
                if let group = groupViewModel.selectedGroup {
                    expenseViewModel.updateContext(user: currentUser, groupId: group.id, devMode: useDevMode)
                    Task {
                        await expenseViewModel.loadExpenses(forGroupId: group.id)
                    }
                }
            }
        }
        .onChange(of: groupViewModel.errorMessage) { _, newValue in
            if let error = newValue {
                errorMessage = error
            }
        }
        .onChange(of: expenseViewModel.errorMessage) { _, newValue in
            if let error = newValue {
                errorMessage = error
            }
        }
    }
    
    var authView: some View {
        AuthView(
            email: $email,
            password: $password,
            displayName: $displayName,
            isRegistering: $isRegistering,
            useDevMode: $useDevMode,
            signInAction: signIn,
            registerAction: registerUser
        )
    }
    
    // Helper function to update ViewModels with current user
    private func updateViewModels(user: User?, devMode: Bool) {
        // Update GroupViewModel
        groupViewModel.currentUser = user
        groupViewModel.useDevMode = devMode
        
        // Update ExpenseViewModel
        expenseViewModel.updateContext(user: user, groupId: nil, devMode: devMode)
    }
    
    // Authentication functions
    private func checkForExistingUser() async {
        // Check dev mode first
        if useDevMode {
            if let devUser = DevAuthService.shared.getCurrentUser() {
                self.currentUser = devUser
                // Update ViewModels with current user and dev mode
                updateViewModels(user: devUser, devMode: true)
                return
            }
        }
        
        // Then check Firebase
        do {
            if let user = try await userService.getCurrentUser() {
                self.currentUser = user
                // Update ViewModels with current user and dev mode
                updateViewModels(user: user, devMode: useDevMode)
            }
        } catch {
            print("No current user: \(error)")
            // No need to show error message for no user
        }
    }
    
    private func signIn() async {
        print("Starting sign in for email: \(email)")
        
        if useDevMode {
            print("Using development authentication mode")
            if let devUser = DevAuthService.shared.signIn(email: email, password: password) {
                print("Dev sign in successful for user: \(devUser.uid)")
                self.currentUser = devUser
                
                // Update ViewModels with current user and dev mode
                updateViewModels(user: devUser, devMode: true)
                
                // Reset fields
                email = ""
                password = ""
                return
            } else {
                errorMessage = "Invalid email or password in development mode. Email must contain @ and password must be at least 6 characters."
                return
            }
        }
        
        // Regular Firebase login
        do {
            print("Signing in with Firebase...")
            let user = try await userService.signIn(email: email, password: password)
            print("Sign in successful for user: \(user.uid)")
            self.currentUser = user
            
            // Update ViewModels with current user and dev mode
            updateViewModels(user: user, devMode: useDevMode)
            
            // Reset fields
            email = ""
            password = ""
        } catch let error as NSError {
            errorMessage = "Sign in failed: \(error.localizedDescription)"
        }
    }
    
    private func registerUser() async {
        print("Starting registration for email: \(email)")
        
        if useDevMode {
            print("Using development authentication mode for registration")
            if let devUser = DevAuthService.shared.signIn(email: email, password: password) {
                print("Dev sign in successful for user: \(devUser.uid)")
                self.currentUser = devUser
                
                // Update ViewModels with current user and dev mode
                updateViewModels(user: devUser, devMode: true)
                
                // Reset fields
                email = ""
                password = ""
                displayName = ""
                return
            } else {
                errorMessage = "Invalid email or password in development mode. Email must contain @ and password must be at least 6 characters."
                return
            }
        }
        
        do {
            print("Creating user...")
            let user = try await userService.createUser(email: email, password: password, displayName: displayName)
            print("User created successfully with ID: \(user.uid)")
            self.currentUser = user
            
            // Update ViewModels with current user and dev mode
            updateViewModels(user: user, devMode: useDevMode)
            
            // Reset fields
            email = ""
            password = ""
            displayName = ""
        } catch let error as NSError {
            errorMessage = "Registration failed: \(error.localizedDescription)"
        }
    }
    
    private func signOut() async {
        if useDevMode {
            // Just reset the dev user
            DevAuthService.shared.signOut()
            self.currentUser = nil
            
            // Update ViewModels
            updateViewModels(user: nil, devMode: true)
            return
        }
        
        do {
            try userService.signOut()
            self.currentUser = nil
            
            // Update ViewModels
            updateViewModels(user: nil, devMode: false)
        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
            print("Sign out error: \(error)")
        }
    }
}

struct iOSContentView_Previews: PreviewProvider {
    static var previews: some View {
        iOSContentView()
    }
}
