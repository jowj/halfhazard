//
//  AppRoot.swift
//  halfhazard
//

import SwiftUI
import FirebaseAuth

/// The whole app's structure: check for a session, sign in if there isn't one, otherwise the
/// ledger.
///
/// One root for both platforms. There used to be two — `ContentView` and `iOSContentView`,
/// 824 and 588 lines — holding two navigation stacks, a sidebar, a tab bar, and a group
/// selection model between them. `ContentView` also carried ~165 lines of `#if os(iOS)` that
/// never compiled, because the pbxproj excluded the file from the iOS target, and attached
/// `.navigationDestination(for:)` to the `NavigationStack` itself rather than its content,
/// which put it outside the navigation hierarchy. Both problems are gone with the file.
struct AppRoot: View {
    @State private var userService = UserService()
    @State private var currentUser: User?
    @State private var isCheckingAuth = true

    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isRegistering = false
    @State private var useDevMode = false
    @State private var errorMessage: String?

    var body: some View {
        #if DEBUG
        if DemoLedgerSource.isRequested {
            // Launched with -demoLedger: the screen against fixtures, no sign-in.
            LedgerScreen(store: LedgerStore(
                source: DemoLedgerSource(),
                viewerId: DemoLedgerSource.viewerId
            ))
        } else {
            authenticated
        }
        #else
        authenticated
        #endif
    }

    @ViewBuilder
    private var authenticated: some View {
        if isCheckingAuth {
            SplashView()
                .task { await restoreSession() }
        } else if let currentUser {
            LedgerScreen(viewerId: currentUser.uid) {
                Task { await signOut() }
            }
            .id(currentUser.uid)
        } else {
            AuthView(
                email: $email,
                password: $password,
                displayName: $displayName,
                isRegistering: $isRegistering,
                useDevMode: $useDevMode,
                signInAction: signIn,
                registerAction: register
            )
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Session

    private func restoreSession() async {
        if useDevMode, let devUser = DevAuthService.shared.getCurrentUser() {
            currentUser = devUser
            isCheckingAuth = false
            return
        }

        currentUser = try? await userService.getCurrentUser()
        isCheckingAuth = false
    }

    private func signIn() async {
        if useDevMode {
            guard let devUser = DevAuthService.shared.signIn(email: email, password: password) else {
                errorMessage = "Dev mode needs an email containing @ and a password of at least 6 characters."
                return
            }
            finish(with: devUser)
            return
        }

        do {
            finish(with: try await userService.signIn(email: email, password: password))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func register() async {
        if useDevMode {
            guard let devUser = DevAuthService.shared.signIn(email: email, password: password) else {
                errorMessage = "Dev mode needs an email containing @ and a password of at least 6 characters."
                return
            }
            finish(with: devUser)
            return
        }

        do {
            finish(with: try await userService.createUser(
                email: email,
                password: password,
                displayName: displayName.isEmpty ? nil : displayName
            ))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func signOut() async {
        if useDevMode {
            DevAuthService.shared.signOut()
            currentUser = nil
            return
        }

        do {
            try userService.signOut()
            currentUser = nil
        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
        }
    }

    private func finish(with user: User) {
        currentUser = user
        email = ""
        password = ""
        displayName = ""
        errorMessage = nil
    }
}

#Preview {
    AppRoot()
}
