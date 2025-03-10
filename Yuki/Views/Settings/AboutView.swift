// AboutView.swift
// About and information view

import SwiftUI

struct AboutView: View {
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // App Info
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        // App icon and name
                        HStack(spacing: 15) {
                            Image(nsImage: NSApp.applicationIconImage)
                                .resizable()
                                .frame(width: 64, height: 64)
                            
                            VStack(alignment: .leading) {
                                Text("Yuki")
                                    .font(.title)
                                Text("Version \(appVersion) (\(buildNumber))")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text("A lightweight tiling window manager for macOS")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                // Links
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Links")
                            .font(.headline)
                        
                        makeLink("GitHub Repository", url: "https://github.com/d-inama/yuki")
                        makeLink("Documentation", url: "https://github.com/d-inama/yuki/wiki")
                        makeLink("Report an Issue", url: "https://github.com/d-inama/yuki/issues")
                    }
                    .padding()
                }
                
                // Acknowledgments
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Acknowledgments")
                            .font(.headline)
                        
                        Text("Thanks to the open-source community and all contributors.")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func makeLink(_ title: String, url: String) -> some View {
        Button(action: {
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            }
        }) {
            HStack {
                Text(title)
                    .foregroundColor(.accentColor)
                Image(systemName: "arrow.up.right")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AboutView()
}
