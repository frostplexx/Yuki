//
//  TilingManager+Notifications.swift
//  Yuki
//
//  Created by Daniel Inama on 5/3/25.
//

import Foundation
import Cocoa

extension TilingManager {
        /// Set up notifications for window changes
    func setupNotifications() {
        // Listen for window changes
        let notificationCenter = NSWorkspace.shared.notificationCenter
        
        // Window events
        notificationCenter.addObserver(
            self,
            selector: #selector(handleWindowChange),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        // Additional notification for window resizing or moving
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWindowChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }
    
    /// Handle window change notifications
    @objc private func handleWindowChange() {
        // Apply tiling with a delay to avoid excessive tiling during window manipulations
        WindowManagerProvider.shared.applyCurrentTiling()
    }
}
