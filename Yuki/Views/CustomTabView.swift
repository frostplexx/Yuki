//
//  CustomTabView.swift
//  Yuki
//
//  Created by Daniel Inama on 7/3/25.
//
import SwiftUI

public struct CustomTabView: View {
    private let titles: [String]
    private let icons: [String]
    private let tabViews: [AnyView]
    @State private var selection = 0
    @State private var indexHovered = -1
    
    public init(content: [(title: String, icon: String, view: AnyView)]) {
        self.titles = content.map{ $0.title }
        self.icons = content.map{ $0.icon }
        self.tabViews = content.map{ $0.view }
    }
    
    public var tabBar: some View {
        HStack {
            Spacer()
            ForEach(0..<titles.count, id: \.self) { index in
                VStack {
                    Image(systemName: self.icons[index])
                        .font(.system(size: 18, weight: .medium))
                    Text(self.titles[index])
                        .font(.system(size: 12, weight: .medium))
                }
                .frame(height: 10)
                .padding(.vertical, 17)
                .padding(.horizontal, 10)
                .background(
                    ZStack {
                        // Base background for selection
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.gray.opacity(self.selection == index ? 0.3 : 0))
                        
                        // Hover glow for non-selected items
                        if self.indexHovered == index || self.selection == index {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                                .blur(radius: 0.5)
                            
                            // Inner glow
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                        }
                    }
                )
                .frame(height: 60)
                .padding(.horizontal, 0)
                // Outer glow for hover state (non-selected items only)
                .shadow(color: self.indexHovered == index && self.selection != index ?
                        Color.white.opacity(0.4) : Color.clear,
                        radius: 3, x: 0, y: 0)
                // Inner shadow for hover state (non-selected items only)
                .shadow(color: self.indexHovered == index && self.selection != index ?
                        Color.white.opacity(0.2) : Color.clear,
                        radius: 1, x: 0, y: 0)
                .foregroundColor(
                    self.selection == index ? Color.white :
                    (self.indexHovered == index ? Color.white.opacity(0.9) : Color.gray)
                )
                .onHover(perform: { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if hovering {
                            indexHovered = index
                        } else {
                            indexHovered = -1
                        }
                    }
                })
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.selection = index
                    }
                }
            }
            Spacer()
        }
        .padding(0)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            tabBar
                .padding(.top, -12)
            tabViews[selection]
                .padding(0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(0)
    }
}

#Preview {
    CustomTabView(content: [
        ("General", "gearshape.fill", AnyView(Text("General Settings"))),
        ("Tiling", "square.grid.2x2", AnyView(Text("Tiling Settings"))),
        ("Workspaces", "rectangle.3.group", AnyView(Text("Workspace Settings")))
    ])
}
