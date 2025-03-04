//
//  AccessibilityPermissionVew.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import Foundation
import SwiftUI

struct AccessibilityPermissionView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Accessibility Permission Required")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Yuki needs Accessibility permissions to monitor window information. Here's how to enable it:")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("1. Click 'Open System Settings' below")
                Text("2. Go to Privacy & Security → Accessibility")
                Text("3. Find and enable Yuki in the list")
                Text("4. Return to Yuki after granting permissions")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            Button("Open System Settings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .frame(width: 500)
    }
}
