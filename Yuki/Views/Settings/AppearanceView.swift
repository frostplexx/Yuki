// AppearanceView.swift
// Improved appearance settings with visual color selection

import AppKit
import SwiftUI

struct AppearanceView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @AppStorage("accentColorName") private var accentColorName: String = "blue"
    
    private let availableColors: [(name: String, color: Color)] = [
        ("blue", .blue),
        ("purple", .purple),
        ("pink", .pink),
        ("red", .red),
        ("orange", .orange),
        ("yellow", .yellow),
        ("green", .green)
    ]
    
    private let menuBarStyles = [
        "glass": "Glass",
        "solid": "Solid",
        "minimal": "Minimal"
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Accent Color
                VStack(alignment: .leading, spacing: 16) {
                    Text("Accent Color")
                        .font(.headline)
                    
                    // Color grid
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 60, maximum: 70), spacing: 16)
                    ], spacing: 16) {
                        ForEach(availableColors, id: \.name) { colorItem in
                            ColorButton(
                                color: colorItem.color,
                                name: colorItem.name,
                                isSelected: accentColorName == colorItem.name,
                                onSelect: {
                                    withAnimation {
                                        accentColorName = colorItem.name
                                        settings.update(\.accentColor, to: colorItem.name)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
                
                // Menu Bar Settings
                VStack(alignment: .leading, spacing: 16) {
                    Text("Menu Bar")
                        .font(.headline)
                    
                    ToggleRow(
                        title: "Show Menu Bar",
                        isOn: .init(
                            get: { settings.getSettings().showMenuBar },
                            set: { settings.update(\.showMenuBar, to: $0) }
                        ),
                        icon: "menubar.dock.rectangle",
                        description: "Show Yuki in the menu bar for quick access"
                    )
                    
                    if settings.getSettings().showMenuBar {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Menu Bar Style")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Picker("Style", selection: .init(
                                get: { settings.getSettings().menuBarStyle },
                                set: { settings.update(\.menuBarStyle, to: $0) }
                            )) {
                                ForEach(Array(menuBarStyles.keys), id: \.self) { key in
                                    Text(menuBarStyles[key] ?? key).tag(key)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            // Style preview
                            MenuBarStylePreview(style: settings.getSettings().menuBarStyle)
                        }
                        .padding(.leading, 32)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
                
                // Animations & Visual Feedback
                VStack(alignment: .leading, spacing: 16) {
                    Text("Visual Feedback")
                        .font(.headline)
                    
                    ToggleRow(
                        title: "Show Layout HUD",
                        isOn: .init(
                            get: { settings.getSettings().showLayoutHUD },
                            set: { settings.update(\.showLayoutHUD, to: $0) }
                        ),
                        icon: "rectangle.on.rectangle",
                        description: "Display a notification when changing layouts"
                    )
                    
                    ToggleRow(
                        title: "Animation Effects",
                        isOn: .init(
                            get: { true },  // Placeholder - implement in settings if needed
                            set: { _ in }
                        ),
                        icon: "sparkles",
                        description: "Enable smooth animations during window operations"
                    )
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Component Views

/// Color selection button with visual feedback
struct ColorButton: View {
    var color: Color
    var name: String
    var isSelected: Bool
    var onSelect: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                ZStack {
                    // Color circle
                    Circle()
                        .fill(color)
                        .frame(width: 45, height: 45)
                    
                    // Selection indicator
                    if isSelected {
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 45, height: 45)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .shadow(color: color.opacity(isHovering ? 0.6 : 0.3), radius: isHovering ? 6 : 3)
                
                // Color name
                Text(name.capitalized)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isHovering ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

/// Toggle row with icon and description
struct ToggleRow: View {
    var title: String
    @Binding var isOn: Bool
    var icon: String
    var description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.accentColor)
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

/// Menu bar style preview
struct MenuBarStylePreview: View {
    var style: String
    
    var body: some View {
        ZStack {
            // Background based on style
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    style == "glass" ? Color.white.opacity(0.2) :
                    style == "solid" ? Color.black.opacity(0.8) :
                    Color.black.opacity(0.5)
                )
                .frame(height: 36)
            
            // Content
            HStack {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 12))
                
                Text("Workspace")
                    .font(.system(size: 12))
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 8)
            .foregroundColor(.white)
        }
        .frame(width: 150, height: 36)
        .padding(.top, 8)
    }
}

#Preview {
    AppearanceView()
}
