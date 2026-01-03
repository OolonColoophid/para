//
//  MenuBuilder.swift
//  ParaMenuBar
//
//  Builds dynamic menus from PARA data.
//

import AppKit
import ParaKit

struct MenuBuilder {

    /// Build the complete menu
    static func buildMenu(paraManager: ParaManager) -> NSMenu {
        let menu = NSMenu()

        // MCP Server Status section
        addServerStatusSection(to: menu, paraManager: paraManager)

        // Projects section
        if !paraManager.projects.isEmpty {
            let projectsSubmenu = buildSubmenu(
                title: "Projects",
                symbolName: "folder.fill",
                items: paraManager.projects,
                paraManager: paraManager
            )
            menu.addItem(projectsSubmenu)
        } else {
            let item = NSMenuItem(title: "Projects (none)", action: nil, keyEquivalent: "")
            item.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
            item.isEnabled = false
            menu.addItem(item)
        }

        // Areas section
        if !paraManager.areas.isEmpty {
            let areasSubmenu = buildSubmenu(
                title: "Areas",
                symbolName: "hexagon.fill",
                items: paraManager.areas,
                paraManager: paraManager
            )
            menu.addItem(areasSubmenu)
        } else {
            let item = NSMenuItem(title: "Areas (none)", action: nil, keyEquivalent: "")
            item.image = NSImage(systemSymbolName: "hexagon", accessibilityDescription: nil)
            item.isEnabled = false
            menu.addItem(item)
        }

        // Resources section
        if !paraManager.resources.isEmpty {
            let resourcesSubmenu = buildSubmenu(
                title: "Resources",
                symbolName: "books.vertical.fill",
                items: paraManager.resources,
                paraManager: paraManager
            )
            menu.addItem(resourcesSubmenu)
        } else if paraManager.hasResources {
            // Resources folder exists but no items
            let item = NSMenuItem(title: "Resources (none)", action: nil, keyEquivalent: "")
            item.image = NSImage(systemSymbolName: "books.vertical", accessibilityDescription: nil)
            item.isEnabled = false
            menu.addItem(item)
        }

        // Archive (if exists)
        if paraManager.hasArchive {
            let archiveItem = NSMenuItem(title: "Archive", action: #selector(MenuActions.revealArchive), keyEquivalent: "")
            archiveItem.image = NSImage(systemSymbolName: "archivebox.fill", accessibilityDescription: nil)
            archiveItem.target = MenuActions.shared
            archiveItem.representedObject = paraManager
            menu.addItem(archiveItem)
        }

        // Separator
        menu.addItem(NSMenuItem.separator())

        // New Project
        let newProjectItem = NSMenuItem(title: "New Project...", action: #selector(MenuActions.newProject), keyEquivalent: "n")
        newProjectItem.image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: nil)
        newProjectItem.target = MenuActions.shared
        newProjectItem.representedObject = paraManager
        menu.addItem(newProjectItem)

        // New Area
        let newAreaItem = NSMenuItem(title: "New Area...", action: #selector(MenuActions.newArea), keyEquivalent: "")
        newAreaItem.image = NSImage(systemSymbolName: "hexagon.fill", accessibilityDescription: nil)
        newAreaItem.target = MenuActions.shared
        newAreaItem.representedObject = paraManager
        menu.addItem(newAreaItem)

        // New Resource
        let newResourceItem = NSMenuItem(title: "New Resource...", action: #selector(MenuActions.newResource), keyEquivalent: "")
        newResourceItem.image = NSImage(systemSymbolName: "books.vertical.fill", accessibilityDescription: nil)
        newResourceItem.target = MenuActions.shared
        newResourceItem.representedObject = paraManager
        menu.addItem(newResourceItem)

        // Separator
        menu.addItem(NSMenuItem.separator())

        // About
        let aboutItem = NSMenuItem(title: "About", action: #selector(MenuActions.showAbout), keyEquivalent: "")
        aboutItem.target = MenuActions.shared
        menu.addItem(aboutItem)

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(MenuActions.showSettings), keyEquivalent: ",")
        settingsItem.target = MenuActions.shared
        settingsItem.representedObject = paraManager
        menu.addItem(settingsItem)

        // Refresh
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(MenuActions.refresh), keyEquivalent: "r")
        refreshItem.target = MenuActions.shared
        refreshItem.representedObject = paraManager
        menu.addItem(refreshItem)

        // Quit
        let quitItem = NSMenuItem(title: "Quit Para", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        return menu
    }

    /// Build a submenu for a list of items
    private static func buildSubmenu(title: String, symbolName: String, items: [ParaItem], paraManager: ParaManager) -> NSMenuItem {
        let submenu = NSMenu()

        for item in items {
            let itemSubmenu = buildItemSubmenu(item: item, paraManager: paraManager)
            submenu.addItem(itemSubmenu)
        }

        let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        menuItem.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        menuItem.submenu = submenu
        return menuItem
    }

    /// Build a submenu for a single item with actions
    private static func buildItemSubmenu(item: ParaItem, paraManager: ParaManager) -> NSMenuItem {
        let itemMenu = NSMenu()

        // Description (if available) - shown at top as disabled item
        if let description = item.description {
            let descItem = NSMenuItem(title: description, action: nil, keyEquivalent: "")
            descItem.isEnabled = false
            itemMenu.addItem(descItem)
            itemMenu.addItem(NSMenuItem.separator())
        }

        // Open main file (Journal for projects/areas, Readme for resources)
        let openTitle = item.type == .resource ? "Open Readme" : "Open Journal"
        let openItem = NSMenuItem(title: openTitle, action: #selector(MenuActions.openJournal), keyEquivalent: "")
        openItem.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
        openItem.target = MenuActions.shared
        openItem.representedObject = (paraManager, item)
        itemMenu.addItem(openItem)

        // Reveal in Finder
        let revealItem = NSMenuItem(title: "Reveal in Finder", action: #selector(MenuActions.revealInFinder), keyEquivalent: "")
        revealItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        revealItem.target = MenuActions.shared
        revealItem.representedObject = (paraManager, item)
        itemMenu.addItem(revealItem)

        // Open in Terminal
        let terminalItem = NSMenuItem(title: "Open in Terminal", action: #selector(MenuActions.openInTerminal), keyEquivalent: "")
        terminalItem.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: nil)
        terminalItem.target = MenuActions.shared
        terminalItem.representedObject = (paraManager, item)
        itemMenu.addItem(terminalItem)

        // Separator
        itemMenu.addItem(NSMenuItem.separator())

        // Archive
        let archiveItem = NSMenuItem(title: "Archive", action: #selector(MenuActions.archiveItem), keyEquivalent: "")
        archiveItem.image = NSImage(systemSymbolName: "archivebox", accessibilityDescription: nil)
        archiveItem.target = MenuActions.shared
        archiveItem.representedObject = (paraManager, item)
        itemMenu.addItem(archiveItem)

        // Delete
        let deleteItem = NSMenuItem(title: "Delete...", action: #selector(MenuActions.deleteItem), keyEquivalent: "")
        deleteItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        deleteItem.target = MenuActions.shared
        deleteItem.representedObject = (paraManager, item)
        itemMenu.addItem(deleteItem)

        // Create menu item with submenu - just use the name
        let menuItem = NSMenuItem(title: item.name, action: nil, keyEquivalent: "")
        menuItem.submenu = itemMenu

        return menuItem
    }

    /// Add MCP server status section at top of menu
    private static func addServerStatusSection(to menu: NSMenu, paraManager: ParaManager) {
        // Server status indicator
        if paraManager.mcpServerRunning {
            // Running: green circle
            let statusItem = NSMenuItem(title: "MCP Server Running", action: nil, keyEquivalent: "")
            statusItem.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)
            if let image = statusItem.image {
                let greenImage = image.withSymbolConfiguration(
                    NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)
                        .applying(NSImage.SymbolConfiguration(paletteColors: [.systemGreen]))
                )
                statusItem.image = greenImage
            }
            statusItem.isEnabled = false
            menu.addItem(statusItem)

            // Local server URL
            if let serverURL = paraManager.mcpServerURL {
                let localItem = NSMenuItem(title: "   Local: \(serverURL)", action: #selector(MenuActions.copyServerURL), keyEquivalent: "")
                localItem.target = MenuActions.shared
                localItem.representedObject = serverURL
                menu.addItem(localItem)
            }

            // Tunnel URL (if available)
            if let tunnelURL = paraManager.mcpTunnelURL {
                let tunnelItem = NSMenuItem(title: "   Tunnel: \(tunnelURL)", action: #selector(MenuActions.copyTunnelURL), keyEquivalent: "")
                tunnelItem.target = MenuActions.shared
                tunnelItem.representedObject = tunnelURL
                menu.addItem(tunnelItem)
            }
        } else {
            // Stopped: gray circle
            let statusItem = NSMenuItem(title: "MCP Server Stopped", action: nil, keyEquivalent: "")
            statusItem.image = NSImage(systemSymbolName: "circle", accessibilityDescription: nil)
            if let image = statusItem.image {
                let grayImage = image.withSymbolConfiguration(
                    NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)
                        .applying(NSImage.SymbolConfiguration(paletteColors: [.systemGray]))
                )
                statusItem.image = grayImage
            }
            statusItem.isEnabled = false
            menu.addItem(statusItem)

            // Start Server button
            let startItem = NSMenuItem(title: "Start Server", action: #selector(MenuActions.startServer), keyEquivalent: "")
            startItem.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
            startItem.target = MenuActions.shared
            startItem.representedObject = paraManager
            menu.addItem(startItem)

            // Start Server with Tunnel button
            let startTunnelItem = NSMenuItem(title: "Start Server with Tunnel", action: #selector(MenuActions.startServerWithTunnel), keyEquivalent: "")
            startTunnelItem.image = NSImage(systemSymbolName: "network", accessibilityDescription: nil)
            startTunnelItem.target = MenuActions.shared
            startTunnelItem.representedObject = paraManager
            menu.addItem(startTunnelItem)
        }

        // Server control actions (when running)
        if paraManager.mcpServerRunning {
            // Stop Server button
            let stopItem = NSMenuItem(title: "Stop Server", action: #selector(MenuActions.stopServer), keyEquivalent: "")
            stopItem.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: nil)
            stopItem.target = MenuActions.shared
            stopItem.representedObject = paraManager
            menu.addItem(stopItem)

            // View Logs button
            let logsItem = NSMenuItem(title: "View Logs", action: #selector(MenuActions.viewServerLogs), keyEquivalent: "")
            logsItem.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
            logsItem.target = MenuActions.shared
            logsItem.representedObject = paraManager
            menu.addItem(logsItem)
        }

        // Separator after server status
        menu.addItem(NSMenuItem.separator())
    }
}

/// Actions for menu items
class MenuActions: NSObject {
    static let shared = MenuActions()

    @objc func openJournal(_ sender: NSMenuItem) {
        guard let (paraManager, item) = sender.representedObject as? (ParaManager, ParaItem) else { return }
        paraManager.openJournal(item)
    }

    @objc func revealInFinder(_ sender: NSMenuItem) {
        guard let (paraManager, item) = sender.representedObject as? (ParaManager, ParaItem) else { return }
        paraManager.revealInFinder(item)
    }

    @objc func openInTerminal(_ sender: NSMenuItem) {
        guard let (paraManager, item) = sender.representedObject as? (ParaManager, ParaItem) else { return }
        paraManager.openInTerminal(item)
    }

    @objc func archiveItem(_ sender: NSMenuItem) {
        guard let (paraManager, item) = sender.representedObject as? (ParaManager, ParaItem) else { return }

        // Confirm archive
        let alert = NSAlert()
        alert.messageText = "Archive \(item.name)?"
        alert.informativeText = "This will move \(item.name) to the archive directory."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Archive")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try paraManager.archiveItem(item)
            } catch {
                showError("Failed to archive \(item.name): \(error.localizedDescription)")
            }
        }
    }

    @objc func deleteItem(_ sender: NSMenuItem) {
        guard let (paraManager, item) = sender.representedObject as? (ParaManager, ParaItem) else { return }

        // Confirm deletion
        let alert = NSAlert()
        alert.messageText = "Delete \(item.name)?"
        alert.informativeText = "This will permanently delete \(item.name) and all its contents. This action cannot be undone."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try paraManager.deleteItem(item)
            } catch {
                showError("Failed to delete \(item.name): \(error.localizedDescription)")
            }
        }
    }

    @objc func revealResources(_ sender: NSMenuItem) {
        guard let paraManager = sender.representedObject as? ParaManager else { return }
        paraManager.revealPath(ParaEnvironment.resourcesPath)
    }

    @objc func revealArchive(_ sender: NSMenuItem) {
        guard let paraManager = sender.representedObject as? ParaManager else { return }
        paraManager.revealPath(ParaEnvironment.archivePath)
    }

    @objc func refresh(_ sender: NSMenuItem) {
        guard let paraManager = sender.representedObject as? ParaManager else { return }
        paraManager.refresh()
    }

    @objc func newProject(_ sender: NSMenuItem) {
        guard let paraManager = sender.representedObject as? ParaManager else { return }
        NewItemWindowController.shared.showNewItem(type: .project, paraManager: paraManager)
    }

    @objc func newArea(_ sender: NSMenuItem) {
        guard let paraManager = sender.representedObject as? ParaManager else { return }
        NewItemWindowController.shared.showNewItem(type: .area, paraManager: paraManager)
    }

    @objc func newResource(_ sender: NSMenuItem) {
        guard let paraManager = sender.representedObject as? ParaManager else { return }
        NewItemWindowController.shared.showNewItem(type: .resource, paraManager: paraManager)
    }

    @objc func showSettings(_ sender: NSMenuItem) {
        // Store paraManager for refresh after settings close
        if let paraManager = sender.representedObject as? ParaManager {
            // Observe settings changes to refresh
            NotificationCenter.default.addObserver(
                forName: .paraSettingsChanged,
                object: nil,
                queue: .main
            ) { [weak paraManager] _ in
                paraManager?.refresh()
            }
        }
        SettingsWindowController.shared.showSettings()
    }

    @objc func showAbout(_ sender: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = "Para"
        alert.informativeText = """
        \(ParaVersion.displayString)
        Built: \(ParaVersion.buildTimestamp)

        A menu bar app for managing your PARA system (Projects, Areas, Resources, Archives).

        Use Settings to configure your PARA directories.

        © 2025 Ian Hocking. Open source software.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func copyServerURL(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? String else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url, forType: .string)
    }

    @objc func copyTunnelURL(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? String else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url, forType: .string)
    }

    @objc func startServer(_ sender: NSMenuItem) {
        guard let paraManager = sender.representedObject as? ParaManager else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            let serverManager = ParaServerManager()
            do {
                _ = try serverManager.startServer(port: 8000, background: true, tunnel: .none)
                DispatchQueue.main.async {
                    paraManager.refreshServerStatus()
                }
            } catch {
                DispatchQueue.main.async {
                    self.showError("Failed to start server: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc func startServerWithTunnel(_ sender: NSMenuItem) {
        guard let paraManager = sender.representedObject as? ParaManager else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            let serverManager = ParaServerManager()
            do {
                _ = try serverManager.startServer(port: 8000, background: true, tunnel: .quick)
                DispatchQueue.main.async {
                    paraManager.refreshServerStatus()
                }
            } catch {
                DispatchQueue.main.async {
                    self.showError("Failed to start server: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc func stopServer(_ sender: NSMenuItem) {
        guard let paraManager = sender.representedObject as? ParaManager else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            let serverManager = ParaServerManager()
            do {
                try serverManager.stopServer()
                DispatchQueue.main.async {
                    paraManager.refreshServerStatus()
                }
            } catch {
                DispatchQueue.main.async {
                    self.showError("Failed to stop server: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc func viewServerLogs(_ sender: NSMenuItem) {
        let serverManager = ParaServerManager()
        let logPath = serverManager.getLogFilePath()

        // Open log file in default text editor
        if FileManager.default.fileExists(atPath: logPath) {
            NSWorkspace.shared.open(URL(fileURLWithPath: logPath))
        } else {
            showError("Log file not found. The server may not have been started yet.")
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
