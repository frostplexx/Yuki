// WindowRulesView.swift
// Window rules configuration

import SwiftUI

struct WindowRulesView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var newFloatingApp = ""
    @State private var newFloatingTitle = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Floating Apps
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Floating Apps")
                            .font(.headline)
                        
                        Text("Apps that will always float on top")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Input for new app
                        HStack {
                            TextField("App Bundle ID", text: $newFloatingApp)
                            Button("Add") {
                                if !newFloatingApp.isEmpty {
                                    var apps = settings.settings.floatingApps
                                    apps.insert(newFloatingApp)
                                    settings.update(\.floatingApps, to: apps)
                                    newFloatingApp = ""
                                }
                            }
                            .disabled(newFloatingApp.isEmpty)
                        }
                        
                        // List of floating apps
                        ForEach(Array(settings.settings.floatingApps), id: \.self) { app in
                            HStack {
                                Text(app)
                                Spacer()
                                Button(role: .destructive) {
                                    var apps = settings.settings.floatingApps
                                    apps.remove(app)
                                    settings.update(\.floatingApps, to: apps)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                }
                
                // Floating Window Titles
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Floating Window Titles")
                            .font(.headline)
                        
                        Text("Windows with these titles will always float")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Input for new window title
                        HStack {
                            TextField("Window Title", text: $newFloatingTitle)
                            Button("Add") {
                                if !newFloatingTitle.isEmpty {
                                    var titles = settings.settings.floatingWindowTitles
                                    titles.insert(newFloatingTitle)
                                    settings.update(\.floatingWindowTitles, to: titles)
                                    newFloatingTitle = ""
                                }
                            }
                            .disabled(newFloatingTitle.isEmpty)
                        }
                        
                        // List of floating window titles
                        ForEach(Array(settings.settings.floatingWindowTitles), id: \.self) { title in
                            HStack {
                                Text(title)
                                Spacer()
                                Button(role: .destructive) {
                                    var titles = settings.settings.floatingWindowTitles
                                    titles.remove(title)
                                    settings.update(\.floatingWindowTitles, to: titles)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    WindowRulesView()
}
