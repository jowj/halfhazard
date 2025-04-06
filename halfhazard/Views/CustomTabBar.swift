//
//  CustomTabBar.swift
//  halfhazard
//
//  Created by Claude on 2025-04-03.
//

import SwiftUI

/// Custom tab bar component that works with NavigationStack
struct CustomTabBar: View {
    @Binding var selection: AppNavigation.TabSelection
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 0) {
                tabButton(title: "Groups", systemImage: "folder", tab: .groups)
                tabButton(title: "Expenses", systemImage: "creditcard", tab: .expenses)
                tabButton(title: "Profile", systemImage: "person.circle", tab: .profile)
            }
            .padding(.vertical, 8)
            .background(Material.bar)
        }
    }
    
    private func tabButton(title: String, systemImage: String, tab: AppNavigation.TabSelection) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selection = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 22))
                    .foregroundColor(selection == tab ? .accentColor : .gray)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(selection == tab ? .accentColor : .gray)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

/// A wrapper view that provides the tabs content with the custom tab bar
struct CustomTabView<Content: View>: View {
    @Binding var selection: AppNavigation.TabSelection
    let content: (AppNavigation.TabSelection) -> Content
    
    var body: some View {
        VStack(spacing: 0) {
            // Content for the selected tab
            content(selection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom tab bar at the bottom
            CustomTabBar(selection: $selection)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// Preview provider
#Preview {
    struct PreviewWrapper: View {
        @State private var selection: AppNavigation.TabSelection = .groups
        
        var body: some View {
            CustomTabView(selection: $selection) { tab in
                switch tab {
                case .groups:
                    Text("Groups Tab")
                case .expenses:
                    Text("Expenses Tab")
                case .profile:
                    Text("Profile Tab")
                }
            }
        }
    }
    
    return PreviewWrapper()
}