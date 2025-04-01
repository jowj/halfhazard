//
//  ContentView.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2025-01-12.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ContentView: View {
    @StateObject private var userService = UserService()
    @StateObject private var groupViewModel = GroupViewModel(currentUser: nil)
    @StateObject private var expenseViewModel = ExpenseViewModel(currentUser: nil)
    
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
    
    var mainAppView: some View {
        #if os(macOS)
        macOSMainView
        #else
        iOSMainView
        #endif
    }
    
    // macOS-specific main view
    var macOSMainView: some View {
        NavigationSplitView {
            // Sidebar - Groups (without its own NavigationStack)
            macOSSidebarContent
        } detail: {
            // Detail view with NavigationStack for forms
            macOSDetailContent
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    if let user = currentUser {
                        Text(user.displayName ?? user.email)
                        Divider()
                    }
                    
                    Button("Sign Out") {
                        Task {
                            await signOut()
                        }
                    }
                } label: {
                    Label("Account", systemImage: "person.circle")
                }
            }
        }
        .onAppear {
            // Update ViewModels with current user and dev mode
            updateViewModels(user: currentUser, devMode: useDevMode)
            
            Task {
                await groupViewModel.loadGroups()
            }
        }
        .onChange(of: groupViewModel._selectedGroup) { oldValue, newValue in
            print("ContentView: Group selection changed from \(oldValue?.name ?? "nil") to \(newValue?.name ?? "nil")")
            if let group = newValue {
                expenseViewModel.updateContext(user: currentUser, groupId: group.id, devMode: useDevMode)
                Task {
                    await expenseViewModel.loadExpenses(forGroupId: group.id)
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
    
    // Sidebar content for macOS
    private var macOSSidebarContent: some View {
        GroupListView(
            groupViewModel: groupViewModel,
            expenseViewModel: expenseViewModel,
            isInSplitView: true
        )
        .frame(minWidth: 250)
    }
    
    // Helper function for group destinations
    @ViewBuilder
    private func macOSGroupDestination(_ destination: GroupViewModel.Destination) -> some View {
        switch destination {
        case .createGroup:
            CreateGroupForm(viewModel: groupViewModel)
                .navigationTitle("Create Group")
        case .joinGroup:
            JoinGroupForm(viewModel: groupViewModel)
                .navigationTitle("Join Group")
        case .manageGroup(let group):
            ManageGroupSheet(group: group, viewModel: groupViewModel)
                .navigationTitle("Manage Group")
        }
    }
    
    // Helper function for expense destinations
    @ViewBuilder
    private func macOSExpenseDestination(_ destination: ExpenseViewModel.Destination) -> some View {
        switch destination {
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
                EmptyView()
            }
        }
    }
    
    // Detail content for macOS - simplified navigation approach
    private var macOSDetailContent: some View {
        NavigationStack {
            // Main content
            if let selectedGroup = groupViewModel.selectedGroup, 
               groupViewModel.navigationPath.isEmpty && expenseViewModel.navigationPath.isEmpty {
                // Show the expense list when a group is selected and no navigation is active
                ExpenseListView(
                    group: selectedGroup, 
                    expenseViewModel: expenseViewModel,
                    groupViewModel: groupViewModel,
                    isInSplitView: true
                )
            } else if !groupViewModel.navigationPath.isEmpty, let dest = groupViewModel.navigationDestination {
                // Group-related navigation - using a computed property
                switch dest {
                case .createGroup:
                    CreateGroupForm(viewModel: groupViewModel)
                        .navigationTitle("Create Group")
                case .joinGroup:
                    JoinGroupForm(viewModel: groupViewModel)
                        .navigationTitle("Join Group")
                case .manageGroup(let group):
                    ManageGroupSheet(group: group, viewModel: groupViewModel)
                        .navigationTitle("Manage Group")
                case nil:
                    // Fallback - should not happen
                    Text("Invalid navigation state - group")
                }
            } else if let dest = expenseViewModel.navigationDestination {
                // Expense-related navigation
                switch dest {
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
                case nil:
                    // Fallback - should not happen
                    Text("Invalid navigation state - expense")
                }
            } else {
                // No group selected and no navigation
                ContentUnavailableView(
                    "Select a Group",
                    systemImage: "arrow.left",
                    description: Text("Choose a group from the sidebar")
                )
            }
        }
        .onAppear {
            print("macOSDetailContent appeared")
        }
    }
    
    // Helper view to simplify the navigation stack
    private struct DetailContentRoot: View {
        let selectedGroup: Group?
        let expenseViewModel: ExpenseViewModel
        let groupViewModel: GroupViewModel
        var isShowingExpenseNavigation: Bool = true
        
        var body: some View {
            if !isShowingExpenseNavigation {
                // If expense navigation is active, don't show the main content
                EmptyView()
            } else if let selectedGroup = selectedGroup {
                ExpenseListView(
                    group: selectedGroup, 
                    expenseViewModel: expenseViewModel,
                    groupViewModel: groupViewModel,
                    isInSplitView: true
                )
            } else {
                // Display any forms in detail view or empty state
                if !groupViewModel.navigationPath.isEmpty {
                    // Show an empty view - the destinations will display properly
                    EmptyView()
                } else {
                    // Empty state
                    ContentUnavailableView(
                        "Select a Group",
                        systemImage: "arrow.left",
                        description: Text("Choose a group from the sidebar")
                    )
                }
            }
        }
    }
    
    // iOS-specific main view
    #if os(iOS)
    var iOSMainView: some View {
        TabView {
            // Groups tab
            NavigationView {
                GroupListView(
                    groupViewModel: groupViewModel,
                    expenseViewModel: expenseViewModel,
                    isInSplitView: false // Use its own NavigationStack on iOS
                )
                .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Groups", systemImage: "folder")
            }
            
            // Selected group expenses tab (only active when a group is selected)
            Group {
                if let selectedGroup = groupViewModel.selectedGroup {
                    NavigationView {
                        ExpenseListView(
                            group: selectedGroup, 
                            expenseViewModel: expenseViewModel,
                            groupViewModel: groupViewModel,
                            isInSplitView: false // Use its own NavigationStack on iOS
                        )
                        .navigationBarTitleDisplayMode(.inline)
                    }
                } else {
                    ContentUnavailableView("Select a Group",
                                          systemImage: "list.bullet.circle",
                                          description: Text("Choose a group from the Groups tab"))
                }
            }
            .tabItem {
                Label("Expenses", systemImage: "creditcard")
            }
            
            // Profile/Settings tab
            NavigationView {
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
                                await signOut()
                            }
                        }
                        .foregroundColor(.red)
                    }
                }
                .navigationTitle("Profile")
            }
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    if let user = currentUser {
                        Text(user.displayName ?? user.email)
                        Divider()
                    }
                    
                    Button("Sign Out") {
                        Task {
                            await signOut()
                        }
                    }
                } label: {
                    Label("Account", systemImage: "person.circle")
                }
            }
        }
        .onAppear {
            // Update ViewModels with current user and dev mode
            updateViewModels(user: currentUser, devMode: useDevMode)
            
            Task {
                await groupViewModel.loadGroups()
            }
        }
        .onChange(of: groupViewModel._selectedGroup) { oldValue, newValue in
            print("ContentView: Group selection changed from \(oldValue?.name ?? "nil") to \(newValue?.name ?? "nil")")
            if let group = newValue {
                expenseViewModel.updateContext(user: currentUser, groupId: group.id, devMode: useDevMode)
                Task {
                    await expenseViewModel.loadExpenses(forGroupId: group.id)
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
    #endif
    
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
            let errorCode = error.code
            let errorDomain = error.domain
            
            print("Sign in error domain: \(errorDomain), code: \(errorCode)")
            print("Error details: \(error)")
            
            // Look for configuration not found error
            let nsError = error as NSError
            if let underlyingError = nsError.userInfo["NSUnderlyingError"] as? NSError,
               let firebaseError = underlyingError.userInfo["NSUnderlyingError"] as? NSError,
               let data = firebaseError.userInfo["data"] as? Data,
               let jsonString = String(data: data, encoding: .utf8),
               jsonString.contains("CONFIGURATION_NOT_FOUND") {
                
                errorMessage = """
                Firebase Authentication is not properly configured.
                
                Please go to the Firebase Console and:
                1. Go to Authentication section
                2. Click "Get Started" or go to "Sign-in method"
                3. Enable Email/Password authentication
                4. Save the changes
                """
                return
            }
            
            // Provide more specific error messages based on common Firebase Auth errors
            if errorDomain == "FIRAuthErrorDomain" {
                switch errorCode {
                case 17020:
                    errorMessage = "No internet connection. Please check your network and try again."
                case 17009:
                    errorMessage = "The email or password is incorrect."
                case 17008:
                    errorMessage = "The email address is badly formatted."
                case 17011:
                    errorMessage = "This user has been disabled. Please contact support."
                case 17995:
                    errorMessage = """
                    Keychain access error during development.
                    
                    As a workaround, try:
                    1. Quit and restart the app
                    2. Sign in with the same credentials again
                    3. If using a simulator, try resetting the simulator
                    
                    Note: This is a common issue during development and doesn't affect production builds.
                    """
                case 17999:
                    errorMessage = "Firebase Authentication is not properly configured. Please enable Email/Password authentication in the Firebase Console."
                default:
                    errorMessage = "Sign in failed: \(error.localizedDescription)"
                }
            } else if errorDomain == "FIRFirestoreErrorDomain" && errorCode == 7 {
                errorMessage = """
                Firestore permissions error.
                
                You need to set up Firestore security rules. Please:
                1. Go to Firebase Console -> Firestore Database
                2. Go to the Rules tab
                3. Replace rules with the content from the firestore.rules.dev file for development
                4. Publish the rules
                
                For development, you can use permissive rules. Make sure to use proper rules in production.
                """
            } else if errorDomain == "NSCocoaErrorDomain" && errorCode == 4865 {
                // Handle the decoding error when the user document doesn't exist
                errorMessage = """
                User document not found in Firestore. This can happen if:
                1. You're using an account created outside this app
                2. The Firestore database was reset
                
                Try creating a new account or using development mode.
                """
            } else if errorDomain == "UserService" && errorCode == 404 {
                errorMessage = "User document doesn't exist in Firestore. Try registering a new account."
            } else {
                errorMessage = "Sign in failed: \(error.localizedDescription)"
            }
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
            let errorCode = error.code
            let errorDomain = error.domain
            
            print("Registration error domain: \(errorDomain), code: \(errorCode)")
            print("Error details: \(error)")
            
            // Look for configuration not found error
            let nsError = error as NSError
            if let underlyingError = nsError.userInfo["NSUnderlyingError"] as? NSError,
               let firebaseError = underlyingError.userInfo["NSUnderlyingError"] as? NSError,
               let data = firebaseError.userInfo["data"] as? Data,
               let jsonString = String(data: data, encoding: .utf8),
               jsonString.contains("CONFIGURATION_NOT_FOUND") {
                
                errorMessage = """
                Firebase Authentication is not properly configured.
                
                Please go to the Firebase Console and:
                1. Go to Authentication section
                2. Click "Get Started" or go to "Sign-in method"
                3. Enable Email/Password authentication
                4. Save the changes
                """
                return
            }
            
            // Provide more specific error messages based on common Firebase Auth errors
            if errorDomain == "FIRAuthErrorDomain" {
                switch errorCode {
                case 17020:
                    errorMessage = "No internet connection. Please check your network and try again."
                case 17007:
                    errorMessage = "Email is already in use by another account."
                case 17008:
                    errorMessage = "The email address is badly formatted."
                case 17026:
                    errorMessage = "Password must be at least 6 characters."
                case 17995:
                    errorMessage = """
                    Keychain access error during development.
                    
                    As a workaround, try:
                    1. Quit and restart the app
                    2. Sign in with the same credentials again
                    3. If using a simulator, try resetting the simulator
                    
                    Note: This is a common issue during development and doesn't affect production builds.
                    """
                case 17999:
                    errorMessage = "Firebase Authentication is not properly configured. Please enable Email/Password authentication in the Firebase Console."
                default:
                    errorMessage = "Registration failed: \(error.localizedDescription)"
                }
            } else if errorDomain == "FIRFirestoreErrorDomain" && errorCode == 7 {
                errorMessage = """
                Firestore permissions error.
                
                You need to set up Firestore security rules. Please:
                1. Go to Firebase Console -> Firestore Database
                2. Go to the Rules tab
                3. Replace rules with the content from the firestore.rules.dev file for development
                4. Publish the rules
                
                For development, you can use permissive rules. Make sure to use proper rules in production.
                """
            } else if errorDomain == "NSCocoaErrorDomain" && errorCode == 4865 {
                // Handle the decoding error when the user document doesn't exist
                errorMessage = """
                User document not found in Firestore. This can happen if:
                1. You're using an account created outside this app
                2. The Firestore database was reset
                
                Try creating a new account or using development mode.
                """
            } else if errorDomain == "UserService" && errorCode == 404 {
                errorMessage = "User document doesn't exist in Firestore. Try registering a new account."
            } else {
                errorMessage = "Registration failed: \(error.localizedDescription)"
            }
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

#Preview {
    ContentView()
}