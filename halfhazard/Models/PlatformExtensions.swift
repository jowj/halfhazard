//
//  PlatformExtensions.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2025-03-27.
//

import SwiftUI

// Cross-platform extensions and adaptations

// Platform-specific view modifiers
extension View {
    /// Apply appropriate styling for the current platform
    func adaptForPlatform() -> some View {
        #if os(macOS)
        return self.adaptForMacOS()
        #elseif os(iOS)
        return self.adaptForIOS()
        #endif
    }
    
    #if os(macOS)
    /// Apply macOS-specific styling
    func adaptForMacOS() -> some View {
        return self
            // Add any macOS-specific modifiers here
    }
    #endif
    
    #if os(iOS)
    /// Apply iOS-specific styling
    func adaptForIOS() -> some View {
        return self
            // Make form fields larger on iOS for better touch targets
            .environment(\.horizontalSizeClass, .compact)
    }
    #endif
    
    /// Apply appropriate form styling for the current platform
    func formStyle() -> some View {
        #if os(macOS)
        return self
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(width: 400)
        #elseif os(iOS)
        return self
            .padding()
            // iOS forms take full width but have standard padding
        #endif
    }
}

// Platform-specific font extensions
extension Font {
    /// Returns the appropriate title font for the platform
    static var platformTitle: Font {
        #if os(macOS)
        return .title
        #else
        return .title.weight(.semibold)
        #endif
    }
    
    /// Returns the appropriate body font for the platform
    static var platformBody: Font {
        #if os(macOS)
        return .body
        #else
        return .body.weight(.regular)
        #endif
    }
}

// Helper for platform-specific UI elements
enum PlatformUI {
    /// Returns the appropriate corner radius for buttons and cards
    static var cornerRadius: CGFloat {
        #if os(macOS)
        return 6
        #else
        return 10
        #endif
    }
    
    /// Returns the appropriate padding for cards
    static var cardPadding: CGFloat {
        #if os(macOS)
        return 16
        #else
        return 20
        #endif
    }
    
    /// Returns the appropriate shadow radius for cards
    static var shadowRadius: CGFloat {
        #if os(macOS)
        return 2
        #else
        return 4
        #endif
    }
}

// Extension for platform-specific bindings
extension Binding {
    /// Provides a toggle binding that adds platform-specific haptic feedback
    func withHapticFeedback() -> Binding<Value> where Value == Bool {
        return Binding<Value>(
            get: { self.wrappedValue },
            set: { newValue in
                #if os(iOS)
                // Add haptic feedback on iOS
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                #endif
                self.wrappedValue = newValue
            }
        )
    }
}