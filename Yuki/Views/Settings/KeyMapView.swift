// KeyMapView.swift
// Keyboard shortcuts configuration

import SwiftUI

// Your imports remain the same
private enum DefaultShortcuts {
    static let shortcuts = [
        "cycle-layout": "cmd+space",
        "focus-left": "cmd+h",
        "focus-right": "cmd+l",
        "focus-up": "cmd+k",
        "focus-down": "cmd+j",
        "swap-left": "cmd+shift+h",
        "swap-right": "cmd+shift+l",
        "swap-up": "cmd+shift+k",
        "swap-down": "cmd+shift+j",
        "toggle-float": "cmd+t",
        "equalize": "cmd+0",
    ]
}

struct KeyMapView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var isRecording = false
    @State private var selectedAction: String? = nil

    // Your defaultShortcuts remain the same

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Keyboard shortcuts section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Keyboard Shortcuts")
                            .font(.headline)

                        Text("Click a shortcut to change it")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        // List of shortcuts
                        ForEach(
                            DefaultShortcuts.shortcuts.sorted(by: {
                                $0.key < $1.key
                            }), id: \.key
                        ) { action, defaultKey in
                            ShortcutRow(
                                action: action,
                                defaultKey: defaultKey,
                                isRecording: isRecording,
                                selectedAction: selectedAction,
                                settings: settings,
                                onSelect: {
                                    selectedAction = action
                                    isRecording = true
                                }
                            )
                        }
                    }
                    .padding()
                }

                // Instructions GroupBox
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Instructions")
                            .font(.headline)

                        Text("• Click any shortcut to change it")
                        Text("• Press Esc to cancel recording")
                        Text("• Click the reset button to restore default")
                    }
                    .padding()
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Add key recording functionality
        //            .onReceive(NotificationCenter.default.publisher(for: NSEvent.keyUpNotification)) { notification in
        //                guard isRecording,
        //                      let selectedAction = selectedAction,
        //                      let event = notification.object as? NSEvent else { return }
        //
        //                // Handle Escape key
        //                if event.keyCode == 53 {
        //                    isRecording = false
        //                    self.selectedAction = nil
        //                    return
        //                }
        //
        //                // Apply new shortcut
        //                let shortcut = keyEventToString(event)
        //                var shortcuts = settings.settings.shortcuts
        //                shortcuts[selectedAction] = shortcut
        //                settings.update(\.shortcuts, to: shortcuts)
        //
        //                // Reset recording state
        //                isRecording = false
        //                self.selectedAction = nil
        //            }
    }

    private func keyEventToString(_ event: NSEvent) -> String {
        var components: [String] = []

        if event.modifierFlags.contains(.command) { components.append("cmd") }
        if event.modifierFlags.contains(.shift) { components.append("shift") }
        if event.modifierFlags.contains(.option) { components.append("opt") }
        if event.modifierFlags.contains(.control) { components.append("ctrl") }

        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        components.append(key)

        return components.joined(separator: "+")
    }
}

// Break out the shortcut row into a separate view
struct ShortcutRow: View {
    let action: String
    let defaultKey: String
    let isRecording: Bool
    let selectedAction: String?
    let settings: SettingsManager
    let onSelect: () -> Void

    var body: some View {
        HStack {
            Text(action.replacingOccurrences(of: "-", with: " ").capitalized)
                .frame(width: 120, alignment: .leading)

            Spacer()

            Button(action: onSelect) {
                Text(settings.settings.shortcuts[action] ?? defaultKey)
                    .frame(width: 100)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        isRecording && selectedAction == action
                            ? Color.accentColor.opacity(0.2)
                            : Color.secondary.opacity(0.2)
                    )
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)

            // Reset button
            if settings.settings.shortcuts[action] != nil {
                Button(action: {
                    var shortcuts = settings.settings.shortcuts
                    shortcuts.removeValue(forKey: action)
                    settings.update(\.shortcuts, to: shortcuts)
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// Preview remains the same
#Preview {
    KeyMapView()
}
