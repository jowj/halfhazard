//
//  PlatformExtensions.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2025-03-27.
//

import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

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

// MARK: - File Import/Export Utilities

/// A utility class for handling file import and export operations
class FileExportManager {
    /// Shares a string as a CSV file with the provided name
    /// - Parameters:
    ///   - content: The string content to share
    ///   - fileName: The name of the file (without extension)
    /// - Returns: A boolean indicating if the file was successfully shared
    @MainActor
    static func shareCSV(_ content: String, fileName: String) -> Bool {
        // Create a temporary file
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let fileURL = tempDirectoryURL.appendingPathComponent("\(fileName).csv")
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            
            #if os(macOS)
            // On macOS, we'll present a save dialog
            let savePanel = NSSavePanel()
            savePanel.canCreateDirectories = true
            savePanel.showsTagField = false
            savePanel.title = "Save CSV File"
            savePanel.nameFieldStringValue = "\(fileName).csv"
            
            // Set allowed file types
            if #available(macOS 11.0, *) {
                savePanel.allowedContentTypes = [UTType.commaSeparatedText]
            } else {
                savePanel.allowedFileTypes = ["csv"]
            }
            
            if savePanel.runModal() == .OK, let targetURL = savePanel.url {
                // Copy the temporary file to the selected location
                try FileManager.default.copyItem(at: fileURL, to: targetURL)
                // Open the file in the default app
                NSWorkspace.shared.open(targetURL)
                return true
            }
            #elseif os(iOS)
            // On iOS, we'll use a share sheet
            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            
            // Present the share sheet
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                return false
            }
            
            // Handle iPad presentation
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, 
                                          y: rootViewController.view.bounds.midY, 
                                          width: 0, 
                                          height: 0)
            }
            
            rootViewController.present(activityVC, animated: true)
            return true
            #endif
        } catch {
            print("Error sharing CSV: \(error)")
        }
        
        return false
    }
    
    /// Opens a file picker to select a CSV file and returns its contents if successful
    /// - Returns: A tuple containing the CSV contents as a string and the selected file's name, or nil if operation was cancelled
    @MainActor
    static func importCSV() async -> (content: String, fileName: String)? {
        #if os(macOS)
        // On macOS, use an open panel
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.title = "Import CSV File"
        
        // Set allowed file types
        if #available(macOS 11.0, *) {
            openPanel.allowedContentTypes = [UTType.commaSeparatedText]
        } else {
            openPanel.allowedFileTypes = ["csv"]
        }
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let fileName = url.lastPathComponent
                return (content, fileName)
            } catch {
                print("Error reading CSV file: \(error)")
                return nil
            }
        }
        #elseif os(iOS)
        // On iOS, use UIDocumentPickerViewController
        // This is more complex and requires a continuation to handle the asynchronous callback
        return await withCheckedContinuation { continuation in
            let docPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.commaSeparatedText])
            docPicker.allowsMultipleSelection = false
            
            // Set up completion handler
            docPicker.completionHandler = { urls in
                guard let url = urls.first else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Attempt to read the file
                do {
                    // Start accessing the security-scoped resource
                    guard url.startAccessingSecurityScopedResource() else {
                        print("Failed to access security scoped resource")
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    defer { url.stopAccessingSecurityScopedResource() }
                    
                    let content = try String(contentsOf: url, encoding: .utf8)
                    let fileName = url.lastPathComponent
                    continuation.resume(returning: (content, fileName))
                } catch {
                    print("Error reading CSV file: \(error)")
                    continuation.resume(returning: nil)
                }
            }
            
            // Present the document picker
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                continuation.resume(returning: nil)
                return
            }
            
            rootViewController.present(docPicker, animated: true)
        }
        #endif
        
        return nil
    }
}

#if os(macOS)
// Add UTType for CSV files for macOS
extension UTType {
    static var commaSeparatedText: UTType {
        if #available(macOS 11.0, *) {
            return UTType("public.comma-separated-values-text")!
        } else {
            // Fallback for older macOS versions
            return UTType("public.text")!
        }
    }
}
#endif