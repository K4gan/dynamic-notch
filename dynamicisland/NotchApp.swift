//
//  NotchApp.swift
//  DynamicNotch
//
//  Created for Dynamic Notch utility app
//

import SwiftUI
import AppKit

@main
struct NotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NotchWindow?
    private var viewModel: NotchViewModel?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Create view model
        let vm = NotchViewModel()
        self.viewModel = vm
        
        // Create and configure window
        let notchWindow = NotchWindow(viewModel: vm)
        vm.setWindow(notchWindow)
        
        self.window = notchWindow
        
        // Show window
        notchWindow.makeKeyAndOrderFront(nil)
        
        // Make sure window stays on top
        notchWindow.orderFrontRegardless()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
        window?.close()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Prevent app from showing when clicking dock icon (since it's hidden anyway)
        return false
    }
}

