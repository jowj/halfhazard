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

struct iOSContentView: View {
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
    
    // iOS-specific main view
    var mainAppView: some View {
        TabView {
            // Groups tab
            TabItemView(label: "Groups", systemImage: "folder") {
                NavigationView {
                    GroupListView(
                        groupViewModel: groupViewModel,
                        expenseViewModel: expenseViewModel
                    )
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                }
            }
            
            // Selected group expenses tab (only active when a group is selected)
            TabItemView(label: "Expenses", systemImage: "creditcard") {
                if let selectedGroup = groupViewModel.selectedGroup {
                    NavigationView {
                        ExpenseListView(
                            group: selectedGroup,
                            expenseViewModel: expenseViewModel,
                            groupViewModel: groupViewModel
                        )
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                    }
                } else {
                    ContentUnavailableView("Select a Group",
                                          systemImage: "list.bullet.circle",
                                          description: Text("Choose a group from the Groups tab"))
                }
            }
            
            // Profile/Settings tab
            TabItemView(label: "Profile", systemImage: "person.circle") {
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
            }
        }
        .onAppear {
            // Update ViewModels with current user and dev mode
            updateViewModels(user: currentUser, devMode: useDevMode)
            
            Task {
                await groupViewModel.loadGroups()
            }
        }
        .onChange(of: groupViewModel._selectedGroup) { newValue in
            if let previousValue = groupViewModel._selectedGroup {
                print("ContentView: Group selection changed from \(previousValue.name) to \(newValue?.name ?? "nil")")
            } else {
                print("ContentView: Group selection changed to \(newValue?.name ?? "nil")")
            }
            
            if let group = newValue {
                expenseViewModel.updateContext(user: currentUser, groupId: group.id, devMode: useDevMode)
                Task {
                    await expenseViewModel.loadExpenses(forGroupId: group.id)
                }
            }
        }
        .onChange(of: groupViewModel.errorMessage) { newValue in
            if let error = newValue {
                errorMessage = error
            }
        }
        .onChange(of: expenseViewModel.errorMessage) { newValue in
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
