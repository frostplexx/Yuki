//
//  WorkspaceCard.swift
//  Yuki
//
//  Created by Daniel Inama on 12/3/25.
//

import SwiftUI

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
                isActive ? Color.accentColor.opacity(0.1) : Color.clear
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
