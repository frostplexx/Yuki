// Your imports remain the same

import AppKit
import SwiftUI

struct AppearanceView: View {
    @ObservedObject private var settings = SettingsManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Menu Bar Settings
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Menu Bar")
                            .font(.headline)
                        
                        Toggle("Show Menu Bar", isOn: .init(
                            get: { settings.settings.showMenuBar },
                            set: { settings.update(\.showMenuBar, to: $0) }
                        ))
                        
                        // Only show style picker if menu bar is enabled
                        if settings.settings.showMenuBar {
                            Picker("Style", selection: .init(
                                get: { settings.settings.menuBarStyle },
                                set: { settings.update(\.menuBarStyle, to: $0) }
                            )) {
                                Text("Glass").tag("glass")
                                Text("Solid").tag("solid")
                                Text("Minimal").tag("minimal")
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding()
                }
                
                // Theme Settings
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Theme")
                            .font(.headline)
                        
                        Picker("Accent Color", selection: .init(
                            get: { settings.settings.accentColor },
                            set: { newColor in
                                settings.update(\.accentColor, to: newColor)
                                applyAccentColor(newColor)
                            }
                        )) {
                            Text("Blue").tag("blue")
                            Text("Purple").tag("purple")
                            Text("Pink").tag("pink")
                            Text("Red").tag("red")
                            Text("Orange").tag("orange")
                            Text("Yellow").tag("yellow")
                            Text("Green").tag("green")
                        }
                    }
                    .padding()
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Apply current settings when view appears
            applyAccentColor(settings.settings.accentColor)
        }
    }
    
    private func applyAccentColor(_ colorName: String) {
        // Convert color name to NSColor and apply
        if let color = colorFromName(colorName) {
//            NSApplication.shared.appearance?.setAccentColor(color)
        }
    }
    
    private func colorFromName(_ name: String) -> NSColor? {
        switch name.lowercased() {
        case "blue": return .systemBlue
        case "purple": return .systemPurple
        case "pink": return .systemPink
        case "red": return .systemRed
        case "orange": return .systemOrange
        case "yellow": return .systemYellow
        case "green": return .systemGreen
        default: return nil
        }
    }
}

