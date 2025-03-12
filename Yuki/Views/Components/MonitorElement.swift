//
//  MonitorElement.swift
//  Yuki
//
//  Created by Daniel Inama on 12/3/25.
//

import SwiftUI

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
