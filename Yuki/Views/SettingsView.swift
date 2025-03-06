//
//  SettingsView.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import SwiftUI

struct SettingsView: View {
    @State private var showingPermissionView = false
    
    var body: some View {
        if showingPermissionView {
            AccessibilityPermissionView()
        } else {
            // Your actual settings view
            VStack {
                // Your settings content
                
                Button("Test Accessibility") {
                    if !AXIsProcessTrusted() {
                        showingPermissionView = true
                    } else {
                        print("Accessibility permissions granted!")
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                    showingPermissionView = !AXIsProcessTrusted()
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
