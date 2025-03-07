//
//  SettingsView.swift
//  Yuki
//
//  Created by Daniel Inama on 4/3/25.
//

import SwiftUI

struct SettingsView: View {
    @State private var showingPermissionView = false
    @State private var selectedTab = 0

    var body: some View {
        CustomTabView(
            content: [
                (
                    title: "Workspaces",
                    icon: "rectangle.3.group",
                    view: AnyView(
                        WorkspaceView()
                    )
                ),
                (
                    title: "Window Rules",
                    icon: "macwindow.on.rectangle",
                    view: AnyView(
                        WindowRulesView()
                    )
                ),
                (
                    title: "Keybindings",
                    icon: "command",
                    view: AnyView(
                        KeyMapView()
                    )
                ),
                (
                    title: "Appearance",
                    icon: "paintbrush",
                    view: AnyView(
                        AppearanceView()
                    )
                ),
                (
                    title: "Advanced",
                    icon: "wrench.and.screwdriver",
                    view: AnyView(
                        AdvanvedSettingsView()
                    )
                ),
                (
                    title: "About",
                    icon: "questionmark.circle",
                    view: AnyView(
                        AboutView()
                    )
                ),
            ]
        )
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
            NSApp.deactivate()
        }

    }

}

#Preview {
    SettingsView()
}
