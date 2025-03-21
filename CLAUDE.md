# CLAUDE.md: Guidelines for Agentic Coding in Halfhazard

## Build/Run Commands
- Build: Open project in Xcode and use ⌘+B
- Run: Use ⌘+R in Xcode to build and run the app
- Test: Use ⌘+U to run all tests
- Single Test: In Xcode, click on test diamond to run individual test

## Code Style Guidelines
- **Imports**: Group by Foundation first, then SwiftUI, then Firebase imports
- **Formatting**: 4-space indentation, braces on same line as declarations
- **Types**: Use structs for models, classes for services
- **Models**: Implement Codable for Firebase serialization
- **Naming**: PascalCase for types, camelCase for properties/methods
- **Error Handling**: Use async/await with try/catch, propagate errors with throws
- **Documentation**: Comment complex functions, maintain models.md for data structure docs
- **File Organization**: Keep models in Models/, services in Services/
- **Firebase**: Follow Firebase best practices for authentication and Firestore interactions

This project is a Firebase-backed SwiftUI application for expense splitting.