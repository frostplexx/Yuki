// SettingsManager.swift
// Centralized settings management with JSON persistence

import Foundation
import Combine
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
        var floatingApps: Set<String> = []
        var floatingWindowTitles: Set<String> = []
        
        // Shortcuts - can be customized later
        var shortcuts: [String: String] = [:]
    }
    
    // MARK: - Initialization
    
    private init() {
        // Set up config directory in ~/.config/Yuki
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        self.configDirectory = homeDir.appendingPathComponent(".config/Yuki")
        self.configFile = configDirectory.appendingPathComponent("settings.json")
        
        // Load or create settings
        if let loaded = Self.loadSettings(from: configFile) {
            self.settings = loaded
        } else {
            self.settings = Settings()
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
    }
    
    /// Update a specific setting
    func update<T>(_ keyPath: WritableKeyPath<Settings, T>, to value: T) {
        settings[keyPath: keyPath] = value
        saveSettings()
    }
    
    // MARK: - Persistence
    
    /// Save current settings to disk
    private func saveSettings() {
        do {
            // Create config directory if needed
            try FileManager.default.createDirectory(
                at: configDirectory,
                withIntermediateDirectories: true
            )
            
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
    }
    
    /// Apply layout settings
    private func applyLayoutSettings() {
        // Apply to all workspaces
        WindowManager.shared.monitors.forEach { monitor in
            monitor.workspaces.forEach { workspace in
                // Set initial layout type if not already set
                workspace.tilingEngine.setLayoutType(named: settings.defaultLayout)
                
                // Update gap settings
                workspace.tilingEngine.config.windowGap = CGFloat(settings.gapSize)
                workspace.tilingEngine.config.outerGap = CGFloat(settings.outerGap)
                
                // Reapply tiling
                if workspace.isActive {
                    workspace.applyTiling()
                }
            }
        }
    }
    
    /// Apply appearance settings
    private func applyAppearanceSettings() {
        // Update menu bar visibility
        if let menuBarController = NSApp.mainMenu?.items.first?.submenu?.items.first?.view?.window?.windowController {
            menuBarController.window?.setIsVisible(settings.showMenuBar)
        }
        
        // Apply accent color
        if let color = colorFromName(settings.accentColor) {
//            NSApplication.shared.appearance?.setAccentColor(color)
        }
    }
    
    /// Apply behavior settings
    private func applyBehaviorSettings() {
        // These are handled in real-time by the window manager
        NotificationCenter.default.post(
            name: Notification.Name("com.yuki.SettingsChanged"),
            object: nil,
            userInfo: ["settings": settings]
        )
    }
    
    /// Apply window rules
    private func applyWindowRules() {
        // Refresh window manager to apply new rules
        WindowManager.shared.monitorWithMouse?.activeWorkspace?.applyTiling()
    }
    
    /// Apply keyboard shortcuts
    private func applyKeyboardShortcuts() {
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
