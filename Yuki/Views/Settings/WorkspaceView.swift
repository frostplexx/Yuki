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
    
    // Animation states
    @State private var animateMonitors = false

    var body: some View {
        ScrollView {
            
            VStack(spacing: 20) {
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
                            ForEach(windowManager.monitors, id: \.self) { monitor in
                                MonitorElement(
                                    monitor: monitor,
                                    scale: scale,
                                    isSelected: selectedMonitor?.id == monitor.id,
                                    onSelect: {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedMonitor = monitor
                                        }
                                    }
                                )
                                .scaleEffect(animateMonitors ? 1.0 : 0.9)
                                .opacity(animateMonitors ? 1.0 : 0.7)
                            }
                        }
                        .padding(.vertical, 25)
                        .padding(.horizontal, 35)
                    }
                }
                .frame(height: 240)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        animateMonitors = true
                    }
                }
                
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
                                Label("Add Workspace", systemImage: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 4)
                        
                        // Workspace grid
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 16)
                        ], spacing: 16) {
                            ForEach(selectedMonitor.workspaces) { workspace in
                                WorkspaceCard(
                                    workspace: workspace,
                                    isActive: workspace.isActive,
                                    onActivate: { workspace.activate() },
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
                                    get: { settings.getSettings().defaultLayout },
                                    set: {
                                        settings.update(\.defaultLayout, to: $0)
                                    }
                                )
                            ) {
                                Label("BSP", systemImage: "square.grid.2x2").tag("bsp")
                                Label("Horizontal", systemImage: "rectangle.split.3x1").tag("hstack")
                                Label("Vertical", systemImage: "rectangle.split.1x2").tag("vstack")
                                Label("Stacked", systemImage: "square.stack").tag("zstack")
                                Label("Float", systemImage: "arrow.up.and.down.and.arrow.left.and.right").tag("float")
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
                                        
                                        Text("\(settings.getSettings().gapSize)px")
                                            .monospacedDigit()
                                            .frame(width: 45, alignment: .trailing)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Slider(
                                            value: .init(
                                                get: { Double(settings.getSettings().gapSize) },
                                                set: {
                                                    settings.update(\.gapSize, to: Int($0))
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
                                        
                                        Text("\(settings.getSettings().outerGap)px")
                                            .monospacedDigit()
                                            .frame(width: 45, alignment: .trailing)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Slider(
                                            value: .init(
                                                get: { Double(settings.getSettings().outerGap) },
                                                set: {
                                                    settings.update(\.outerGap, to: Int($0))
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
                    if let monitor = selectedMonitor, !newWorkspaceName.isEmpty {
                        let newWorkspace = monitor.createWorkspace(name: newWorkspaceName)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            newWorkspace.activate()
                        }
                    }
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
                message: Text("Are you sure you want to delete the workspace '\(workspaceToDelete?.title ?? "")'? All windows will be moved to the next available workspace."),
                primaryButton: .destructive(Text("Delete")) {
                    if let workspace = workspaceToDelete, let monitor = selectedMonitor {
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

struct MonitorElement: View {
    var monitor: Monitor
    var scale: CGFloat
    var isSelected: Bool
    var onSelect: () -> Void

    @State private var isHovering = false
    @State private var wallpaper: NSImage?
    @State private var isLoadingWallpaper = true

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            // Monitor frame view with hover effects
            ZStack {
                // Monitor frame with wallpaper
                ZStack {
                    // Wallpaper image or loading placeholder
                    if isLoadingWallpaper {
                        // Loading placeholder
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .gray.opacity(0.3), .gray.opacity(0.5),
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .opacity(0.7)

                        ProgressView()
                            .scaleEffect(0.7)
                    } else if let wallpaper = wallpaper {
                        Image(nsImage: wallpaper)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        // Fallback if no wallpaper
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .blue.opacity(0.6), .purple.opacity(0.6),
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }

                    // Windows visualization placeholder
                    ForEach(
                        0..<min(
                            3,
                            monitor.workspaces.flatMap {
                                $0.getAllWindowNodes()
                            }.count), id: \.self
                    ) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.8))
                            .frame(
                                width: max(15, scaledWidth / 3),
                                height: max(10, scaledHeight / 3)
                            )
                            .offset(
                                x: CGFloat(index * 5), y: CGFloat(index * 5))
                    }
                }
                .frame(width: scaledWidth, height: scaledHeight)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                // Selection indicator
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: 2)
                        .frame(
                            width: scaledWidth + 12,
                            height: scaledHeight + 12
                        )
                }
            }
            .frame(width: scaledWidth + 50, height: scaledHeight + 30)
            .scaleEffect(isHovering ? 1.05 : 1.0)
            .shadow(
                color: .black.opacity(isHovering ? 0.3 : 0.15),
                radius: isHovering ? 8 : 4,
                x: 0,
                y: isHovering ? 5 : 2
            )
            .animation(
                .interactiveSpring(response: 0.25, dampingFraction: 0.7),
                value: isHovering
            )
            .contentShape(Rectangle())

            // Monitor name label with active workspace
            VStack(spacing: 4) {
                Text(monitor.name)
                    .font(.system(size: isSelected ? 13 : 12))
                    .fontWeight(isSelected ? .medium : .regular)
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                if let activeWorkspace = monitor.activeWorkspace {
                    Text(activeWorkspace.title ?? "Untitled")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .onHover { hovering in
            withAnimation {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onSelect()
        }
        .onAppear {
            // Load wallpaper asynchronously
            loadWallpaperAsync()
        }
    }

    // Calculate width based on scale, with a minimum size
    private var scaledWidth: CGFloat {
        max(80, monitor.width / scale)
    }

    // Calculate height based on scale, with a minimum size
    private var scaledHeight: CGFloat {
        max(45, monitor.height / scale)
    }

    // Load the actual wallpaper for this monitor asynchronously with caching
    private func loadWallpaperAsync() {
        // Start in loading state
        isLoadingWallpaper = true

        Task {
            // Find the NSScreen that corresponds to this monitor
            if let screen = NSScreen.screens.first(where: {
                NSEqualRects($0.frame, monitor.frame)
            }),
                let wallpaperURL = NSWorkspace.shared.desktopImageURL(
                    for: screen)
            {

                // Use the image cache to load the wallpaper
                ImageCacheManager.shared.getImage(for: wallpaperURL) { image in
                    // Update state on the main thread
                    DispatchQueue.main.async {
                        self.wallpaper = image
                        self.isLoadingWallpaper = false
                    }
                }
            } else {
                // No wallpaper found, exit loading state
                DispatchQueue.main.async {
                    self.isLoadingWallpaper = false
                }
            }
        }
    }
}

struct WorkspaceCard: View {
    var workspace: WorkspaceNode
    var isActive: Bool
    var onActivate: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(workspace.title ?? "Untitled")
                    .font(.headline)
                    .foregroundColor(isActive ? .primary : .secondary)
                
                Spacer()
                
                // Layout type icon
                layoutTypeIcon
                    .foregroundColor(isActive ? .accentColor : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                isActive ?
                    Color.accentColor.opacity(0.1) :
                    Color.clear
            )
            .cornerRadius(8, corners: [.topLeft, .topRight])
            
            // Divider
            Divider()
                .padding(.horizontal, 0)
            
            // Window count and stats
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(workspace.getAllWindowNodes().count) windows")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if workspace.isActive {
                        Text("Active")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // Actions
                HStack(spacing: 8) {
                    Button(action: onActivate) {
                        Image(systemName: "arrow.right.circle")
                            .foregroundColor(.blue)
                            .imageScale(.medium)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .opacity(isHovering ? 1.0 : 0.0)
                    
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle")
                            .foregroundColor(.orange)
                            .imageScale(.medium)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .opacity(isHovering ? 1.0 : 0.0)
                    
                    // Only show delete button if this isn't the only workspace
                    if workspace.monitor.workspaces.count > 1 {
                        Button(action: onDelete) {
                            Image(systemName: "trash.circle")
                                .foregroundColor(.red)
                                .imageScale(.medium)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .opacity(isHovering ? 1.0 : 0.0)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isActive ? Color.accentColor : Color.gray.opacity(0.2),
                    lineWidth: isActive ? 2 : 1
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onActivate()
        }
    }
    
    private var layoutTypeIcon: some View {
        let type = workspace.tilingEngine.currentLayoutType
        
        let iconName: String
        
        switch type {
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
    
    init(workspace: WorkspaceNode, onCancel: @escaping () -> Void, onSave: @escaping (String, String) -> Void) {
        self.workspace = workspace
        self.onCancel = onCancel
        self.onSave = onSave
        
        // Initialize state
        _workspaceName = State(initialValue: workspace.title ?? "")
        _layoutType = State(initialValue: workspace.tilingEngine.currentLayoutType.rawValue)
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
                        Label("Horizontal", systemImage: "rectangle.split.3x1").tag("hstack")
                        Label("Vertical", systemImage: "rectangle.split.1x2").tag("vstack")
                        Label("Stacked", systemImage: "square.stack").tag("zstack")
                        Label("Float", systemImage: "arrow.up.and.down.and.arrow.left.and.right").tag("float")
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

enum RectCorner {
    case topLeft, topRight, bottomLeft, bottomRight, allCorners
    
    static let all: Set<RectCorner> = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

// Helper for applying cornerRadius to specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: Set<RectCorner>) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

struct RoundedCornerShape: Shape {
    var radius: CGFloat = .infinity
    var corners: Set<RectCorner> = Set(RectCorner.all)

    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let topLeft = corners.contains(.topLeft)
        let topRight = corners.contains(.topRight)
        let bottomLeft = corners.contains(.bottomLeft)
        let bottomRight = corners.contains(.bottomRight)
        
        let width = rect.size.width
        let height = rect.size.height
        
        // Start at top-left
        if topLeft {
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        }
        
        // Top-right corner
        if topRight {
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addArc(
                center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                radius: radius,
                startAngle: Angle(degrees: -90),
                endAngle: Angle(degrees: 0),
                clockwise: false
            )
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
        
        // Bottom-right corner
        if bottomRight {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addArc(
                center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                radius: radius,
                startAngle: Angle(degrees: 0),
                endAngle: Angle(degrees: 90),
                clockwise: false
            )
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        
        // Bottom-left corner
        if bottomLeft {
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addArc(
                center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                radius: radius,
                startAngle: Angle(degrees: 90),
                endAngle: Angle(degrees: 180),
                clockwise: false
            )
        } else {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        
        // Back to top-left
        if topLeft {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addArc(
                center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                radius: radius,
                startAngle: Angle(degrees: 180),
                endAngle: Angle(degrees: 270),
                clockwise: false
            )
        } else {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        }
        
        path.closeSubpath()
        return path
    }
}

// Custom transition for smooth workspace selection
extension AnyTransition {
    static var moveAndFade: AnyTransition {
        let insertion = AnyTransition.opacity.combined(with: .move(edge: .top))
        let removal = AnyTransition.opacity.combined(with: .move(edge: .bottom))
        return .asymmetric(insertion: insertion, removal: removal)
    }
}

#Preview {
    WorkspaceView()
        .frame(width: 800, height: 600)
}
