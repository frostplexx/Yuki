import SwiftUI

struct WindowRulesView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var newFloatingApp = ""
    @State private var newFloatingTitle = ""
    @State private var isShowingAppSelector = false
    @State private var searchText = ""
    @State private var selectedTab = 0
    
    // Animation states
    @State private var showCheckmark = false
    
    private var currentApps: [String] {
        Array(settings.getSettings().floatingApps).sorted()
    }
    
    private var currentTitles: [String] {
        Array(settings.getSettings().floatingWindowTitles).sorted()
    }
    
    private var runningApps: [NSRunningApplication] {
        let apps = NSWorkspace.shared.runningApplications
        return apps.filter { $0.activationPolicy == .regular }
    }
    
    private var filteredApps: [NSRunningApplication] {
        if searchText.isEmpty {
            return runningApps
        } else {
            return runningApps.filter {
                $0.localizedName?.lowercased().contains(searchText.lowercased()) ?? false ||
                $0.bundleIdentifier?.lowercased().contains(searchText.lowercased()) ?? false
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selection
            HStack {
                tabButton(title: "Floating Apps", index: 0)
                tabButton(title: "Window Title Patterns", index: 1)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Divider()
                .padding(.top, 8)
            
            if selectedTab == 0 {
                appRulesView
                    .transition(.opacity)
            } else {
                titleRulesView
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $isShowingAppSelector) {
            appSelectorSheet
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
        .onAppear {
            // Load running apps initially
        }
    }
    
    private func tabButton(title: String, index: Int) -> some View {
        Button(action: {
            selectedTab = index
        }) {
            Text(title)
                .font(.system(size: 14, weight: selectedTab == index ? .semibold : .regular))
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .foregroundColor(selectedTab == index ? .accentColor : .secondary)
                .background(
                    selectedTab == index ?
                        Color.accentColor.opacity(0.1) :
                        Color.clear
                )
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - App Rules View
    
    private var appRulesView: some View {
        VStack(spacing: 16) {
            // Description
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.accentColor)
                        Text("Apps that will always float on top of the tiling layout")
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                    
                    Text("Use this for applications that don't work well with tiling window managers, such as utilities with custom window shapes or modal windows.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(10)
            }
            .padding(.horizontal)
            
            // Input for new app
            HStack {
                TextField("App Bundle ID", text: $newFloatingApp)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        addFloatingApp()
                    }
                
                Button("Choose App") {
                    isShowingAppSelector = true
                }
                
                Button(action: addFloatingApp) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 18))
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(newFloatingApp.isEmpty)
//                .keyboardShortcut(.defaultAction, modifiers: [])
            }
            .padding(.horizontal)
            
            // List of floating apps with empty state message
            if currentApps.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("No floating apps configured")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Add applications that shouldn't be automatically tiled")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 250)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(currentApps, id: \.self) { app in
                            FloatingAppRow(
                                bundleID: app,
                                onDelete: { removeFloatingApp(app) }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .animation(.easeInOut(duration: 0.2), value: currentApps.count)
            }
            
            Spacer()
        }
        .padding(.top, 16)
    }
    
    // MARK: - Title Rules View
    
    private var titleRulesView: some View {
        VStack(spacing: 16) {
            // Description
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.accentColor)
                        Text("Windows with these titles will always float")
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                    
                    Text("Use patterns that match dialog boxes, popups, or utility windows. These patterns are case-insensitive and match any window title containing the text.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(10)
            }
            .padding(.horizontal)
            
            // Input for new window title
            HStack {
                TextField("Window Title Pattern", text: $newFloatingTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        addFloatingTitle()
                    }
                
                Button(action: addFloatingTitle) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 18))
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(newFloatingTitle.isEmpty)
//                .keyboardShortcut(.defaultAction, modifiers: [])
            }
            .padding(.horizontal)
            
            // List of floating title patterns with empty state message
            if currentTitles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("No title patterns configured")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Add patterns like \"Preferences\", \"Settings\", or \"Dialog\" to automatically float windows with matching titles")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 250)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(currentTitles, id: \.self) { title in
                            FloatingTitleRow(
                                titlePattern: title,
                                onDelete: { removeFloatingTitle(title) }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .animation(.easeInOut(duration: 0.2), value: currentTitles.count)
            }
            
            Spacer()
        }
        .padding(.top, 16)
    }
    
    // MARK: - App Selector Sheet
    
    private var appSelectorSheet: some View {
        VStack(spacing: 16) {
            // Header
            Text("Select an Application")
                .font(.headline)
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search by name or bundle ID", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            // App list
            List(filteredApps, id: \.bundleIdentifier) { app in
                Button(action: {
                    if let bundleID = app.bundleIdentifier {
                        newFloatingApp = bundleID
                        isShowingAppSelector = false
                        
                        // Add after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            addFloatingApp()
                        }
                    }
                }) {
                    HStack {
                        // App icon
                        if let appIcon = app.icon {
                            Image(nsImage: appIcon)
                                .resizable()
                                .frame(width: 32, height: 32)
                                .cornerRadius(4)
                        } else {
                            Image(systemName: "app.dashed")
                                .resizable()
                                .frame(width: 32, height: 32)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(app.localizedName ?? "Unknown App")
                                .fontWeight(.medium)
                            
                            if let bundleID = app.bundleIdentifier {
                                Text(bundleID)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Check if already in floating apps
                        if let bundleID = app.bundleIdentifier,
                           settings.getSettings().floatingApps.contains(bundleID) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Cancel button
            Button("Cancel") {
                isShowingAppSelector = false
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding()
        .frame(width: 450, height: 500)
    }
    
    // MARK: - Actions
    
    private func addFloatingApp() {
        if !newFloatingApp.isEmpty {
            var apps = settings.getSettings().floatingApps
            apps.insert(newFloatingApp)
            settings.update(\.floatingApps, to: apps)
            
            withAnimation {
                showCheckmark = true
            }
            
            newFloatingApp = ""
            
            // Hide checkmark after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showCheckmark = false
                }
            }
        }
    }
    
    private func removeFloatingApp(_ app: String) {
        var apps = settings.getSettings().floatingApps
        apps.remove(app)
        settings.update(\.floatingApps, to: apps)
    }
    
    private func addFloatingTitle() {
        if !newFloatingTitle.isEmpty {
            var titles = settings.getSettings().floatingWindowTitles
            titles.insert(newFloatingTitle)
            settings.update(\.floatingWindowTitles, to: titles)
            newFloatingTitle = ""
        }
    }
    
    private func removeFloatingTitle(_ title: String) {
        var titles = settings.getSettings().floatingWindowTitles
        titles.remove(title)
        settings.update(\.floatingWindowTitles, to: titles)
    }
}

// MARK: - Row Components

struct FloatingAppRow: View {
    var bundleID: String
    var onDelete: () -> Void
    
    @State private var isHovering = false
    @State private var showInfo = false
    
    var body: some View {
        HStack {
            // Bundle ID
            VStack(alignment: .leading, spacing: 4) {
                Text(appDisplayName)
                    .fontWeight(.medium)
                
                Text(bundleID)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Info button
            Button(action: { showInfo.toggle() }) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(isHovering ? 1 : 0)
            .popover(isPresented: $showInfo) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("App Information")
                        .font(.headline)
                    
                    Divider()
                    
                    Text("Bundle ID: \(bundleID)")
                        .font(.system(.body, design: .monospaced))
                    
                    if let appPath = getAppPath() {
                        Text("Location: \(appPath)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(width: 300)
            }
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(isHovering ? 1 : 0)
        }
        .padding(10)
        .background(Color.secondary.opacity(isHovering ? 0.1 : 0))
        .cornerRadius(8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
    
    // Get human-readable app name if possible
    private var appDisplayName: String {
        // Try to find a running app with this bundle ID
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
            return app.localizedName ?? bundleID
        }
        
        // Try to look up in installed apps
        let appName = bundleID.split(separator: ".").last?.capitalized
        return appName ?? bundleID
    }
    
    // Get app path if available
    private func getAppPath() -> String? {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }),
           let url = app.bundleURL {
            return url.path
        }
        return nil
    }
}

struct FloatingTitleRow: View {
    var titlePattern: String
    var onDelete: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            // Pattern icon
            Image(systemName: "text.quote")
                .foregroundColor(.secondary)
                .frame(width: 24, height: 24)
            
            // Pattern text
            Text(titlePattern)
                .fontWeight(.medium)
            
            Spacer()
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(isHovering ? 1 : 0)
        }
        .padding(10)
        .background(Color.secondary.opacity(isHovering ? 0.1 : 0))
        .cornerRadius(8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Extensions

extension NSRunningApplication {
    var icon: NSImage? {
        return self.icon
    }
}

#Preview {
    WindowRulesView()
        .frame(width: 600, height: 500)
}
