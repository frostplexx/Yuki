// SettingsManager.swift
// Centralized settings management with JSON persistence

import Combine
import Defaults
import Foundation
import SwiftUI

class SettingsManager: ObservableObject {
    // MARK: - Singleton

    static let shared = SettingsManager()

    // MARK: - Properties

    /// Settings storage location
    private let configDirectory: URL
    private let configFile: URL

    /// Current settings
    @Published private(set) var settings: Settings

    // MARK: - Settings Structure

    // Update the Settings struct in SettingsManager.swift
    struct Settings: Codable {
        // Appearance
        var showMenuBar: Bool = true
        var menuBarStyle: String = "glass"
        var accentColor: String = "blue"

        // Layout
        var defaultLayout: String = "bsp"
        var gapSize: Int = 10
        var outerGap: Int = 10

        // Behavior
        var floatNewWindows: Bool = false
        var followWindowToSpace: Bool = true
        var showLayoutHUD: Bool = true

        // Window Rules
        var floatingApps: Set<String> = [
            "com.apple.systempreferences",
            "com.apple.finder.SaveDialog",
            "com.apple.PreferencePane",
            "com.apple.ColorSyncUtility",
        ]
        var floatingWindowTitles: Set<String> = [
            "Preferences", "Settings", "Properties",
        ]

        // Workspaces - now with default empty array
        var workspaces: [WorkspaceConfig] = []

        // Shortcuts
        var shortcuts: [String: String] = [
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

        // Add custom CodingKeys and proper decoder/encoder implementations
        enum CodingKeys: String, CodingKey {
            case showMenuBar, menuBarStyle, accentColor
            case defaultLayout, gapSize, outerGap
            case floatNewWindows, followWindowToSpace, showLayoutHUD
            case floatingApps, floatingWindowTitles
            case workspaces
            case shortcuts
        }

        init() {
            // Default initialization already handled by property defaults
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            // Decode with defaults if keys are missing
            showMenuBar =
                try container.decodeIfPresent(Bool.self, forKey: .showMenuBar)
                ?? true
            menuBarStyle =
                try container.decodeIfPresent(
                    String.self, forKey: .menuBarStyle) ?? "glass"
            accentColor =
                try container.decodeIfPresent(String.self, forKey: .accentColor)
                ?? "blue"

            defaultLayout =
                try container.decodeIfPresent(
                    String.self, forKey: .defaultLayout) ?? "bsp"
            gapSize =
                try container.decodeIfPresent(Int.self, forKey: .gapSize) ?? 10
            outerGap =
                try container.decodeIfPresent(Int.self, forKey: .outerGap) ?? 10

            floatNewWindows =
                try container.decodeIfPresent(
                    Bool.self, forKey: .floatNewWindows) ?? false
            followWindowToSpace =
                try container.decodeIfPresent(
                    Bool.self, forKey: .followWindowToSpace) ?? true
            showLayoutHUD =
                try container.decodeIfPresent(Bool.self, forKey: .showLayoutHUD)
                ?? true

            floatingApps =
                try container.decodeIfPresent(
                    Set<String>.self, forKey: .floatingApps) ?? [
                    "com.apple.systempreferences",
                    "com.apple.finder.SaveDialog",
                    "com.apple.PreferencePane",
                    "com.apple.ColorSyncUtility",
                ]

            floatingWindowTitles =
                try container.decodeIfPresent(
                    Set<String>.self, forKey: .floatingWindowTitles) ?? [
                    "Preferences", "Settings", "Properties",
                ]

            // New field - handle missing gracefully
            workspaces =
                try container.decodeIfPresent(
                    [WorkspaceConfig].self, forKey: .workspaces) ?? []

            shortcuts =
                try container.decodeIfPresent(
                    [String: String].self, forKey: .shortcuts) ?? [
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
    }
    // Workspace configuration in settings
    struct WorkspaceConfig: Codable, Identifiable, Equatable {
        let id: String
        var name: String
        var monitorID: Int
        var layoutType: String

        var uuid: UUID {
            return UUID(uuidString: id) ?? UUID()
        }
    }

    // MARK: - Initialization

    private init() {
        // Set up config directory in ~/.config/Yuki
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        self.configDirectory = homeDir.appendingPathComponent(".config/Yuki")
        self.configFile = configDirectory.appendingPathComponent(
            "settings.json")

        // Create directory if needed
        do {
            try FileManager.default.createDirectory(
                at: configDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            print("Failed to create config directory: \(error)")
        }

        // Start with default settings to be safe
        self.settings = Settings()

        // Try to load existing settings, but don't crash if it fails
        if let loaded = Self.loadSettings(from: configFile) {
            self.settings = loaded
            print("Loaded settings from \(configFile.path)")
        } else {
            print("Using default settings and saving them")
            saveSettings()
        }
    }

    // MARK: - Settings Access

    /// Get current settings
    func getSettings() -> Settings {
        return settings
    }

    /// Update settings
    func updateSettings(_ newSettings: Settings) {
        settings = newSettings
        saveSettings()
//        applyAllSettings()
    }

    /// Update a specific setting
    func update<T>(_ keyPath: WritableKeyPath<Settings, T>, to value: T) {
        settings[keyPath: keyPath] = value
        saveSettings()

        // Apply specific setting that changed
        switch keyPath {
        case \Settings.defaultLayout, \Settings.gapSize, \Settings.outerGap:
            applyLayoutSettings()
        case \Settings.showMenuBar, \Settings.menuBarStyle,
            \Settings.accentColor:
            applyAppearanceSettings()
        case \Settings.floatNewWindows, \Settings.followWindowToSpace,
            \Settings.showLayoutHUD:
            applyBehaviorSettings()
        case \Settings.floatingApps, \Settings.floatingWindowTitles:
            applyWindowRules()
        case \Settings.shortcuts:
            applyKeyboardShortcuts()
        case \Settings.workspaces:
            syncWorkspaces()
        default:
//            applyAllSettings()
                return
        }
    }

    // MARK: - Workspace Management

    /// Add a new workspace configuration
    func addWorkspace(name: String, monitorID: Int, layoutType: String)
        -> WorkspaceConfig
    {
        let newWorkspace = WorkspaceConfig(
            id: UUID().uuidString,
            name: name,
            monitorID: monitorID,
            layoutType: layoutType
        )

        var updatedWorkspaces = settings.workspaces
        updatedWorkspaces.append(newWorkspace)

        update(\.workspaces, to: updatedWorkspaces)
        syncWorkspaces()

        return newWorkspace
    }

    /// Update a workspace configuration
    func updateWorkspace(_ workspace: WorkspaceConfig) {
        var updatedWorkspaces = settings.workspaces
        if let index = updatedWorkspaces.firstIndex(where: {
            $0.id == workspace.id
        }) {
            updatedWorkspaces[index] = workspace
            update(\.workspaces, to: updatedWorkspaces)
        }
    }

    /// Remove a workspace configuration
    func removeWorkspace(withID id: String) {
        var updatedWorkspaces = settings.workspaces
        updatedWorkspaces.removeAll { $0.id == id }
        update(\.workspaces, to: updatedWorkspaces)
    }

    /// Get workspaces for a specific monitor
    func getWorkspaces(forMonitorID monitorID: Int) -> [WorkspaceConfig] {
        return settings.workspaces.filter { $0.monitorID == monitorID }
    }

    /// Sync workspaces from configuration to WindowManager
    func syncWorkspaces() {
        let windowManager = WindowManager.shared

        // First save any current workspaces that aren't in settings
        captureCurrentWorkspaces()

        // For each monitor, ensure it has the configured workspaces
        for monitor in windowManager.monitors {
            let configuredWorkspaces = getWorkspaces(forMonitorID: monitor.id)

            // Create missing workspaces from config
            for workspaceConfig in configuredWorkspaces {
                // Check if we already have this workspace
                let exists = monitor.workspaces.contains {
                    $0.id.uuidString == workspaceConfig.id
                }

                if !exists {
                    // Create the workspace
                    let newWorkspace = WorkspaceNode(
                        id: workspaceConfig.uuid,
                        title: workspaceConfig.name,
                        monitor: monitor
                    )

                    // Set layout type
                    newWorkspace.tilingEngine.setLayoutType(
                        named: workspaceConfig.layoutType)

                    // Add to monitor
                    monitor.workspaces.append(newWorkspace)
                }
            }

            // Ensure at least one workspace exists
            if monitor.workspaces.isEmpty {
                let defaultWorkspace = WorkspaceNode(
                    title: "Default",
                    monitor: monitor
                )
                monitor.workspaces.append(defaultWorkspace)
                monitor.activeWorkspace = defaultWorkspace

                // Add to settings
                addWorkspace(
                    name: "Default",
                    monitorID: monitor.id,
                    layoutType: settings.defaultLayout
                )
            }

            // Make sure we have an active workspace
            if monitor.activeWorkspace == nil {
                monitor.activeWorkspace = monitor.workspaces.first
            }

            // Apply layout settings to all workspaces
            for workspace in monitor.workspaces {
                // Find matching config if it exists
                if let config = configuredWorkspaces.first(where: {
                    $0.id == workspace.id.uuidString
                }) {
                    // Apply layout type
                    workspace.tilingEngine.setLayoutType(
                        named: config.layoutType)

                    // Update title if different
                    if workspace.title != config.name {
                        workspace.title = config.name
                    }
                } else {
                    // Default to settings layout
                    workspace.tilingEngine.setLayoutType(
                        named: settings.defaultLayout)
                }

                // Apply gap settings
                workspace.tilingEngine.config.windowGap = CGFloat(
                    settings.gapSize)
                workspace.tilingEngine.config.outerGap = CGFloat(
                    settings.outerGap)

                // Reapply tiling if active
                if workspace.isActive {
                    workspace.applyTiling()
                }
            }
        }
    }

    /// Save current workspaces to settings
    func captureCurrentWorkspaces() {
        var workspaceConfigs: [WorkspaceConfig] = []

        for monitor in WindowManager.shared.monitors {
            for workspace in monitor.workspaces {
                // Create configuration
                let config = WorkspaceConfig(
                    id: workspace.id.uuidString,
                    name: workspace.title ?? "Untitled",
                    monitorID: monitor.id,
                    layoutType: workspace.tilingEngine.currentLayoutType
                        .rawValue
                )

                workspaceConfigs.append(config)
            }
        }

        // Only update if different
        if workspaceConfigs != settings.workspaces {
            settings.workspaces = workspaceConfigs
            saveSettings()
        }
    }

    // MARK: - Persistence

    /// Save current settings to disk
    private func saveSettings() {
        do {
            // Encode settings to JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)

            // Write to file
            try data.write(to: configFile)
        } catch {
            print("Failed to save settings: \(error)")
        }
    }

    /// Load settings from disk
    private static func loadSettings(from url: URL) -> Settings? {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(Settings.self, from: data)
        } catch {
            print("Failed to load settings: \(error)")
            return nil
        }
    }

    /// Reset settings to defaults
    func resetToDefaults() {
        settings = Settings()
        saveSettings()
//        applyAllSettings()
    }
}

// MARK: - Settings Access Helpers

extension SettingsManager {
    /// Apply all settings
    func applyAllSettings() {
        applyLayoutSettings()
        applyAppearanceSettings()
        applyBehaviorSettings()
        applyWindowRules()
        applyKeyboardShortcuts()
        syncWorkspaces()
    }

    /// Apply layout settings
    func applyLayoutSettings() {
        // Apply to all workspaces with safety checks
        
        
        for monitor in WindowManager.shared.monitors {

            guard monitor.workspaces != nil else {
                print("Monitor has nil workspaces array, skipping")
                continue
            }

            for workspace in monitor.workspaces {
                // Check if workspace and engine are properly initialized
                guard workspace.tilingEngine != nil else {
                    print("Warning: Workspace has nil tiling engine")
                    continue
                }

                // Set initial layout type with extra safety
                do {
                    let layoutType = settings.defaultLayout
                    print(
                        "Setting layout type: \(layoutType) for workspace: \(workspace.title ?? "unknown")"
                    )
                    workspace.tilingEngine.setLayoutType(named: layoutType)
                } catch {
                    print("Error setting layout type: \(error)")
                }

                // Only apply other settings if previous step succeeded
                workspace.tilingEngine.config.windowGap = CGFloat(
                    settings.gapSize)
                workspace.tilingEngine.config.outerGap = CGFloat(
                    settings.outerGap)

                // Apply tiling only if workspace is active
                if workspace.isActive {
                    workspace.applyTiling()
                }
            }
        }
    }

    /// Apply appearance settings
    func applyAppearanceSettings() {
        // Update menu bar visibility
        if let menuBarController = NSApp.mainMenu?.items.first?.submenu?.items
            .first?.view?.window?.windowController
        {
            menuBarController.window?.setIsVisible(settings.showMenuBar)
        }

        // Apply accent color
        if let color = colorFromName(settings.accentColor) {
            // NSApplication.shared.appearance?.setAccentColor(color)
            // macOS doesn't allow programmatic accent color changes, but we can style our own UI
        }
    }

    /// Apply behavior settings
    func applyBehaviorSettings() {
        // These are handled in real-time by the window manager
        NotificationCenter.default.post(
            name: Notification.Name("com.yuki.SettingsChanged"),
            object: nil,
            userInfo: ["settings": settings]
        )
    }

    /// Apply window rules
    func applyWindowRules() {
        // Clear window cache to re-evaluate float decisions
        for monitor in WindowManager.shared.monitors {
            for workspace in monitor.workspaces {
                workspace.tilingEngine.clearFloatDecisionCache()
            }
        }

        // Refresh window manager to apply new rules
        WindowManager.shared.monitorWithMouse?.activeWorkspace?.applyTiling()
    }

    /// Apply keyboard shortcuts
    func applyKeyboardShortcuts() {
        // Post notification for shortcut manager to handle
        NotificationCenter.default.post(
            name: Notification.Name("com.yuki.ShortcutsChanged"),
            object: nil,
            userInfo: ["shortcuts": settings.shortcuts]
        )
    }

    /// Convert color name to NSColor
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
