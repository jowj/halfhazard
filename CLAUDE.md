# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Halfhazard is a cross-platform SwiftUI application (iOS 18.2+ and macOS 15.1+) for tracking shared expenses between users. It's a personal app distributed via TestFlight, using Firebase for authentication and data storage.

## Build Commands

- **Build project**: Open `halfhazard.xcodeproj` in Xcode and build normally
- **Run tests**: `./run_tests.sh` (runs all test suites)
  - Individual test suites: `./run_tests.sh models`, `./run_tests.sh services`, `./run_tests.sh mocks`, `./run_tests.sh firebase`
- **Target schemes**: 
  - `halfhazard` (macOS)it
  - `halfhazard_ios` (iOS)

## Architecture

**Pattern**: MVVM with service layer
- **Models/**: Core data models (Expense, Group, Users, SplitType)
- **Services/**: Business logic and Firebase integration
- **ViewModels/**: State management for views
- **Views/**: SwiftUI interface components

**Key Services**:
- `ExpenseService`: Expense CRUD operations
- `GroupService`: Group management and membership
- `UserService`: Authentication and user management
- `DevAuthService`: Development mode bypass

## Development Features

**Dev Mode**: The app includes a development authentication service that bypasses Firebase auth for local testing. Toggle via `DevAuthService.isDevMode`.

**Platform Differences**: 
- Shared models and business logic
- Platform-specific UI adaptations in `ContentView.swift` vs `iOSContentView.swift`
- macOS uses hidden title bar, iOS uses standard navigation

## Firebase Configuration

- Uses Firebase v11.7.0 (Auth + Firestore)
- Security rules in `firestore.rules` (production) and `firestore.rules.dev`
- Database indexes defined in `firestore.indexes.json`
- Platform-specific `GoogleService-Info.plist` files required

## Testing Strategy

Comprehensive test coverage with mock services:
- **ModelsTests**: Data model validation
- **ServiceBehaviorTests**: Business logic using dev mode
- **MockServices**: Firebase-independent service testing
- Mock implementations follow protocols for clean testing

The test runner script provides organized execution with color-coded output and proper cleanup between test suites.
