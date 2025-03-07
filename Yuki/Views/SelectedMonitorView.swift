//
//  SelectedMonitorView.swift
//  Yuki
//
//  Created by Daniel Inama on 7/3/25.
//
import SwiftUI

struct SelectedMonitorView: View {
    @Binding var selectedMonitor: Monitor?
    @State private var workSpaceBeingEdited: WorkspaceNode?
    @State private var isAddingWorkspace = false
    @State private var newWorkspaceName = ""

    var body: some View {
        if let selectedMonitor {
            VStack(alignment: .leading, spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(selectedMonitor.workspaces, id: \.id) {
                            workspace in
                            WorkspaceButton(
                                workspace: workspace,
                                isActive: workSpaceBeingEdited == workspace,
                                workSpaceBeingEdited: $workSpaceBeingEdited
                            )
                        }

                        Button(
                            action: {
                                isAddingWorkspace = true
                                newWorkspaceName = ""
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10))
                                    .frame(width: 16, height: 16)
                                    .background(Color.gray.opacity(0.2))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 5)
                            .popover(
                                isPresented: $isAddingWorkspace,
                                arrowEdge: .bottom
                            ) {
                                VStack(spacing: 5) {
                                    TextField(
                                        "Workspace name",
                                        text: $newWorkspaceName
                                    )
                                    .textFieldStyle(
                                        PlainTextFieldStyle()
                                    )
                                    .padding(.horizontal)
                                    .frame(width: 100)

                                    HStack {
                                        Button("Create") {
                                            if !newWorkspaceName.isEmpty {
                                                createNewWorkspace()
                                                isAddingWorkspace = false
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .disabled(newWorkspaceName.isEmpty)
                                    }
                                }
                                .padding(5)
                            }
                    }
                    .padding(.horizontal, 2)
                }
                .padding(5)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
            .onAppear {
                workSpaceBeingEdited = selectedMonitor.workspaces.first
            }
            .onDisappear {
                workSpaceBeingEdited = nil
            }
        } else {
            Text("Select a Monitor")
                .foregroundColor(.secondary)
        }
    }

    private func createNewWorkspace() {
        // Create a new workspace with the entered name
        // This implementation depends on how your app handles data
        // For now, we're just creating a simple example
        if let selectedMonitor {
            let newWorkspace = WorkspaceNode(
                title: newWorkspaceName,
                monitor: selectedMonitor
            )
            // Add the new workspace to the monitor
            // Note: This assumes Monitor is a struct, so we need to create a new one
            selectedMonitor.workspaces.append(newWorkspace)
            workSpaceBeingEdited = newWorkspace
        } else {
            return
        }

    }
}

// Workspace button component for the selected monitor's workspaces
struct WorkspaceButton: View {
    var workspace: WorkspaceNode
    var isActive: Bool
    @Binding var workSpaceBeingEdited: WorkspaceNode?

    var body: some View {
        Button {
            //            workspace.activate()
            workSpaceBeingEdited = workspace
        } label: {
            Text(workspace.title ?? "Untitled")
                .font(.system(size: 11))
                .fontWeight(isActive ? .semibold : .regular)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .foregroundColor(isActive ? .white : .primary)
                .background(
                    isActive ? Color.accentColor : Color.gray.opacity(0.2)
                )
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .shadow(
            color: isActive ? Color.accentColor.opacity(0.3) : .clear, radius: 3
        )
    }
}
