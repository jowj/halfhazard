//
//  TestView.swift
//  halfhazard
//
//  Created by Claude on 2025-03-21.
//

import SwiftUI

struct TestView: View {
    var body: some View {
        Text("Hello World")
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundColor(.blue)
        
        Text("This is a test view")
            .font(.title2)
            .foregroundColor(.secondary)
        
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 64))
            .foregroundColor(.green)
    }
}

#Preview {
    TestView()
}
