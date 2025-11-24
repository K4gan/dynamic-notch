//
//  NotchWindow.swift
//  DynamicNotch
//
//  Created for Dynamic Notch utility app
//

import AppKit
import SwiftUI

class NotchWindow: NSPanel {
    private var contentViewHost: NSHostingController<ContentView>?
    private var viewModel: NotchViewModel
    
    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        
        // Create panel with specific style
        super.init(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupContentView()
    }
    
    private func setupWindow() {
        // Configure panel properties
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isFloatingPanel = true
        self.becomesKeyOnlyIfNeeded = true
        self.hidesOnDeactivate = false
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        
        // Position at top center of screen
        updateWindowPosition()
        
        // Set initial collapsed state
        setExpanded(false, animated: false)
    }
    
    private func setupContentView() {
        let contentView = ContentView(viewModel: viewModel)
        contentViewHost = NSHostingController(rootView: contentView)
        
        guard let hostingView = contentViewHost?.view else { return }
        
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        self.contentView = hostingView
    }
    
    func updateWindowPosition() {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.frame
        let screenWidth = screenFrame.width
        let screenHeight = screenFrame.height
        
        // Position window directly below notch, completely hidden
        // NSScreen.frame uses bottom-left origin, so top is origin.y + height
        let notchHeight: CGFloat = 30 // Approximate notch height
        let collapsedWidth: CGFloat = 10 // Very small for mouse tracking
        let collapsedHeight: CGFloat = 10 // Very small, hidden below notch
        
        // Center horizontally on notch
        let notchX = screenFrame.origin.x + (screenWidth - collapsedWidth) / 2
        
        // Position just below the notch
        let frame = NSRect(
            x: notchX,
            y: screenFrame.origin.y + screenHeight - notchHeight - collapsedHeight,
            width: collapsedWidth,
            height: collapsedHeight
        )
        
        self.setFrame(frame, display: true)
    }
    
    func setExpanded(_ expanded: Bool, animated: Bool = true) {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.frame
        let screenWidth = screenFrame.width
        let screenHeight = screenFrame.height
        
        // Window expands in all directions from notch bottom
        // Cover upper center portion of screen (smaller width)
        let collapsedWidth: CGFloat = 10
        let collapsedHeight: CGFloat = 10
        let expandedWidth: CGFloat = min(screenWidth * 0.45, 600) // Cover 45% of screen width or max 600px
        let expandedHeight: CGFloat = min(screenHeight * 0.6, 400) // Max 60% of screen height or 400px
        
        let targetWidth = expanded ? expandedWidth : collapsedWidth
        let targetHeight = expanded ? expandedHeight : collapsedHeight
        
        // Position: start from notch bottom, expand in all directions
        let notchHeight: CGFloat = 30
        let notchBottomY = screenFrame.origin.y + screenHeight - notchHeight
        
        // Center horizontally on notch, expand upward and downward
        let notchX = screenFrame.origin.x + (screenWidth - targetWidth) / 2
        
        // Expand upward (into notch area) and downward
        let newFrame = NSRect(
            x: notchX,
            y: notchBottomY - (targetHeight / 2), // Center on notch bottom, expand both ways
            width: targetWidth,
            height: targetHeight
        )
        
        if expanded {
            NSApp.activate(ignoringOtherApps: true)
            self.makeKeyAndOrderFront(nil)
            self.makeFirstResponder(self.contentView)
        }
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1) // Spring-like
                self.animator().setFrame(newFrame, display: true)
            }
        } else {
            self.setFrame(newFrame, display: true)
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        viewModel.handleMouseEnter()
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        viewModel.handleMouseExit()
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return false
    }
}

