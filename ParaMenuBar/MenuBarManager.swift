//
//  MenuBarManager.swift
//  ParaMenuBar
//
//  Manages the menu bar status item and menu.
//

import AppKit
import Combine
import ParaKit

class MenuBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    private let paraManager: ParaManager
    private var cancellables = Set<AnyCancellable>()

    init(paraManager: ParaManager) {
        self.paraManager = paraManager
        setupMenuBar()
        observeChanges()
    }

    private func setupMenuBar() {
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // Use SF Symbol for menu bar icon
            if let image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: "Para") {
                image.isTemplate = true  // Allow automatic dark mode adaptation
                button.image = image
            } else {
                // Fallback to text if symbol not available
                button.title = "P"
            }
        }

        // Build and attach menu
        updateMenu()
    }

    private func observeChanges() {
        // Rebuild menu when ParaManager data changes
        paraManager.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateMenu()
                }
            }
            .store(in: &cancellables)
    }

    private func updateMenu() {
        statusItem?.menu = MenuBuilder.buildMenu(paraManager: paraManager)
    }
}
