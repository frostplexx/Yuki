import Cocoa
import ApplicationServices

class WorkspaceSwitcher {
    // Function to switch to a specific workspace using accessibility APIs
    // This approach is more reliable than attempting to use private CGS APIs
    @discardableResult
    func switchToWorkspace(index: Int) -> Bool {
        // Ensure workspace index is valid (positive number)
        guard index >= 0 else {
            print("Error: Workspace index must be non-negative")
            return false
        }
        
        // First method: Using System Events and UI scripting (no animation, but faster)
        if switchUsingAccessibilityAPI(index: index) {
            print("Successfully switched to workspace \(index) using Accessibility API")
            return true
        }
        
        // Second method: Using key commands via AppleScript (has animation, but more reliable)
        if switchUsingAppleScript(index: index) {
            print("Successfully switched to workspace \(index) using AppleScript")
            return true
        }
        
        print("Failed to switch to workspace \(index)")
        return false
    }
    
    // Switch using Accessibility API - no animation approach
    private func switchUsingAccessibilityAPI(index: Int) -> Bool {
        // Get the system-wide accessibility element
        let systemWideElement = AXUIElementCreateSystemWide()
        
        // Get the Dock process
        let dockPID = getDockPID()
        guard dockPID > 0 else {
            print("Could not find Dock process")
            return false
        }
        
        // Create an accessibility element for the Dock
        let dockElement = AXUIElementCreateApplication(dockPID)
        
        // Try to get the Mission Control element from the Dock
        var spaces: AnyObject?
        let spacesError = AXUIElementCopyAttributeValue(
            dockElement,
            "AXApplicationDockItem" as CFString,
            &spaces
        )
        
        if spacesError != .success {
            print("Failed to get Dock spaces: \(spacesError)")
            return false
        }
        
        // Try to get the specific space button
        guard let spacesList = spaces as! AXUIElement? else {
            print("Could not get spaces list")
            return false
        }
        
        var children: AnyObject?
        let childrenError = AXUIElementCopyAttributeValue(
            spacesList,
            "AXChildren" as CFString,
            &children
        )
        
        if childrenError != .success {
            print("Failed to get space children: \(childrenError)")
            return false
        }
        
        // Find and press the specific space button
        guard let spaceButtons = children as? [AXUIElement], index < spaceButtons.count else {
            print("Could not get space buttons or index out of range")
            return false
        }
        
        // Press the space button to switch to it
        let pressError = AXUIElementPerformAction(spaceButtons[index], "AXPress" as CFString)
        return pressError == .success
    }
    
    // Switch using AppleScript keyboard shortcut
    private func switchUsingAppleScript(index: Int) -> Bool {
        // This AppleScript simulates pressing Control+Number to switch space
        let keyCode: Int
        
        // Map index to the appropriate key code
        if index < 10 {
            // For spaces 1-9, use the number row keys (key codes 18-26)
            keyCode = 18 + index  // Key code 18 is '1', 19 is '2', etc.
        } else {
            // Space 10 is typically mapped to the '0' key (key code 29)
            keyCode = 29
        }
        
        let script = """
        tell application "System Events"
            key code \(keyCode) using {control down}
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error: \(error)")
                return false
            }
            return true
        }
        
        return false
    }
    
    // Get the PID of the Dock process
    private func getDockPID() -> pid_t {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-axo", "pid,comm"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return 0
        }
        
        // Find the line containing "Dock"
        for line in output.components(separatedBy: "\n") {
            if line.contains("Dock") {
                let components = line.trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
                if let pidStr = components.first?.trimmingCharacters(in: .whitespaces),
                   let pid = Int32(pidStr) {
                    return pid
                }
            }
        }
        
        return 0
    }
    
    // Get the number of workspaces
    func getWorkspaceCount() -> Int {
        let script = """
        tell application "System Events"
            tell process "Dock"
                tell list 1
                    get count of items
                end tell
            end tell
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error: \(error)")
                return -1
            } else if let countStr = result.stringValue, let count = Int(countStr) {
                return count
            }
        }
        
        return -1
    }
    
    // Get the current workspace
    func getCurrentWorkspace() -> Int {
        // Unfortunately, there's no reliable way to get the current workspace
        // without using private APIs that might change across macOS versions
        
        print("Getting current workspace is not supported without private APIs")
        print("The AppleScript method only allows switching workspaces")
        
        return -1
    }
}

