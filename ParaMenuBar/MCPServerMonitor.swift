//
//  MCPServerMonitor.swift
//  ParaMenuBar
//
//  Monitors MCP server status and triggers UI updates.
//

import Foundation
import ParaKit

class MCPServerMonitor: ObservableObject {
    private let paraManager: ParaManager
    private var pollTimer: Timer?
    private let pollInterval: TimeInterval = 2.5 // Poll every 2.5 seconds

    // Track previous state to detect changes
    private var lastServerRunning: Bool = false
    private var lastServerURL: String?
    private var lastTunnelURL: String?

    init(paraManager: ParaManager) {
        self.paraManager = paraManager
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    func startMonitoring() {
        // Perform initial status check
        refreshStatus()

        // Schedule periodic polling
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.refreshStatus()
        }
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func refreshStatus() {
        // Refresh server status from ParaManager
        paraManager.refreshServerStatus()

        // Check if status changed (for potential future use, e.g., notifications)
        let statusChanged = (lastServerRunning != paraManager.mcpServerRunning) ||
                           (lastServerURL != paraManager.mcpServerURL) ||
                           (lastTunnelURL != paraManager.mcpTunnelURL)

        if statusChanged {
            // Update tracked state
            lastServerRunning = paraManager.mcpServerRunning
            lastServerURL = paraManager.mcpServerURL
            lastTunnelURL = paraManager.mcpTunnelURL

            // The @Published properties in ParaManager will automatically trigger menu rebuild
            // through Combine's observation mechanism
        }
    }
}
