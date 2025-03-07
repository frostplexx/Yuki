//
//  MouseTrackingView.swift
//  Yuki
//
//  Created by Daniel Inama on 7/3/25.
//

import SwiftUI
import AppKit

// Mouse location publisher for precise hover tracking
class MouseLocation: ObservableObject {
    @Published var location: CGPoint = .zero
    
    static let shared = MouseLocation()
    
    private var trackingArea: NSTrackingArea?
    private var view: NSView?
    
    func startTracking(in newView: NSView, rect: CGRect) {
        // Stop existing tracking first
        stopTracking()
        
        // Store the view
        self.view = newView
        
        // Create a tracking area
        trackingArea = NSTrackingArea(
            rect: rect,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow],
            owner: newView,
            userInfo: nil
        )
        
        if let trackingArea = trackingArea {
            newView.addTrackingArea(trackingArea)
        }
    }
    
    func stopTracking() {
        if let oldTrackingArea = trackingArea, let view = view {
            view.removeTrackingArea(oldTrackingArea)
            trackingArea = nil
        }
    }
    
    func updateLocation(_ newLocation: CGPoint, in view: NSView) {
        // Convert point to view coordinates
        let localPoint = view.convert(newLocation, from: nil)
        DispatchQueue.main.async {
            self.location = localPoint
        }
    }
}

// NSViewRepresentable for tracking mouse movement
struct MouseTrackingViewRepresentable: NSViewRepresentable {
    var mouseLocation: MouseLocation
    
    func makeNSView(context: Context) -> NSView {
        let view = MouseTrackingNSView()
        view.mouseLocation = mouseLocation
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? MouseTrackingNSView {
            // Update tracking area when view changes size
            view.mouseLocation = mouseLocation
            mouseLocation.startTracking(in: view, rect: view.bounds)
        }
    }
    
    // NSView subclass that handles mouse events
    class MouseTrackingNSView: NSView {
        var mouseLocation: MouseLocation?
        
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            
            // Update tracking when the view updates
            if let mouseLocation = mouseLocation {
                mouseLocation.startTracking(in: self, rect: self.bounds)
            }
        }
        
        override func mouseMoved(with event: NSEvent) {
            if let mouseLocation = mouseLocation {
                mouseLocation.updateLocation(event.locationInWindow, in: self)
            }
        }
        
        override func mouseEntered(with event: NSEvent) {
            if let mouseLocation = mouseLocation {
                mouseLocation.updateLocation(event.locationInWindow, in: self)
            }
        }
        
        override func mouseExited(with event: NSEvent) {
            if let mouseLocation = mouseLocation {
                // Set to a position outside the view when mouse exits
                mouseLocation.updateLocation(CGPoint(x: -100, y: -100), in: self)
            }
        }
    }
}

// Wrapper view for easy use
struct MouseTrackingView<Content: View>: View {
    @StateObject private var mouseLocation = MouseLocation()
    let content: (CGPoint) -> Content
    
    init(@ViewBuilder content: @escaping (CGPoint) -> Content) {
        self.content = content
    }
    
    var body: some View {
        ZStack {
            MouseTrackingViewRepresentable(mouseLocation: mouseLocation)
                .frame(width: 0, height: 0)
            
            content(mouseLocation.location)
        }
    }
}
