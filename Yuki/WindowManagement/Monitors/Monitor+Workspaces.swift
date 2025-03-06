//
//  Monitor+Workspaces.swift
//  Yuki
//
//  Created by Daniel Inama on 5/3/25.
//

import Foundation

extension Monitor {
    func initDefaultWorkspaces() {
        workspaces.append(WorkspaceNode(title: "Default", monitor: self))
        workspaces.append(WorkspaceNode(title: "Alternate", monitor: self))
        activeWorkspace = workspaces[0]
    }
}
