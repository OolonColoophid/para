//
//  ParaServerManager.swift
//  ParaKit
//
//  MCP server lifecycle management
//

import Foundation

/// Manages the Para MCP server lifecycle
public class ParaServerManager {

    private let mcpDirectory: String
    private let pidFilePath: String
    private let logFilePath: String
    private let tunnelFilePath: String

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
            let venvPath = "\(candidate)/venv"
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: venvPath, isDirectory: &isDirectory) && isDirectory.boolValue {
                foundDirectory = candidate
                break
            }
        }

        // Use found directory or fallback to first candidate
        self.mcpDirectory = foundDirectory ?? candidates[0]
        self.pidFilePath = "\(mcpDirectory)/.server.pid"
        self.logFilePath = "\(mcpDirectory)/.server.log"
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

    /// Start the MCP server
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

        // Start Python server process
        let process = try runPythonServer(port: port, background: background)

        // Save PID
        try savePID(process.processIdentifier)

        // Start tunnel if requested
        var tunnelURL: String? = nil
        if tunnel != .none {
            tunnelURL = try startTunnel(type: tunnel)
            // Save tunnel URL to file
            if let url = tunnelURL {
                try saveTunnelURL(url)
            }
        } else {
            // Clear any existing tunnel URL file
            try? FileManager.default.removeItem(atPath: tunnelFilePath)
        }

        let serverURL = "http://localhost:\(port)"

        return ServerStartResult(
            serverURL: serverURL,
            tunnelURL: tunnelURL,
            pid: process.processIdentifier,
            port: port
        )
    }

    /// Stop the MCP server
    public func stopServer() throws {
        guard let pid = readPID() else {
            throw ParaServerError.serverNotRunning
        }

        // Stop tunnel process first
        stopTunnelProcess()

        // Send SIGTERM for graceful shutdown
        kill(pid, SIGTERM)

        // Wait up to 5 seconds for process to exit
        var attempts = 0
        while attempts < 50 {
            if kill(pid, 0) != 0 {
                // Process no longer exists
                break
            }
            usleep(100000) // 100ms
            attempts += 1
        }

        // If still running, force kill
        if kill(pid, 0) == 0 {
            kill(pid, SIGKILL)
        }

        // Clean up PID file and tunnel URL file
        try? FileManager.default.removeItem(atPath: pidFilePath)
        try? FileManager.default.removeItem(atPath: tunnelFilePath)
    }

    /// Get current server status
    public func serverStatus() -> ServerStatus? {
        guard let pid = readPID() else {
            return ServerStatus(isRunning: false, pid: nil, serverURL: nil, tunnelURL: nil, uptime: nil)
        }

        // Check if process is actually running
        let isRunning = kill(pid, 0) == 0

        if !isRunning {
            // Clean up stale PID file
            try? FileManager.default.removeItem(atPath: pidFilePath)
            return ServerStatus(isRunning: false, pid: nil, serverURL: nil, tunnelURL: nil, uptime: nil)
        }

        // Try to read port from environment or use default
        let serverURL = "http://localhost:8000"

        // Read tunnel URL if it exists
        let tunnelURL = readTunnelURL()

        return ServerStatus(
            isRunning: true,
            pid: pid,
            serverURL: serverURL,
            tunnelURL: tunnelURL,
            uptime: nil // TODO: Calculate uptime from process start time
        )
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

    /// Start Cloudflare tunnel
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

    /// Start a quick Cloudflare tunnel (no setup required)
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

        // Save tunnel PID for cleanup
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

    /// Start a permanent Cloudflare tunnel (requires setup)
    private func startPermanentTunnel() throws -> String {
        let script = "\(mcpDirectory)/scripts/start-tunnel.sh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: script)
        process.currentDirectoryURL = URL(fileURLWithPath: mcpDirectory)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ParaServerError.tunnelSetupFailed
        }

        // Read configured tunnel URL from config or output
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8),
           let range = output.range(of: "https://[a-zA-Z0-9.-]+", options: .regularExpression) {
            return String(output[range])
        }

        throw ParaServerError.tunnelURLNotFound
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

    private func stopTunnelProcess() {
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

    // MARK: - Process Management

    private func runPythonServer(port: Int, background: Bool) throws -> Process {
        let pythonPath = "\(mcpDirectory)/venv/bin/python"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = ["-m", "src.server"]
        process.currentDirectoryURL = URL(fileURLWithPath: mcpDirectory)

        // Set environment variables
        var env = ProcessInfo.processInfo.environment
        env["PARA_HOME"] = ParaEnvironment.paraHome
        env["PARA_ARCHIVE"] = ParaEnvironment.archivePath
        env["USE_HTTP"] = "true"
        env["PORT"] = String(port)
        process.environment = env

        if background {
            // Create or truncate log file
            FileManager.default.createFile(atPath: logFilePath, contents: nil, attributes: nil)

            // Redirect output to log file
            if let logFileHandle = FileHandle(forWritingAtPath: logFilePath) {
                process.standardOutput = logFileHandle
                process.standardError = logFileHandle
            }
        }

        try process.run()

        return process
    }

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

    private func savePID(_ pid: Int32) throws {
        try String(pid).write(toFile: pidFilePath, atomically: true, encoding: .utf8)
    }

    private func readPID() -> Int32? {
        guard let content = try? String(contentsOfFile: pidFilePath) else { return nil }
        return Int32(content.trimmingCharacters(in: .whitespacesAndNewlines))
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
        }
    }
}
