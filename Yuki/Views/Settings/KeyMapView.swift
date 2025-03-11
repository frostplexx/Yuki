// KeyMapView.swift
// Improved keyboard shortcuts configuration

import Carbon
import SwiftUI

struct KeyMapView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var isRecording = false
    @State private var selectedAction: String? = nil
    @State private var recordedKeys = ""
    @State private var showSuccess = false
    @State private var searchText = ""

    // Default shortcuts reference
    private let defaultShortcuts = [
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
        "next-workspace": "ctrl+right",
        "prev-workspace": "ctrl+left",
        "workspace-1": "ctrl+1",
        "workspace-2": "ctrl+2",
        "workspace-3": "ctrl+3",
        "workspace-4": "ctrl+4",
        "workspace-5": "ctrl+5",
    ]

    // Action descriptions for readability
    private let actionDescriptions = [
        "cycle-layout": "Cycle between layout types",
        "focus-left": "Focus window to the left",
        "focus-right": "Focus window to the right",
        "focus-up": "Focus window above",
        "focus-down": "Focus window below",
        "swap-left": "Swap with window to the left",
        "swap-right": "Swap with window to the right",
        "swap-up": "Swap with window above",
        "swap-down": "Swap with window below",
        "toggle-float": "Toggle float state of focused window",
        "equalize": "Make all windows equal size",
        "next-workspace": "Switch to next workspace",
        "prev-workspace": "Switch to previous workspace",
        "workspace-1": "Switch to workspace 1",
        "workspace-2": "Switch to workspace 2",
        "workspace-3": "Switch to workspace 3",
        "workspace-4": "Switch to workspace 4",
        "workspace-5": "Switch to workspace 5",
    ]

    // Categorize actions
    private var categories: [(String, [String])] {
        let windowActions = [
            "focus-left", "focus-right", "focus-up", "focus-down",
            "swap-left", "swap-right", "swap-up", "swap-down",
            "toggle-float", "equalize",
        ]

        let layoutActions = ["cycle-layout"]

        let workspaceActions = [
            "next-workspace", "prev-workspace",
            "workspace-1", "workspace-2", "workspace-3",
            "workspace-4", "workspace-5",
        ]

        return [
            ("Window Actions", windowActions),
            ("Layout Actions", layoutActions),
            ("Workspace Actions", workspaceActions),
        ]
    }

    // Filtered shortcut names
    private var filteredShortcuts: [String] {
        if searchText.isEmpty {
            return defaultShortcuts.keys.sorted()
        } else {
            return defaultShortcuts.keys.filter { key in
                let displayName = key.replacingOccurrences(of: "-", with: " ")
                    .capitalized
                let description = actionDescriptions[key] ?? ""
                return displayName.lowercased().contains(
                    searchText.lowercased())
                    || description.lowercased().contains(
                        searchText.lowercased())
            }.sorted()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search shortcuts", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .padding()
            .padding(.bottom, -8)

            // Instructions
            if isRecording {
                recordingInstructionsView
            } else {
                instructionsView
            }

            // List of shortcuts
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(categories, id: \.0) { category, actions in
                        // Only show category if it has visible actions
                        if !actions.filter({ filteredShortcuts.contains($0) })
                            .isEmpty
                        {
                            // Category header
                            HStack {
                                Text(category)
                                    .font(.headline)
                                    .foregroundColor(.secondary)

                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 16)
                            .padding(.bottom, 8)

                            // Shortcut rows
                            ForEach(
                                actions.filter {
                                    filteredShortcuts.contains($0)
                                }, id: \.self
                            ) { action in
                                ShortcutRow(
                                    action: action,
                                    description: actionDescriptions[action]
                                        ?? "",
                                    defaultKey: defaultShortcuts[action] ?? "",
                                    isRecording: isRecording
                                        && selectedAction == action,
                                    currentShortcut: settings.getSettings()
                                        .shortcuts[action] ?? defaultShortcuts[
                                            action] ?? "",
                                    onSelect: {
                                        if isRecording
                                            && selectedAction == action
                                        {
                                            // Cancel recording for this shortcut
                                            isRecording = false
                                            selectedAction = nil
                                        } else {
                                            // Start recording for this shortcut
                                            recordedKeys = ""
                                            isRecording = true
                                            selectedAction = action
                                        }
                                    },
                                    onReset: {
                                        resetShortcut(action)
                                    }
                                )
                                .transition(.opacity)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }

            // Reset all button
            HStack {
                Spacer()

                Button("Reset All to Defaults") {
                    resetAllShortcuts()
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .onAppear {
            // Set up the NSEvent monitor for key events when isRecording is true
            setupKeyEventMonitor()
        }
        .overlay(
            ZStack {
                if showSuccess {
                    Text("Shortcut saved!")
                        .padding()
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                        .shadow(radius: 3)
                        .transition(.scale.combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(
                                deadline: .now() + 1.5
                            ) {
                                withAnimation {
                                    showSuccess = false
                                }
                            }
                        }
                }
            }
        )
    }

    // Recording instructions
    private var recordingInstructionsView: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Text("Recording Shortcut")
                    .font(.headline)
                    .foregroundColor(.accentColor)

                HStack {
                    Text("Press the keys you want to use for:")
                        .foregroundColor(.secondary)

                    if let action = selectedAction {
                        Text(
                            action.replacingOccurrences(of: "-", with: " ")
                                .capitalized
                        )
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                    }
                }

                Text("Press Esc to cancel")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !recordedKeys.isEmpty {
                    HStack {
                        Text("Current input:")
                            .foregroundColor(.secondary)

                        Text(recordedKeys)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 6)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .transition(.opacity)
    }

    // General instructions
    private var instructionsView: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "keyboard")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 22))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Keyboard Shortcuts")
                        .font(.headline)

                    Text(
                        "Click on any shortcut to change it. Press the desired keys when prompted. Shortcuts will be applied immediately."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .transition(.opacity)
    }

    // MARK: - Key Event Handling

    private func setupKeyEventMonitor() {
        // Set up a local monitor to detect key events
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if self.isRecording {
                self.handleKeyEvent(event)
                // Consume the event by returning nil
                return nil
            }
            // Pass through events when not recording
            return event
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        // Handle Escape key to cancel recording
        if event.keyCode == kVK_Escape {
            withAnimation {
                isRecording = false
                selectedAction = nil
                recordedKeys = ""
            }
            return
        }

        // Create shortcut string from key event
        let shortcut = keyEventToString(event)

        // Check if we have a valid shortcut and action
        if !shortcut.isEmpty, let action = selectedAction {
            recordedKeys = shortcut

            // Apply the new shortcut
            var shortcuts = settings.getSettings().shortcuts
            shortcuts[action] = shortcut
            settings.update(\.shortcuts, to: shortcuts)

            // Show success message
            withAnimation {
                showSuccess = true
                isRecording = false
                self.selectedAction = nil
            }
        }
    }

    private func keyEventToString(_ event: NSEvent) -> String {
        var components: [String] = []

        // Add modifiers
        if event.modifierFlags.contains(.command) { components.append("cmd") }
        if event.modifierFlags.contains(.shift) { components.append("shift") }
        if event.modifierFlags.contains(.option) { components.append("opt") }
        if event.modifierFlags.contains(.control) { components.append("ctrl") }

        // Translate special keys
        let keyChar: String

        switch Int(event.keyCode) {
        case kVK_Return:
            keyChar = "return"
        case kVK_Tab:
            keyChar = "tab"
        case kVK_Space:
            keyChar = "space"
        case kVK_Delete:
            keyChar = "delete"
        case kVK_Escape:
            keyChar = "escape"
        case kVK_LeftArrow:
            keyChar = "left"
        case kVK_RightArrow:
            keyChar = "right"
        case kVK_UpArrow:
            keyChar = "up"
        case kVK_DownArrow:
            keyChar = "down"
        case kVK_F1:
            keyChar = "f1"
        case kVK_F2:
            keyChar = "f2"
        case kVK_F3:
            keyChar = "f3"
        case kVK_F4:
            keyChar = "f4"
        case kVK_F5:
            keyChar = "f5"
        case kVK_F6:
            keyChar = "f6"
        case kVK_F7:
            keyChar = "f7"
        case kVK_F8:
            keyChar = "f8"
        case kVK_F9:
            keyChar = "f9"
        case kVK_F10:
            keyChar = "f10"
        case kVK_F11:
            keyChar = "f11"
        case kVK_F12:
            keyChar = "f12"
        default:
            // Regular character
            keyChar = event.charactersIgnoringModifiers?.lowercased() ?? ""
        }

        if !keyChar.isEmpty {
            components.append(keyChar)
        }

        return components.joined(separator: "+")
    }

    // MARK: - Shortcut Management

    private func resetShortcut(_ action: String) {
        if let defaultShortcut = defaultShortcuts[action] {
            var shortcuts = settings.getSettings().shortcuts
            shortcuts[action] = defaultShortcut
            settings.update(\.shortcuts, to: shortcuts)
        } else {
            var shortcuts = settings.getSettings().shortcuts
            shortcuts.removeValue(forKey: action)
            settings.update(\.shortcuts, to: shortcuts)
        }
    }

    private func resetAllShortcuts() {
        settings.update(\.shortcuts, to: defaultShortcuts)
    }
}

// MARK: - Component Views

struct ShortcutRow: View {
    var action: String
    var description: String
    var defaultKey: String
    var isRecording: Bool
    var currentShortcut: String
    var onSelect: () -> Void
    var onReset: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    action.replacingOccurrences(of: "-", with: " ").capitalized
                )
                .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 180, alignment: .leading)

            Spacer()

            Button(action: onSelect) {
                if isRecording {
                    Text("Press keys...")
                        .foregroundColor(.secondary)
                        .italic()
                        .frame(width: 130, alignment: .center)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(6)
                } else {
                    Text(currentShortcut)
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .frame(width: 130, alignment: .center)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            .buttonStyle(.plain)

            // Reset button - show if current shortcut differs from default
            if currentShortcut != defaultKey {
                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reset to default")
            } else {
                // Placeholder to keep spacing consistent
                Image(systemName: "arrow.counterclockwise")
                    .foregroundColor(.clear)
                    .frame(width: 16)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isRecording
                        ? Color.accentColor.opacity(0.1)
                        : (isHovering
                            ? Color.secondary.opacity(0.05) : Color.clear))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

#Preview {
    KeyMapView()
}
