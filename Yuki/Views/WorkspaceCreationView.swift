//
//  WorkspaceCreationView.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import SwiftUI

struct WorkspaceCreationView: View {
    // Required properties
    @Binding var workspaceName: String
    @Binding var isShowing: Bool
    var windowManager: WindowManager
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Create New Workspace")
                .font(.headline)
            
            TextField("Workspace Name", text: $workspaceName)
                .frame(width: 200)
            
            HStack {
                Button("Cancel") {
                    cancel()
                }
                
                Button("Create") {
                    createWorkspace()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(workspaceName.isEmpty)
            }
        }
        .padding()
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    // MARK: - Actions
    
    private func cancel() {
        isShowing = false
        workspaceName = ""
    }
    
    private func createWorkspace() {
        if !workspaceName.isEmpty {
            windowManager.createNewWorkspace(name: workspaceName)
            isShowing = false
            workspaceName = ""
        }
    }
}
