import SwiftUI

struct WorkspaceView: View {
    @StateObject var windowManager = WindowManager.shared
    @StateObject private var settings = SettingsManager.shared
    @State private var scale: CGFloat = 10
    @State private var selectedMonitor: Monitor? = nil
    @State private var maxDisplayWidth: CGFloat = 160
    @State private var monitorPadding: CGFloat = 20
    @State private var minMonitorWidth: CGFloat = 80
    @State private var isAddingWorkspace = false
    @State private var newWorkspaceName = ""
    @State private var editingWorkspace: WorkspaceNode? = nil
    @State private var showDeleteAlert = false
    @State private var workspaceToDelete: WorkspaceNode? = nil

    @State private var activeWorkspace: WorkspaceNode? = nil

    var body: some View {
        ScrollView {

            // Monitor visualization section
            ZStack {
                // Monitor display card
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.black.opacity(0.03))
                    .shadow(
                        color: .black.opacity(0.1), radius: 2, x: 0, y: 1
                    )
                    .shadow(
                        color: .black.opacity(0.05), radius: 15, x: 0, y: 10
                    )

                // Glass blur effect
                RoundedRectangle(cornerRadius: 24)
                    .foregroundStyle(.ultraThinMaterial)

                // Inner reflection highlight
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    .padding(1)

                // Monitors container
                VStack {
                    Text("Monitors")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 12)

                    HStack(alignment: .bottom, spacing: 30) {
                        ForEach(windowManager.monitors, id: \.self) {
                            monitor in
                            MonitorElement(
                                monitor: monitor,
                                scale: scale,
                                isSelected: selectedMonitor?.id
                                    == monitor.id,
                                onSelect: {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedMonitor = monitor
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 25)
                    .padding(.horizontal, 35)
                }
            }
            .frame(height: 240)
            .onAppear {
                activeWorkspace =
                    windowManager.monitorWithMouse?.workspaces.first
            }

            VStack(spacing: 20) {
                // Workspace management for selected monitor
                if let selectedMonitor = selectedMonitor {
                    VStack(spacing: 16) {
                        // Workspace header
                        HStack {
                            Text("Workspaces for \(selectedMonitor.name)")
                                .font(.headline)

                            Spacer()

                            Button(action: {
                                isAddingWorkspace = true
                                newWorkspaceName = ""
                            }) {
                                Label(
                                    "Add Workspace",
                                    systemImage: "plus.circle.fill"
                                )
                                .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 4)

                        // Workspace grid
                        LazyVGrid(
                            columns: [
                                GridItem(
                                    .adaptive(minimum: 180, maximum: 220),
                                    spacing: 16)
                            ], spacing: 16
                        ) {
                            ForEach(selectedMonitor.workspaces) { workspace in
                                WorkspaceCard(
                                    workspace: workspace,
                                    isActive: activeWorkspace == workspace,
                                    onActivate: {
                                        activeWorkspace = workspace
                                    },
                                    onEdit: { editingWorkspace = workspace },
                                    onDelete: {
                                        workspaceToDelete = workspace
                                        showDeleteAlert = true
                                    }
                                )
                            }
                        }
                        .padding(8)
                    }
                    .transition(.moveAndFade)
                } else {
                    // No monitor selected
                    VStack {
                        Text("Select a monitor to view and manage workspaces")
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 200)
                }

                // Layout settings section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Layout Configuration")
                        .font(.headline)

                    // Layout type selection
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Default Layout")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Picker(
                                "",
                                selection: .init(
                                    get: {
                                        settings.getSettings().defaultLayout
                                    },
                                    set: {
                                        settings.update(\.defaultLayout, to: $0)
                                    }
                                )
                            ) {
                                Label("BSP", systemImage: "square.grid.2x2")
                                    .tag("bsp")
                                Label(
                                    "Horizontal",
                                    systemImage: "rectangle.split.3x1"
                                ).tag("hstack")
                                Label(
                                    "Vertical",
                                    systemImage: "rectangle.split.1x2"
                                ).tag("vstack")
                                Label("Stacked", systemImage: "square.stack")
                                    .tag("zstack")
                                Label(
                                    "Float",
                                    systemImage:
                                        "arrow.up.and.down.and.arrow.left.and.right"
                                ).tag("float")
                            }
                            .pickerStyle(.segmented)
                            .labelStyle(.iconOnly)
                        }
                        .padding()
                    }

                    // Gap configuration
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Window Gaps")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            VStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Inner Gap:")

                                        Spacer()

                                        Text(
                                            "\(settings.getSettings().gapSize)px"
                                        )
                                        .monospacedDigit()
                                        .frame(width: 45, alignment: .trailing)
                                        .foregroundColor(.secondary)
                                    }

                                    HStack {
                                        Slider(
                                            value: .init(
                                                get: {
                                                    Double(
                                                        settings.getSettings()
                                                            .gapSize)
                                                },
                                                set: {
                                                    settings.update(
                                                        \.gapSize, to: Int($0))
                                                }
                                            ),
                                            in: 0...50,
                                            step: 1
                                        )
                                        .accentColor(.blue)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Outer Gap:")

                                        Spacer()

                                        Text(
                                            "\(settings.getSettings().outerGap)px"
                                        )
                                        .monospacedDigit()
                                        .frame(width: 45, alignment: .trailing)
                                        .foregroundColor(.secondary)
                                    }

                                    HStack {
                                        Slider(
                                            value: .init(
                                                get: {
                                                    Double(
                                                        settings.getSettings()
                                                            .outerGap)
                                                },
                                                set: {
                                                    settings.update(
                                                        \.outerGap, to: Int($0))
                                                }
                                            ),
                                            in: 0...50,
                                            step: 1
                                        )
                                        .accentColor(.blue)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
                .padding(.top, 10)

                Spacer()
            }
        }
        .padding()
        .sheet(isPresented: $isAddingWorkspace) {
            AddWorkspaceView(
                monitorName: selectedMonitor?.name ?? "Unknown",
                workspaceName: $newWorkspaceName,
                onCancel: { isAddingWorkspace = false },
                onSave: {
                    // Make sure we have both a valid name and monitor
                    guard !newWorkspaceName.isEmpty,
                        let monitor = selectedMonitor
                    else {
                        // Handle invalid state
                        isAddingWorkspace = false
                        return
                    }

                    // Create the workspace with proper error handling
                    let newWorkspace = monitor.createWorkspace(
                        name: newWorkspaceName)

                    // Close the dialog
                    isAddingWorkspace = false
                }
            )
        }
        .sheet(item: $editingWorkspace) { workspace in
            EditWorkspaceView(
                workspace: workspace,
                onCancel: { editingWorkspace = nil },
                onSave: { newName, newLayoutType in
                    workspace.rename(to: newName)
                    workspace.setTilingMode(newLayoutType)
                    editingWorkspace = nil
                }
            )
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Delete Workspace"),
                message: Text(
                    "Are you sure you want to delete the workspace '\(workspaceToDelete?.title ?? "")'? All windows will be moved to the next available workspace."
                ),
                primaryButton: .destructive(Text("Delete")) {
                    if let workspace = workspaceToDelete,
                        let monitor = selectedMonitor
                    {
                        monitor.removeWorkspace(workspace)
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            // Calculate scale so the largest monitor fits
            calcScale()
            // Select the monitor with the mouse initially
            selectedMonitor = windowManager.monitorWithMouse
        }
    }

    func calcScale() {
        // Find the largest monitor dimensions
        var largestWidth: CGFloat = 0
        var largestHeight: CGFloat = 0

        for monitor in windowManager.monitors {
            largestWidth = max(largestWidth, monitor.width)
            largestHeight = max(largestHeight, monitor.height)
        }

        // Calculate scale to fit the largest monitor within our max display width
        // while preserving aspect ratio
        let widthScale = largestWidth / maxDisplayWidth
        let heightScale = largestHeight / 150  // Max height we want

        // Take the larger scale factor to ensure it fits in both dimensions
        scale = max(widthScale, heightScale)

        // Ensure scale isn't too small (which would make displays too large)
        scale = max(scale, 5)
    }
}

struct AddWorkspaceView: View {
    var monitorName: String
    @Binding var workspaceName: String
    var onCancel: () -> Void
    var onSave: () -> Void
    @State private var layoutType = "bsp"

    var body: some View {
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

                    Text(monitorName)
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

                    TextField("Enter name", text: $workspaceName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            if !workspaceName.isEmpty {
                                onSave()
                            }
                        }
                }

                // Layout type
                VStack(alignment: .leading, spacing: 8) {
                    Text("Layout Type")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("", selection: $layoutType) {
                        Text("BSP").tag("bsp")
                        Text("Horizontal Stack").tag("hstack")
                        Text("Vertical Stack").tag("vstack")
                        Text("Stacked Windows").tag("zstack")
                        Text("Float").tag("float")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(.horizontal, 16)

            // Buttons
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    onSave()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(workspaceName.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

struct EditWorkspaceView: View {
    var workspace: WorkspaceNode
    var onCancel: () -> Void
    var onSave: (String, String) -> Void

    @State private var workspaceName: String
    @State private var layoutType: String

    init(
        workspace: WorkspaceNode, onCancel: @escaping () -> Void,
        onSave: @escaping (String, String) -> Void
    ) {
        self.workspace = workspace
        self.onCancel = onCancel
        self.onSave = onSave

        // Initialize state
        _workspaceName = State(initialValue: workspace.title ?? "")
        _layoutType = State(
            initialValue: workspace.tilingEngine.currentLayoutType.rawValue)
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            Text("Edit Workspace")
                .font(.headline)

            // Form
            VStack(alignment: .leading, spacing: 16) {
                // Monitor name (non-editable)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Monitor")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(workspace.monitor.name)
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

                    TextField("Enter name", text: $workspaceName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            if !workspaceName.isEmpty {
                                onSave(workspaceName, layoutType)
                            }
                        }
                }

                // Layout type
                VStack(alignment: .leading, spacing: 8) {
                    Text("Layout Type")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("", selection: $layoutType) {
                        Label("BSP", systemImage: "square.grid.2x2").tag("bsp")
                        Label("Horizontal", systemImage: "rectangle.split.3x1")
                            .tag("hstack")
                        Label("Vertical", systemImage: "rectangle.split.1x2")
                            .tag("vstack")
                        Label("Stacked", systemImage: "square.stack").tag(
                            "zstack")
                        Label(
                            "Float",
                            systemImage:
                                "arrow.up.and.down.and.arrow.left.and.right"
                        ).tag("float")
                    }
                    .pickerStyle(.segmented)
                    .labelStyle(.iconOnly)
                }
            }
            .padding(.horizontal, 16)

            // Buttons
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    onSave(workspaceName, layoutType)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(workspaceName.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

#Preview {
    WorkspaceView()
        .frame(width: 800, height: 600)
}
