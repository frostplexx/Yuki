//
//  WindowNode+Extension.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import Foundation
import Cocoa

extension WindowNode {
    /// Disables the AXEnhancedUserInterface setting for this window
    /// This prevents incorrect window resizing (related to issue #285)
    func disableEnhancedUserInterface() {
        window.set(Ax.enhancedUserInterfaceAttr, false)
    }
    
    /// Enables the AXEnhancedUserInterface setting for this window
    func enableEnhancedUserInterface() {
        window.set(Ax.enhancedUserInterfaceAttr, true)
    }
    
    /// Resizes the window without using the native resizing which can have issues
    /// - Parameter newSize: The new size to apply
    func resizeWithoutEnhancement(to newSize: NSSize) {
        // Temporarily disable enhanced user interface
        let currentEnhancedSetting = window.get(Ax.enhancedUserInterfaceAttr) ?? false
        
        if currentEnhancedSetting {
            window.set(Ax.enhancedUserInterfaceAttr, false)
        }
        
        // Perform the resize
        window.set(Ax.sizeAttr, CGSize(width: newSize.width, height: newSize.height))
        
        // Restore the previous setting
        if currentEnhancedSetting {
            window.set(Ax.enhancedUserInterfaceAttr, true)
        }
    }
    
}

extension WindowManager {
    /// Disables enhanced user interface for all managed windows
    /// Call this during initialization to prevent resize issues
    func disableEnhancedUserInterfaceForAllWindows() {
        for monitor in monitors {
            for workspace in monitor.workspaces {
                for windowNode in workspace.root.getAllWindowNodes() {
                    windowNode.disableEnhancedUserInterface()
                }
            }
        }
    }
    
    /// Refreshes windows and ensures enhanced user interface is disabled
    func refreshWindowsWithoutEnhancement() {
        refreshWindows()
        disableEnhancedUserInterfaceForAllWindows()
    }
}
