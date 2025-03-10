//
//  WorkspaceView.swift
//  Yuki
//
//  Created by Daniel Inama on 7/3/25.
//
import SwiftUI

struct WorkspaceView: View {
    @StateObject var windowManager = WindowManager.shared
    @StateObject private var settings = SettingsManager.shared
    @State private var scale: CGFloat = 10
    @State private var selectedMonitor: Monitor? = nil
    @State private var maxDisplayWidth: CGFloat = 160
    @State private var monitorPadding: CGFloat = 20
    @State private var minMonitorWidth: CGFloat = 80

    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                //                Text("Monitors")
                //                    .font(.system(size: 13, weight: .medium))
                //                    .opacity(0.5)
                //                    .padding(.horizontal)

                ZStack {
                    // Background with depth effect
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.black.opacity(0.03))
                        .shadow(
                            color: .black.opacity(0.1), radius: 2, x: 0, y: 1
                        )
                        .shadow(
                            color: .black.opacity(0.05), radius: 15, x: 0, y: 10
                        )

                    // Glass blur effect
                    RoundedRectangle(cornerRadius: 18)
                        .foregroundStyle(.ultraThinMaterial)

                    // Inner reflection highlight
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        .padding(1)

                    // Monitors container
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
                        }
                    }
                    .padding(.vertical, 25)
                    .padding(.horizontal, 35)
                }
                .frame(height: 220)
            }

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
                                get: { settings.settings.defaultLayout },
                                set: {
                                    settings.update(\.defaultLayout, to: $0)
                                }
                            )
                        ) {
                            Text("Binary Space Partition").tag("bsp")
                            Text("Horizontal Stack").tag("hstack")
                            Text("Vertical Stack").tag("vstack")
                            Text("Stacked Windows").tag("zstack")
                            Text("Float").tag("float")
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding()
                }

                // Gap configuration
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Window Gaps")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack {
                            Text("Inner Gap:")
                            Slider(
                                value: .init(
                                    get: { Double(settings.settings.gapSize) },
                                    set: {
                                        settings.update(\.gapSize, to: Int($0))
                                    }
                                ),
                                in: 0...50
                            )
                            Text("\(settings.settings.gapSize)px")
                                .monospacedDigit()
                                .frame(width: 50, alignment: .trailing)
                        }

                        HStack {
                            Text("Outer Gap:")
                            Slider(
                                value: .init(
                                    get: { Double(settings.settings.outerGap) },
                                    set: {
                                        settings.update(\.outerGap, to: Int($0))
                                    }
                                ),
                                in: 0...50
                            )
                            Text("\(settings.settings.outerGap)px")
                                .monospacedDigit()
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                    .padding()
                }

                // Window behavior
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Window Behavior")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Toggle(
                            "Float new windows by default",
                            isOn: .init(
                                get: { settings.settings.floatNewWindows },
                                set: {
                                    settings.update(\.floatNewWindows, to: $0)
                                }
                            ))
                    }
                    .padding()
                }
            }

            SelectedMonitorView(selectedMonitor: $selectedMonitor)

            Spacer()
        }
        .padding()
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

            // Monitor name label
            Text(monitor.name)
                .font(.system(size: isSelected ? 13 : 12))
                .opacity(isSelected ? 1.0 : 0.7)
                .fontWeight(isSelected ? .medium : .regular)
                .foregroundColor(isSelected ? .primary : .secondary)
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

#Preview {
    WorkspaceView()
}
