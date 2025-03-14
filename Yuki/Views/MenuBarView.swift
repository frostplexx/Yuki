//
//  MenuBarView.swift
//  Yuki
//
//  Created by Daniel Inama on 6/3/25.
//

import SwiftUI

struct MenuBarView: View {
    var openSettings: () -> Void

    // Add state observation for WindowManager
    @ObservedObject var windowManager: WindowManager = WindowManager.shared
    @State private var debugClassification = false
    @State private var isAddingWorkspace = false
    @State private var newWorkspaceName = ""
    @State private var selectedMonitor: Monitor? = nil

    let switcher = WorkspaceSwitcher()

    var body: some View {
        VStack(spacing: 0) {
            Button {

                // Switch to workspace 2
                switcher.switchToWorkspace(index: 2)

            } label: {
                Text("Test")
            }
            // Header section with version
            HStack {
                Text("Yuki")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Text("v1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.1))

            Divider()

            // Monitors and workspaces
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(windowManager.monitors) { monitor in
                        MonitorMenuSection(
                            monitor: monitor,
                            addWorkspace: {
                                newWorkspaceName = ""
                                selectedMonitor = monitor
                                isAddingWorkspace = true
                            }
                        )
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(
                height: min(CGFloat(windowManager.monitors.count) * 120, 300))

            Divider()

            // Layout Controls
            VStack(spacing: 0) {
                Text("Layout Controls")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                // Layout buttons grid
                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ], spacing: 8
                ) {
                    LayoutButton(
                        title: "BSP",
                        icon: "square.grid.2x2",
                        action: { windowManager.arrangeCurrentWorkspaceBSP() }
                    )

                    LayoutButton(
                        title: "H-Stack",
                        icon: "rectangle.split.3x1",
                        action: {
                            windowManager.arrangeCurrentWorkspaceHorizontally()
                        }
                    )

                    LayoutButton(
                        title: "V-Stack",
                        icon: "rectangle.split.1x2",
                        action: {
                            windowManager.arrangeCurrentWorkspaceVertically()
                        }
                    )

                    LayoutButton(
                        title: "Stack",
                        icon: "square.stack",
                        action: {
                            windowManager.arrangeCurrentWorkspaceStacked()
                        }
                    )

                    LayoutButton(
                        title: "Float",
                        icon: "arrow.up.and.down.and.arrow.left.and.right",
                        action: { windowManager.floatCurrentWorkspace() }
                    )

                    LayoutButton(
                        title: "Refresh",
                        icon: "arrow.clockwise",
                        action: {
                            windowManager.monitorWithMouse?.activeWorkspace?
                                .applyTiling()
                        }
                    )
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            Divider()

            // Actions
            VStack(spacing: 0) {
                Button(action: {
                    windowManager.printDebugInfo()
                }) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Debug Info")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(MenuButtonStyle())

                Button(action: {
                    windowManager.discoverAndAssignWindows()
                    windowManager.monitorWithMouse?.activeWorkspace?
                        .applyTiling()
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Refresh Windows")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(MenuButtonStyle())

                Button(action: openSettings) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(MenuButtonStyle())
                .keyboardShortcut(",")

                Divider()

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack {
                        Image(systemName: "power")
                        Text("Quit Yuki")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(MenuButtonStyle())
                .keyboardShortcut("q")
            }
        }
        .frame(width: 280)
        .fixedSize(horizontal: true, vertical: false)
        .sheet(isPresented: $isAddingWorkspace) {
            addWorkspaceView
        }
    }

    private var addWorkspaceView: some View {
        VStack(spacing: 24) {
            // Header
            Text("Add New Workspace")
                .font(.headline)

            // Form
            VStack(alignment: .leading, spacing: 16) {
                // Monitor name (non-editable)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Monitor")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(selectedMonitor?.name ?? "Unknown")
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }

                // Workspace name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workspace Name")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("Enter name", text: $newWorkspaceName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            if !newWorkspaceName.isEmpty
                                && selectedMonitor != nil
                            {
                                createWorkspace()
                            }
                        }
                }
            }
            .padding(.horizontal, 16)

            // Buttons
            HStack {
                Button("Cancel") {
                    isAddingWorkspace = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    createWorkspace()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newWorkspaceName.isEmpty || selectedMonitor == nil)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func createWorkspace() {
        if !newWorkspaceName.isEmpty, let monitor = selectedMonitor {
            let newWorkspace = monitor.createWorkspace(name: newWorkspaceName)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                newWorkspace.activate()
            }
            isAddingWorkspace = false
        }
    }
}

// MARK: - Component Views

struct MonitorMenuSection: View {
    var monitor: Monitor
    var addWorkspace: () -> Void

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Monitor header
            HStack {
                Image(systemName: "display")
                    .foregroundColor(.secondary)

                Text(monitor.name)
                    .font(.system(size: 13, weight: .semibold))

                if monitor.isMain {
                    Text("Main")
                        .font(.system(size: 9))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }

                Spacer()

                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Image(
                        systemName: isExpanded
                            ? "chevron.down" : "chevron.right"
                    )
                    .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)

            // Workspaces
            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(monitor.workspaces) { workspace in
                        WorkspaceRow(workspace: workspace)
                    }

                    // Add workspace button
                    Button(action: addWorkspace) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.accentColor)

                            Text("Add Workspace")
                                .foregroundColor(.accentColor)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 4)
                    .padding(.leading, 16)
                }
                .padding(.leading, 16)
            }
        }
        .padding(.vertical, 4)
    }
}

struct WorkspaceRow: View {
    var workspace: WorkspaceNode

    @State private var isHovering = false

    var body: some View {
        Button(action: {
            workspace.activate()
        }) {
            HStack {
                // Layout icon
                layoutIcon
                    .frame(width: 16, height: 16)
                    .foregroundColor(
                        workspace.isActive ? .accentColor : .secondary)

                // Name
                Text(workspace.title ?? "Untitled")
                    .font(.system(size: 13))

                // Window count
                Text("(\(workspace.getAllWindowNodes().count))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Spacer()

                // Active indicator
                if workspace.isActive {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        workspace.isActive
                            ? Color.accentColor.opacity(0.1)
                            : (isHovering
                                ? Color.secondary.opacity(0.1) : Color.clear))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }

    var layoutIcon: some View {
        let iconName: String

        switch workspace.tilingEngine.currentLayoutType {
        case .bsp:
            iconName = "square.grid.2x2"
        case .hstack:
            iconName = "rectangle.split.3x1"
        case .vstack:
            iconName = "rectangle.split.1x2"
        case .zstack:
            iconName = "square.stack"
        case .float:
            iconName = "arrow.up.and.down.and.arrow.left.and.right"
        }

        return Image(systemName: iconName)
    }
}

struct LayoutButton: View {
    var title: String
    var icon: String
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))

                Text(title)
                    .font(.system(size: 11))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isHovering
                            ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation {
                isHovering = hovering
            }
        }
    }
}

struct MenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .background(
                configuration.isPressed
                    ? Color.accentColor.opacity(0.2)
                    : (configuration.trigger.isHover
                        ? Color.secondary.opacity(0.1) : Color.clear)
            )
    }
}

extension ButtonStyleConfiguration {
    var trigger: Trigger {
        var value = Trigger()
        if isPressed { value.insert(.press) }
        return value
    }

    struct Trigger: OptionSet {
        var rawValue: Int = 0
        static let press = Trigger(rawValue: 1 << 0)
        var isHover: Bool { !isEmpty && !contains(.press) }
    }
}

#Preview {
    MenuBarView(openSettings: {})
        .environmentObject(WindowManager.shared)
}
