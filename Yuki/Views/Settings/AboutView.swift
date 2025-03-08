//
//  AboutView.swift
//  Yuki
//
//  Created by Daniel Inama on 7/3/25.
//

import SwiftUI

struct AboutView: View {
    // Get the app version from the bundle
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "Version \(version) (\(build))"
    }
    
    // Get the current year for the copyright notice
    private var currentYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: Date())
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // App Icon
            Image("AppIcon")
            .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128, height: 128)
                    .cornerRadius(22)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            // App Name
            Text("Yuki")
                .font(.system(size: 28, weight: .bold))
                .padding(.top, 10)
            
            // Version
            Text(appVersion)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Description
            Text("A modern tiling window manager for macOS")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.top, 5)
                .padding(.horizontal, 20)
            
            // Divider
            Divider()
                .padding(.vertical, 10)
                .padding(.horizontal, 40)
            
            // Developer Info
            VStack(spacing: 8) {
                Text("Created by Frostplexx")
                    .font(.body)
                
//                Text("© \(currentYear) Daniel Inama. All rights reserved.")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
            }
            
            // Links
            HStack(spacing: 25) {
                // GitHub
                Link(destination: URL(string: "https://github.com/frostplexx/Yuki")!) {
                    VStack {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 20))
                        Text("GitHub")
                            .font(.caption)
                    }
                }
                
                // Website
                Link(destination: URL(string: "https://yukimac.app")!) {
                    VStack {
                        Image(systemName: "globe")
                            .font(.system(size: 20))
                        Text("Website")
                            .font(.caption)
                    }
                }
                
                // Report Issue
                Link(destination: URL(string: "https://github.com/danielinama/yuki/issues")!) {
                    VStack {
                        Image(systemName: "exclamationmark.bubble")
                            .font(.system(size: 20))
                        Text("Report Issue")
                            .font(.caption)
                    }
                }
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 500)
    }
}

#Preview {
    AboutView()
}
