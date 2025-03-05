//
//  WindowManager+Windows.swift
//  Yuki
//
//  Created by Daniel Inama on 5/3/25.
//

import Foundation
import Cocoa

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
