//
//  ParaServerManager.swift
//  ParaKit
//
//  MCP server lifecycle management
//

import Foundation

/// Manages the Para MCP server lifecycle via launchd
public class ParaServerManager {

    private let mcpDirectory: String
    private let logFilePath: String
    private let tunnelLogFilePath: String
    private let tunnelFilePath: String

    // launchd service identifiers
    private let serverServiceLabel = "com.para.mcp-server"
    private let tunnelServiceLabel = "com.para.cloudflare-tunnel"

    private var launchAgentsDir: String {
        FileManager.default.homeDirectoryForCurrentUser.path + "/Library/LaunchAgents"
    }

    private var serverPlistPath: String {
        "\(launchAgentsDir)/\(serverServiceLabel).plist"
    }

    private var tunnelPlistPath: String {
        "\(launchAgentsDir)/\(tunnelServiceLabel).plist"
    }

    /// Initialize with MCP directory path
    public init() {
        // Try multiple locations to find para-mcp directory
        var candidates: [String] = []
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        // 1. Check environment variable (highest priority for user override)
        if let envPath = ProcessInfo.processInfo.environment["PARA_MCP_DIR"] {
            candidates.append(envPath)
        }

        // 2. Relative to executable (for development builds in .build directory)
        if let executablePath = Bundle.main.executablePath {
            let executableDir = URL(fileURLWithPath: executablePath).deletingLastPathComponent().path
            // Go up from .build/arm64-apple-macosx/release to project root
            candidates.append("\(executableDir)/../../../para-mcp")
        }

        // 3. Common development locations
        candidates.append("\(homeDir)/repos/other/para/para-mcp")
        candidates.append("\(homeDir)/repos/para/para-mcp")
        candidates.append("\(homeDir)/Developer/para/para-mcp")
        candidates.append("\(homeDir)/Projects/para/para-mcp")

        // 4. Relative to current directory
        candidates.append(FileManager.default.currentDirectoryPath + "/para-mcp")

        // 5. Standard install location (for future use)
        candidates.append("\(homeDir)/.para/mcp-server")

        // Find the first valid directory with venv
        var foundDirectory: String?
        for candidate in candidates {
            // Standardize the path to resolve any .. components
            let standardizedPath = URL(fileURLWithPath: candidate).standardized.path
            let venvPath = "\(standardizedPath)/venv"
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: venvPath, isDirectory: &isDirectory) && isDirectory.boolValue {
                foundDirectory = standardizedPath
                break
            }
        }

        // Use found directory or fallback to first candidate (also standardized)
        if let found = foundDirectory {
            self.mcpDirectory = found
        } else {
            self.mcpDirectory = URL(fileURLWithPath: candidates[0]).standardized.path
        }
        self.logFilePath = "\(mcpDirectory)/.server.log"
        self.tunnelLogFilePath = "\(mcpDirectory)/.tunnel.log"
        self.tunnelFilePath = "\(mcpDirectory)/.tunnel.url"
    }

    // MARK: - Setup

    /// Get the log file path
    public func getLogFilePath() -> String {
        return logFilePath
    }

    /// Check if Python environment is set up
    public func isEnvironmentSetup() -> Bool {
        let venvPath = "\(mcpDirectory)/venv"
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: venvPath, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    /// Set up Python virtual environment and install dependencies
    public func setupEnvironment() throws {
        // Check Python version
        guard let pythonPath = findPython() else {
            throw ParaServerError.pythonNotFound
        }

        let venvPath = "\(mcpDirectory)/venv"

        // Create venv if it doesn't exist
        if !isEnvironmentSetup() {
            let createVenv = Process()
            createVenv.executableURL = URL(fileURLWithPath: pythonPath)
            createVenv.arguments = ["-m", "venv", venvPath]
            try createVenv.run()
            createVenv.waitUntilExit()

            guard createVenv.terminationStatus == 0 else {
                throw ParaServerError.venvCreationFailed
            }
        }

        // Install dependencies
        let pip = Process()
        pip.executableURL = URL(fileURLWithPath: "\(venvPath)/bin/pip")
        pip.arguments = ["install", "-r", "\(mcpDirectory)/requirements.txt"]
        try pip.run()
        pip.waitUntilExit()

        guard pip.terminationStatus == 0 else {
            throw ParaServerError.dependencyInstallFailed
        }
    }

    // MARK: - Server Control

    /// Start the MCP server via launchd
    public func startServer(
        port: Int = 8000,
        background: Bool = false,
        tunnel: TunnelType = .none
    ) throws -> ServerStartResult {
        // Check if already running
        if let status = serverStatus(), status.isRunning {
            throw ParaServerError.serverAlreadyRunning(pid: status.pid!)
        }

        // Validate environment is set up
        guard isEnvironmentSetup() else {
            throw ParaServerError.environmentNotSetup
        }

        // Ensure plist is installed
        guard FileManager.default.fileExists(atPath: serverPlistPath) else {
            throw ParaServerError.launchdPlistNotInstalled
        }

        // Load the launchd service
        try runLaunchctl(["load", serverPlistPath])

        // Wait briefly for server to start
        usleep(500000) // 500ms

        // Start tunnel if requested
        var tunnelURL: String? = nil
        if tunnel != .none {
            tunnelURL = try startTunnel(type: tunnel)
            if let url = tunnelURL {
                try saveTunnelURL(url)
            }
        }

        let serverURL = "http://localhost:\(port)"
        let pid = getServicePID(serverServiceLabel) ?? 0

        return ServerStartResult(
            serverURL: serverURL,
            tunnelURL: tunnelURL,
            pid: pid,
            port: port
        )
    }

    /// Stop the MCP server via launchd
    public func stopServer() throws {
        let status = serverStatus()
        guard status?.isRunning == true else {
            throw ParaServerError.serverNotRunning
        }

        // Stop tunnel first
        stopTunnel()

        // Unload the launchd service
        try runLaunchctl(["unload", serverPlistPath])

        // Clean up tunnel URL file
        try? FileManager.default.removeItem(atPath: tunnelFilePath)
    }

    /// Get current server status by checking launchd
    public func serverStatus() -> ServerStatus? {
        let pid = getServicePID(serverServiceLabel)
        let isRunning = pid != nil && pid! > 0

        if !isRunning {
            return ServerStatus(isRunning: false, pid: nil, serverURL: nil, tunnelURL: nil, uptime: nil)
        }

        let serverURL = "http://localhost:8000"
        let tunnelURL = readTunnelURL() ?? getTunnelURLFromConfig()

        return ServerStatus(
            isRunning: true,
            pid: pid,
            serverURL: serverURL,
            tunnelURL: tunnelURL,
            uptime: nil
        )
    }

    // MARK: - Launchd Helpers

    /// Run a launchctl command
    private func runLaunchctl(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        // launchctl returns 0 on success, but also returns 0 for some "not running" cases
        // We check the output for actual errors
    }

    /// Get the PID of a launchd service
    private func getServicePID(_ label: String) -> Int32? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }

            // Parse launchctl list output: PID\tStatus\tLabel
            for line in output.components(separatedBy: "\n") {
                if line.contains(label) {
                    let parts = line.split(separator: "\t")
                    if parts.count >= 1, let pid = Int32(parts[0]), pid > 0 {
                        return pid
                    }
                }
            }
        } catch {}

        return nil
    }

    /// Check if tunnel service is running
    public func isTunnelRunning() -> Bool {
        let pid = getServicePID(tunnelServiceLabel)
        return pid != nil && pid! > 0
    }

    /// Get tunnel URL from cloudflared config
    private func getTunnelURLFromConfig() -> String? {
        let configPath = FileManager.default.homeDirectoryForCurrentUser.path + "/.cloudflared/config.yml"
        guard let content = try? String(contentsOfFile: configPath) else { return nil }

        // Look for hostname: line
        for line in content.components(separatedBy: "\n") {
            if line.contains("hostname:") {
                let hostname = line.replacingOccurrences(of: "hostname:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "- "))
                if !hostname.isEmpty {
                    return "https://\(hostname)"
                }
            }
        }
        return nil
    }

    // MARK: - Tunnel Management

    /// Set up permanent Cloudflare tunnel
    public func setupTunnel() throws {
        let setupScript = "\(mcpDirectory)/scripts/setup-tunnel.sh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: setupScript)
        process.currentDirectoryURL = URL(fileURLWithPath: mcpDirectory)
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ParaServerError.tunnelSetupFailed
        }
    }

    /// Start Cloudflare tunnel via launchd
    private func startTunnel(type: TunnelType) throws -> String {
        switch type {
        case .quick:
            return try startQuickTunnel()
        case .permanent:
            return try startPermanentTunnel()
        case .none:
            return ""
        }
    }

    /// Start a quick Cloudflare tunnel (no setup required) - runs directly, not via launchd
    private func startQuickTunnel() throws -> String {
        // Find cloudflared
        guard let cloudflaredPath = findCloudflared() else {
            throw ParaServerError.cloudflaredNotFound
        }

        // Use a log file for tunnel output to avoid pipe buffer issues
        let tunnelLogPath = "\(mcpDirectory)/.tunnel.log"

        // Create/truncate log file
        FileManager.default.createFile(atPath: tunnelLogPath, contents: nil, attributes: nil)

        guard let logFileHandle = FileHandle(forWritingAtPath: tunnelLogPath) else {
            throw ParaServerError.tunnelSetupFailed
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: cloudflaredPath)
        process.arguments = ["tunnel", "--url", "http://localhost:8000"]

        // Redirect output to log file (keeps tunnel alive)
        process.standardError = logFileHandle
        process.standardOutput = FileHandle.nullDevice

        try process.run()

        // Save tunnel PID for cleanup (quick tunnels still use PID file)
        try saveTunnelPID(process.processIdentifier)

        // Wait for URL to appear in log file
        var tunnelURL: String? = nil
        let startTime = Date()
        let timeout: TimeInterval = 30

        while tunnelURL == nil && Date().timeIntervalSince(startTime) < timeout {
            usleep(500000) // 500ms between checks

            // Read log file
            if let content = try? String(contentsOfFile: tunnelLogPath, encoding: .utf8) {
                // Look for trycloudflare.com URL
                if let range = content.range(of: "https://[a-zA-Z0-9-]+\\.trycloudflare\\.com", options: .regularExpression) {
                    tunnelURL = String(content[range])
                }
            }
        }

        guard let url = tunnelURL else {
            process.terminate()
            throw ParaServerError.tunnelURLNotFound
        }

        return url
    }

    /// Start a permanent Cloudflare tunnel via launchd
    private func startPermanentTunnel() throws -> String {
        // Ensure plist is installed
        guard FileManager.default.fileExists(atPath: tunnelPlistPath) else {
            throw ParaServerError.launchdPlistNotInstalled
        }

        // Load the launchd service
        try runLaunchctl(["load", tunnelPlistPath])

        // Wait briefly for tunnel to connect
        usleep(2000000) // 2 seconds

        // Get URL from config
        guard let url = getTunnelURLFromConfig() else {
            throw ParaServerError.tunnelURLNotFound
        }

        return url
    }

    /// Stop the tunnel (via launchd for permanent, PID for quick)
    public func stopTunnel() {
        // Try launchd first (permanent tunnel)
        if isTunnelRunning() {
            try? runLaunchctl(["unload", tunnelPlistPath])
        }

        // Also check for quick tunnel PID
        stopQuickTunnelProcess()
    }

    private func findCloudflared() -> String? {
        let candidates = ["/usr/local/bin/cloudflared", "/opt/homebrew/bin/cloudflared"]

        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate) {
                return candidate
            }
        }

        // Try which
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["cloudflared"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
                    return path
                }
            }
        } catch {}

        return nil
    }

    private var tunnelPidFilePath: String {
        return "\(mcpDirectory)/.tunnel.pid"
    }

    private func saveTunnelPID(_ pid: Int32) throws {
        try String(pid).write(toFile: tunnelPidFilePath, atomically: true, encoding: .utf8)
    }

    private func readTunnelPID() -> Int32? {
        guard let content = try? String(contentsOfFile: tunnelPidFilePath) else { return nil }
        return Int32(content.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Stop quick tunnel by PID
    private func stopQuickTunnelProcess() {
        guard let pid = readTunnelPID() else { return }

        // Send SIGTERM
        kill(pid, SIGTERM)

        // Wait briefly for graceful shutdown
        var attempts = 0
        while attempts < 10 {
            if kill(pid, 0) != 0 {
                break
            }
            usleep(100000) // 100ms
            attempts += 1
        }

        // Force kill if still running
        if kill(pid, 0) == 0 {
            kill(pid, SIGKILL)
        }

        // Clean up PID file
        try? FileManager.default.removeItem(atPath: tunnelPidFilePath)
    }

    // MARK: - Helper Methods

    private func findPython() -> String? {
        let pythonCandidates = ["python3.10", "python3.11", "python3.12", "python3"]

        for candidate in pythonCandidates {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            process.arguments = [candidate]

            let pipe = Pipe()
            process.standardOutput = pipe

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                        return path
                    }
                }
            } catch {
                continue
            }
        }

        return nil
    }

    private func saveTunnelURL(_ url: String) throws {
        try url.write(toFile: tunnelFilePath, atomically: true, encoding: .utf8)
    }

    private func readTunnelURL() -> String? {
        guard let content = try? String(contentsOfFile: tunnelFilePath) else { return nil }
        let url = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return url.isEmpty ? nil : url
    }
}

// MARK: - Supporting Types

public enum TunnelType {
    case none
    case quick       // cloudflared tunnel --url
    case permanent   // configured tunnel
}

public struct ServerStartResult {
    public let serverURL: String
    public let tunnelURL: String?
    public let pid: Int32
    public let port: Int
}

public struct ServerStatus {
    public let isRunning: Bool
    public let pid: Int32?
    public let serverURL: String?
    public let tunnelURL: String?
    public let uptime: TimeInterval?
}

public enum ParaServerError: Error, LocalizedError {
    case pythonNotFound
    case venvCreationFailed
    case dependencyInstallFailed
    case environmentNotSetup
    case serverAlreadyRunning(pid: Int32)
    case serverNotRunning
    case tunnelSetupFailed
    case cloudflaredNotFound
    case tunnelURLNotFound
    case launchdPlistNotInstalled

    public var errorDescription: String? {
        switch self {
        case .pythonNotFound:
            return "Python 3.10+ not found. Please install Python."
        case .venvCreationFailed:
            return "Failed to create Python virtual environment."
        case .dependencyInstallFailed:
            return "Failed to install Python dependencies."
        case .environmentNotSetup:
            return "MCP server environment not set up. Run 'para server-setup' first."
        case .serverAlreadyRunning(let pid):
            return "MCP server is already running (PID: \(pid))."
        case .serverNotRunning:
            return "MCP server is not running."
        case .tunnelSetupFailed:
            return "Failed to set up Cloudflare tunnel."
        case .cloudflaredNotFound:
            return "cloudflared not found. Install with: brew install cloudflared"
        case .tunnelURLNotFound:
            return "Failed to get tunnel URL from cloudflared. Check your network connection."
        case .launchdPlistNotInstalled:
            return "LaunchAgent plist not installed. Run 'para server-setup' first."
        }
    }
}
