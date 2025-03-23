# Halfhazard Test Suite

This directory contains comprehensive tests for the Halfhazard application.

## Test Organization

The test suite is organized into the following categories:

### Model Tests
- `ModelsTests.swift`: Tests the basic data models (User, Group, Expense, SplitType, Settings)

### Service Behavior Tests  
- `ServiceBehaviorTests.swift`: Tests the business logic of services using dev mode

### Mock Service Tests
- `MockServicesTests.swift`: Verifies that our mock service implementations work correctly

### Mock Firebase Tests
- `MockFirebaseTests.swift`: Tests the protocol-based Firebase mock implementation

### Mock Implementations
- `MockFirebase.swift`: Protocol-based mock implementations of Firebase services
- `MockServices.swift`: Mock implementations of application services

## Running the Tests

To run the tests:

1. Open the project in Xcode
2. Select the target device (Mac)
3. From the Product menu, select Test (or press ⌘U)

### Using the Test Runner Script

For convenience, you can use the provided test runner script:

```bash
# Run all tests
./run_tests.sh

# Run specific test suites
./run_tests.sh models    # Run model tests only
./run_tests.sh services  # Run service behavior tests only
./run_tests.sh mocks     # Run mock service tests only
./run_tests.sh firebase  # Run mock Firebase tests only

# Show help information
./run_tests.sh --help
```

### Running Tests with xcodebuild

You can also run specific test classes directly with xcodebuild:

```bash
# Run model tests only
xcodebuild test -scheme halfhazard -destination "platform=macOS" -only-testing halfhazardTests/ModelsTests

# Run service behavior tests only
xcodebuild test -scheme halfhazard -destination "platform=macOS" -only-testing halfhazardTests/ServiceBehaviorTests

# Run mock services tests only
xcodebuild test -scheme halfhazard -destination "platform=macOS" -only-testing halfhazardTests/MockServicesTests

# Run mock Firebase tests only
xcodebuild test -scheme halfhazard -destination "platform=macOS" -only-testing halfhazardTests/MockFirebaseTests
```

## Test Categories

### Model Tests
Model tests verify that the basic data models work correctly:
- Creating model instances with various data
- Handling nullable properties (nil vs non-nil)
- Equality and hash functions
- Edge cases (e.g., zero amounts, empty lists)

### Service Behavior Tests
Service behavior tests verify the business logic of services:
- Group management (creating, joining, leaving)
- Expense management (creating, updating, deleting)
- View model state management
- User authentication
- Form validation and error handling
- Split expense calculations
- Permission checks

These tests use the application's dev mode to avoid Firebase dependencies.

### Mock Service Tests
These tests verify that our mock service implementations work correctly:
- Mock UserService (authentication, user management)
- Mock GroupService (group operations)
- Mock ExpenseService (expense operations)
- Error handling in mock services

### Mock Firebase Tests
These tests verify our protocol-based Firebase mock implementation:
- Firestore operations (get, set, update, delete)
- Query operations (filtering, ordering)
- Auth operations
- Error handling
- Codable integration

## Testing Strategy

The testing strategy for Halfhazard follows these principles:

1. **Test Models First**: Ensure that the core data models are correctly implemented and work as expected.

2. **Test Business Logic**: Verify that the application services implement the correct business rules and maintain data integrity.

3. **Use Dev Mode**: Leverage the application's dev mode to test services without Firebase dependencies.

4. **Mock Firebase Services**: Use protocol-based mocks to simulate Firebase behavior for more comprehensive testing.

5. **Test Edge Cases**: Ensure the application handles edge cases and invalid inputs properly.

6. **Test Error Scenarios**: Verify that error handling works correctly throughout the application.

7. **Test User Permissions**: Ensure that permission checks are working correctly (e.g., only group creators can delete groups).

## Future Test Improvements

Additional tests that could be implemented:

1. **View Tests**: Add tests for SwiftUI views to verify UI rendering and user interactions.

2. **Integration Tests**: Add tests that verify multiple services working together.

3. **Firebase Emulator Tests**: Configure tests to use Firebase emulator for even more realistic testing.

4. **UI Tests**: Add UI tests for end-to-end testing of the application.

5. **Performance Tests**: Add tests to measure and ensure app performance.

6. **Concurrency Tests**: Test how the application handles concurrent operations.

7. **Network Resilience Tests**: Test how the application handles network errors and offline mode.