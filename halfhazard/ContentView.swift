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
    @StateObject private var groupService = GroupService()
    @StateObject private var expenseService = ExpenseService()
    
    // Dev mode state
    @State private var useDevMode = false
    
    @State private var groups: [Group] = []
    @State private var expenses: [Expense] = []
    @State private var selectedGroup: Group?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingCreateGroupSheet = false
    @State private var newGroupName = ""
    @State private var newGroupDescription = ""
    
    // Expense creation state
    @State private var showingCreateExpenseSheet = false
    @State private var newExpenseAmount = ""
    @State private var newExpenseDescription = ""
    @State private var selectedSplitType = SplitType.equal
    
    @State private var showingLoginSheet = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isRegistering = false
    @State private var currentUser: User?
    
    var body: some View {
        ZStack {
            if currentUser == nil {
                authView
                    .onAppear {
                        Task {
                            await checkForExistingUser()
                        }
                    }
            } else {
                mainAppView
            }
        }
        .alert(
            "Error",
            isPresented: Binding<Bool>(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ),
            actions: {
                Button("OK") {
                    errorMessage = nil
                }
            },
            message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        )
    }
    
    var mainAppView: some View {
        HStack(spacing: 0) {
            // MARK: - Groups Sidebar (Left Column)
            VStack(spacing: 0) {
                // Title and toolbar for groups
                HStack {
                    Text("Groups")
                        .font(.title)
                        .padding([.top, .horizontal])
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: { 
                            showingCreateGroupSheet = true
                        }) {
                            Image(systemName: "plus")
                        }
                        
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
                            Image(systemName: "person.circle")
                        }
                    }
                    .padding([.top, .trailing])
                }
                
                Divider()
                
                // Groups List
                List {
                    ForEach(groups) { group in
                        Button(action: {
                            selectedGroup = group
                        }) {
                            HStack {
                                Text(group.name)
                                    .font(.headline)
                                Spacer()
                                if selectedGroup?.id == group.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.vertical, 4)
                        .background(selectedGroup?.id == group.id ? Color.blue.opacity(0.1) : Color.clear)
                        .cornerRadius(4)
                    }
                }
                .overlay {
                    if groups.isEmpty && !isLoading {
                        ContentUnavailableView("No Groups", 
                                              systemImage: "person.3",
                                              description: Text("Create or join a group to get started"))
                    }
                    
                    if isLoading {
                        ProgressView()
                    }
                }
            }
            .frame(width: 250)
            .background(Color(.windowBackgroundColor))
            
            Divider()
            
            // MARK: - Expenses (Right Column)
            if let selectedGroup = selectedGroup {
                VStack(spacing: 0) {
                    // Group header
                    HStack {
                        Text(selectedGroup.name)
                            .font(.largeTitle.bold())
                        Spacer()
                        Button(action: {
                            showingCreateExpenseSheet = true
                        }) {
                            Label("Add Expense", systemImage: "plus.circle.fill")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding([.horizontal, .top])
                    .padding(.bottom, 8)
                    
                    Divider()
                    
                    // Expenses list
                    List {
                        ForEach(expenses, id: \.id) { expense in
                            ExpenseRow(expense: expense, group: selectedGroup)
                        }
                    }
                    .listStyle(.plain)
                    .overlay {
                        if expenses.isEmpty && !isLoading {
                            ContentUnavailableView("No Expenses", 
                                                 systemImage: "dollarsign.circle",
                                                 description: Text("Add an expense to get started"))
                        }
                        
                        if isLoading {
                            ProgressView()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // No group selected
                ContentUnavailableView("Select a Group", 
                                      systemImage: "arrow.left",
                                      description: Text("Choose a group from the sidebar"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingCreateGroupSheet) {
            createGroupView
        }
        .sheet(isPresented: $showingCreateExpenseSheet) {
            createExpenseView
                .frame(minWidth: 700, maxWidth: .infinity, minHeight: 700, maxHeight: .infinity)
        }
        .task {
            await loadGroups()
        }
        .onChange(of: selectedGroup) { oldValue, newValue in
            if let group = newValue {
                Task {
                    await loadExpenses(for: group)
                }
            } else {
                expenses = []
            }
        }
    }
    
    private func loadGroups() async {
        guard currentUser != nil else { return }
        
        // Skip for dev mode since we don't have real Firebase data
        if useDevMode {
            isLoading = false
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        var loadedGroups: [Group] = []
        
        for groupId in currentUser!.groupIds {
            do {
                let group = try await groupService.getGroupInfo(groupID: groupId)
                loadedGroups.append(group)
            } catch let error as NSError {
                if error.domain == "FIRFirestoreErrorDomain" && error.code == 7 {
                    // If we hit a permissions error, show the user a helpful message
                    errorMessage = """
                    Firestore permissions error.
                    
                    You need to set up Firestore security rules. Please:
                    1. Go to Firebase Console -> Firestore Database
                    2. Go to the Rules tab
                    3. Replace rules with the content from the firestore.rules.dev file for development
                    4. Publish the rules
                    
                    For development, you can use permissive rules. Make sure to use proper rules in production.
                    """
                    print("Firestore permissions error loading group \(groupId): \(error)")
                    return
                } else {
                    print("Error loading group \(groupId): \(error)")
                }
            }
        }
        
        groups = loadedGroups.sorted(by: { $0.name < $1.name })
        
        if groups.count > 0 && selectedGroup == nil {
            selectedGroup = groups.first
        }
    }
    
    private func loadExpenses(for group: Group) async {
        // Skip for dev mode since we don't have real Firebase data
        if useDevMode {
            isLoading = false
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            expenses = try await expenseService.getExpensesForGroup(groupId: group.id)
        } catch let error as NSError {
            if error.domain == "FIRFirestoreErrorDomain" && error.code == 7 {
                errorMessage = """
                Firestore permissions error.
                
                You need to set up Firestore security rules. Please:
                1. Go to Firebase Console -> Firestore Database
                2. Go to the Rules tab
                3. Replace rules with the content from the firestore.rules.dev file for development
                4. Publish the rules
                
                For development, you can use permissive rules. Make sure to use proper rules in production.
                """
            } else if error.domain == "ExpenseService" && error.code == 9 {
                // This is a missing index error
                let indexURL = error.userInfo["indexURL"] as? String ?? ""
                
                errorMessage = """
                Firestore index required.
                
                You need to create a composite index for the expenses collection.
                
                Please go to this URL to create the index:
                \(indexURL)
                
                Just click "Create index" on the page that opens. It may take a few minutes for the index to be ready.
                """
            } else if error.domain == "FIRFirestoreErrorDomain" && error.code == 9 {
                // Generic index error backup
                errorMessage = """
                Firestore index required.
                
                You need to create a composite index for this query. The error message contains a link to create it.
                Check the logs for the full URL or use the firestore.indexes.json file to deploy indexes.
                """
            } else {
                errorMessage = "Failed to load expenses: \(error.localizedDescription)"
            }
            print("Error loading expenses: \(error)")
        }
    }
    
    private func createGroup() async {
        guard !newGroupName.isEmpty else { return }
        
        // Handle dev mode - create mock group
        if useDevMode {
            let groupId = "dev-group-\(UUID().uuidString)"
            let timestamp = Timestamp()
            let mockGroup = Group(
                id: groupId,
                name: newGroupName,
                memberIds: [currentUser?.uid ?? "dev-user"],
                createdBy: currentUser?.uid ?? "dev-user",
                createdAt: timestamp,
                settings: Settings(name: newGroupDescription.isEmpty ? "" : newGroupDescription)
            )
            
            // Add to our array
            groups.append(mockGroup)
            
            // Sort the groups
            groups.sort { $0.name < $1.name }
            
            // Select the new group
            selectedGroup = mockGroup
            
            // Reset form fields
            newGroupName = ""
            newGroupDescription = ""
            
            // Close the sheet
            showingCreateGroupSheet = false
            return
        }
        
        do {
            let group = try await groupService.createGroup(groupName: newGroupName, groupDescription: newGroupDescription.isEmpty ? nil : newGroupDescription)
            
            // Add the new group to our array
            groups.append(group)
            
            // Sort the groups by name
            groups.sort { $0.name < $1.name }
            
            // Select the new group
            selectedGroup = group
            
            // Reset form fields
            newGroupName = ""
            newGroupDescription = ""
            
            // Close the sheet
            showingCreateGroupSheet = false
        } catch let error as NSError {
            if error.domain == "FIRFirestoreErrorDomain" && error.code == 7 {
                errorMessage = """
                Firestore permissions error.
                
                You need to set up Firestore security rules. Please:
                1. Go to Firebase Console -> Firestore Database
                2. Go to the Rules tab
                3. Replace rules with the content from the firestore.rules.dev file for development
                4. Publish the rules
                
                For development, you can use permissive rules. Make sure to use proper rules in production.
                """
            } else {
                errorMessage = "Failed to create group: \(error.localizedDescription)"
            }
            print("Error creating group: \(error)")
        }
    }
    
    private func createExpense() async {
        guard let amount = Double(newExpenseAmount), amount > 0 else {
            errorMessage = "Please enter a valid expense amount"
            return
        }
        
        guard let selectedGroup = selectedGroup else {
            errorMessage = "No group selected"
            return
        }
        
        // Handle dev mode - create mock expense
        if useDevMode {
            let expenseId = "dev-expense-\(UUID().uuidString)"
            let timestamp = Timestamp()
            
            // Create default equal splits
            var splits: [String: Double] = [:]
            let memberCount = selectedGroup.memberIds.count
            let equalShare = amount / Double(memberCount)
            
            for memberId in selectedGroup.memberIds {
                splits[memberId] = equalShare
            }
            
            let mockExpense = Expense(
                id: expenseId,
                amount: amount,
                description: newExpenseDescription.isEmpty ? "Expense" : newExpenseDescription,
                groupId: selectedGroup.id,
                createdBy: currentUser?.uid ?? "dev-user",
                createdAt: timestamp,
                splitType: selectedSplitType,
                splits: splits
            )
            
            // Add to our array
            expenses.insert(mockExpense, at: 0) // Add to top (newest first)
            
            // Reset form fields
            resetExpenseForm()
            
            // Close the sheet
            showingCreateExpenseSheet = false
            return
        }
        
        do {
            // Create default equal splits
            var splits: [String: Double] = [:]
            let memberCount = selectedGroup.memberIds.count
            let equalShare = amount / Double(memberCount)
            
            for memberId in selectedGroup.memberIds {
                splits[memberId] = equalShare
            }
            
            let expense = try await expenseService.createExpense(
                amount: amount,
                description: newExpenseDescription.isEmpty ? nil : newExpenseDescription,
                groupId: selectedGroup.id,
                splitType: selectedSplitType,
                splits: splits
            )
            
            // Add the new expense to our array
            expenses.insert(expense, at: 0) // Add to the top since they're sorted newest first
            
            // Reset form fields
            resetExpenseForm()
            
            // Close the sheet
            showingCreateExpenseSheet = false
        } catch let error as NSError {
            if error.domain == "FIRFirestoreErrorDomain" && error.code == 7 {
                errorMessage = """
                Firestore permissions error.
                
                You need to set up Firestore security rules. Please:
                1. Go to Firebase Console -> Firestore Database
                2. Go to the Rules tab
                3. Replace rules with the content from the firestore.rules.dev file for development
                4. Publish the rules
                
                For development, you can use permissive rules. Make sure to use proper rules in production.
                """
            } else {
                errorMessage = "Failed to create expense: \(error.localizedDescription)"
            }
            print("Error creating expense: \(error)")
        }
    }
    
    private func resetExpenseForm() {
        newExpenseAmount = ""
        newExpenseDescription = ""
        selectedSplitType = .equal
    }
    
    private func isValidAmount(_ amount: String) -> Bool {
        guard let value = Double(amount) else { return false }
        return value > 0
    }
    
    var createGroupView: some View {
        VStack {
            HStack {
                Text("Create New Group")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                Button("Cancel") {
                    newGroupName = ""
                    newGroupDescription = ""
                    showingCreateGroupSheet = false
                }
            }
            .padding()
            
            Form {
                Section(header: Text("Group Details")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Group Name").font(.caption).foregroundColor(.secondary)
                        TextField("Enter a name for your group", text: $newGroupName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.bottom, 10)
                        
                        Text("Description (Optional)").font(.caption).foregroundColor(.secondary)
                        TextField("Enter a description", text: $newGroupDescription)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.vertical, 10)
                }
                
                Section {
                    Button("Create Group") {
                        Task {
                            await createGroup()
                        }
                    }
                    .disabled(newGroupName.isEmpty)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(minWidth: 350, minHeight: 400)
        }
    }
    
    var createExpenseView: some View {
        VStack {
            HStack {
                Text("Add Expense")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                Button("Cancel") {
                    resetExpenseForm()
                    showingCreateExpenseSheet = false
                }
            }
            .padding()
            
            Form {
                Section(header: Text("Expense Details")) {
                    // Amount field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Amount").font(.headline)
                        TextField("0.00", text: $newExpenseAmount)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.vertical, 4)
                    
                    // Description field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description").font(.headline)
                        TextField("What was this expense for?", text: $newExpenseDescription)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.vertical, 4)
                    
                    // Split type selector
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Split Type").font(.headline)
                        Picker("Split Type", selection: $selectedSplitType) {
                            Text("Equal").tag(SplitType.equal)
                            Text("Percentage").tag(SplitType.percentage)
                            Text("Custom").tag(SplitType.custom)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    Button("Create Expense") {
                        Task {
                            await createExpense()
                        }
                    }
                    .disabled(newExpenseAmount.isEmpty || !isValidAmount(newExpenseAmount))
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }
    
    var authView: some View {
        VStack(spacing: 20) {
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text("Halfhazard")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(isRegistering ? "Create a new account" : "Sign in to your account")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 15) {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if isRegistering {
                    TextField("Display Name", text: $displayName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disableAutocorrection(true)
                }
            }
            .frame(maxWidth: 300)
            
            Button(isRegistering ? "Register" : "Sign In") {
                Task {
                    if isRegistering {
                        await registerUser()
                    } else {
                        await signIn()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty || (isRegistering && displayName.isEmpty))
            
            Button(isRegistering ? "Already have an account? Sign In" : "Don't have an account? Register") {
                isRegistering.toggle()
            }
            .buttonStyle(.plain)
            .font(.footnote)
            
            // Dev mode option
            Toggle("Development Mode (Bypass Firebase Auth)", isOn: $useDevMode)
                .padding(.top, 20)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: 400, maxHeight: 600)
    }
    
    // Authentication functions
    private func checkForExistingUser() async {
        // Check dev mode first
        if useDevMode {
            if let devUser = DevAuthService.shared.getCurrentUser() {
                self.currentUser = devUser
                return
            }
        }
        
        // Then check Firebase
        do {
            if let user = try await userService.getCurrentUser() {
                self.currentUser = user
                await loadGroups()
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
            await loadGroups()
            
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
            
            // Reset fields
            email = ""
            password = ""
            displayName = ""
            
            // No groups yet for a new user
            groups = []
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
            groups = []
            expenses = []
            selectedGroup = nil
            return
        }
        
        do {
            try userService.signOut()
            self.currentUser = nil
            groups = []
            expenses = []
            selectedGroup = nil
        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
            print("Sign out error: \(error)")
        }
    }
}

struct ExpenseRow: View {
    let expense: Expense
    let group: Group
    @State private var creatorName: String = "Unknown"
    @State private var showingExpenseDetail = false
    @StateObject private var userService = UserService()
    
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading) {
                    Text(expense.description ?? "Expense")
                        .font(.headline)
                    
                    Text("Added by \(creatorName) • \(dateFormatter.string(from: expense.createdAt.dateValue()))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(currencyFormatter.string(from: NSNumber(value: expense.amount)) ?? "$0.00")
                    .font(.title3.bold())
            }
            
            Divider()
            
            HStack {
                Label("\(expense.splitType.rawValue.capitalized) split", systemImage: "person.3")
                    .font(.caption)
                    .padding(4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                
                Spacer()
                
                Button("Details") {
                    showingExpenseDetail = true
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
        .task {
            // Load creator name
            do {
                let creator = try await userService.getUser(uid: expense.createdBy)
                creatorName = creator.displayName ?? creator.email
            } catch {
                print("Error loading creator: \(error)")
            }
        }
        .sheet(isPresented: $showingExpenseDetail) {
            ExpenseDetailView(expense: expense, group: group)
                .frame(minWidth: 600, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
        }
    }
}

#Preview {
    ContentView()
}