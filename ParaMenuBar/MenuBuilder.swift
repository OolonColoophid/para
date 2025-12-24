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

        // Resources (if exists)
        if paraManager.hasResources {
            menu.addItem(NSMenuItem.separator())
            let resourcesItem = NSMenuItem(title: "Resources", action: #selector(MenuActions.revealResources), keyEquivalent: "")
            resourcesItem.image = NSImage(systemSymbolName: "books.vertical.fill", accessibilityDescription: nil)
            resourcesItem.target = MenuActions.shared
            resourcesItem.representedObject = paraManager
            menu.addItem(resourcesItem)
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
        newAreaItem.image = NSImage(systemSymbolName: "hexagon.badge.plus", accessibilityDescription: nil)
        newAreaItem.target = MenuActions.shared
        newAreaItem.representedObject = paraManager
        menu.addItem(newAreaItem)

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

        // Open Journal
        let openItem = NSMenuItem(title: "Open Journal", action: #selector(MenuActions.openJournal), keyEquivalent: "")
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
        Version 0.1

        A menu bar app for managing your PARA system (Projects, Areas, Resources, Archives).

        Use Settings to configure your PARA directories.

        © 2025 Ian Hocking. Open source software.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
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
