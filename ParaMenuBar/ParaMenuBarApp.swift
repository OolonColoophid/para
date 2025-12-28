//
//  ParaMenuBarApp.swift
//  ParaMenuBar
//
//  Main entry point for the Para menu bar application.
//

import SwiftUI
import ParaKit

@main
struct ParaMenuBarApp: App {
    @StateObject private var paraManager: ParaManager
    @StateObject private var menuBarManager: MenuBarManager
    @StateObject private var fileWatcher: FileWatcher
    @StateObject private var mcpServerMonitor: MCPServerMonitor

    init() {
        // Create shared ParaManager instance
        let manager = ParaManager()

        // Initialize state objects
        _paraManager = StateObject(wrappedValue: manager)
        _menuBarManager = StateObject(wrappedValue: MenuBarManager(paraManager: manager))
        _fileWatcher = StateObject(wrappedValue: FileWatcher(paraManager: manager))
        _mcpServerMonitor = StateObject(wrappedValue: MCPServerMonitor(paraManager: manager))
    }

    var body: some Scene {
        // Settings scene is required but unused (menu bar app only)
        Settings {
            EmptyView()
        }
    }
}
