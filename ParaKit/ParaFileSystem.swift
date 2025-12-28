//
//  ParaFileSystem.swift
//  ParaKit
//
//  File system operations for the PARA system.
//

import Foundation

/// File system operations for PARA items
public struct ParaFileSystem {

    // MARK: - Path Helpers

    /// Get the full path for a PARA folder
    public static func getParaFolderPath(type: String, name: String) -> String {
        let paraHome = ParaEnvironment.paraHome
        return "\(paraHome)/\(type)s/\(name)"
    }

    /// Get the archive path for an item
    public static func getArchiveFolderPath(name: String) -> String? {
        let archivePath = ParaEnvironment.paraArchive
        return "\(archivePath)/\(name)"
    }

    // MARK: - File Content

    /// Extract description from journal.org file
    public static func getItemDescription(type: String, name: String) -> String? {
        let folderPath = getParaFolderPath(type: type, name: name)
        let filePath = "\(folderPath)/journal.org"

        do {
            // Read file line by line, stopping early for efficiency
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            // Only check first 20 lines (descriptions should be at the top of org files)
            let linesToCheck = min(20, lines.count)

            for i in 0..<linesToCheck {
                let line = lines[i]
                if line.hasPrefix("#+DESCRIPTION:") {
                    // Extract description text, removing the prefix and trimming whitespace
                    let descPrefix = "#+DESCRIPTION:"
                    let startIndex = line.index(line.startIndex, offsetBy: descPrefix.count)
                    return String(line[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            return nil // No description found
        } catch {
            return nil // Error reading file
        }
    }

    // MARK: - Folder Operations

    /// Create a folder at the specified path
    public static func createFolder(at path: String) throws {
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw ParaError.fileSystemError("Error creating folder: \(error.localizedDescription)")
        }
    }

    /// Create a file with content
    public static func createFile(at path: String, content: String) throws {
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            throw ParaError.fileSystemError("Error creating file: \(error.localizedDescription)")
        }
    }

    /// Move item to archive
    public static func moveToArchive(from: String, to: String) throws {
        let fileManager = FileManager.default
        let expandedFrom = (from as NSString).expandingTildeInPath
        let expandedTo = (to as NSString).expandingTildeInPath

        // Ensure source exists before attempting to move
        guard fileManager.fileExists(atPath: expandedFrom) else {
            throw NSError(
                domain: "com.para",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Source path not found at \(expandedFrom)"]
            )
        }

        // Ensure destination parent directory exists
        let destinationDir = (expandedTo as NSString).deletingLastPathComponent
        try fileManager.createDirectory(atPath: destinationDir, withIntermediateDirectories: true, attributes: nil)

        // Prevent silent overwrite if destination already exists
        guard !fileManager.fileExists(atPath: expandedTo) else {
            throw NSError(
                domain: "com.para",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Destination already exists at \(expandedTo)"]
            )
        }

        try fileManager.moveItem(atPath: expandedFrom, toPath: expandedTo)
    }

    /// Delete a directory
    public static func deleteDirectory(at path: String) throws {
        let expandedPath = (path as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: expandedPath) {
            try FileManager.default.removeItem(atPath: expandedPath)
        } else {
            throw NSError(domain: "com.para", code: 1, userInfo: [NSLocalizedDescriptionKey: "Directory does not exist"])
        }
    }

    // MARK: - Folder Queries

    /// List all folders of a specific type
    public static func completeFolders(type: String) -> [String] {
        let paraHome = ParaEnvironment.paraHome
        let path = "\(paraHome)/\(type)s"

        do {
            let items = try FileManager.default.contentsOfDirectory(atPath: path)
            return items.filter { itemName in
                var isDir: ObjCBool = false
                let fullPath = "\(path)/\(itemName)"
                FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir)
                return isDir.boolValue
            }
        } catch {
            return []
        }
    }

    /// Check if a folder exists
    public static func folderExists(type: String, name: String) -> Bool {
        let paraHome = ParaEnvironment.paraHome
        let path = "\(paraHome)/\(type)s/\(name)"
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)

        return exists && isDir.boolValue
    }

    /// Check if a directory exists at path
    public static func directoryExists(at path: String) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    // MARK: - Search

    /// Find executable in PATH
    private static func findExecutable(_ name: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
                    return path
                }
            }
        } catch {
            return nil
        }

        return nil
    }

    /// Search result with context
    public struct SearchResult: Codable {
        public let file: String
        public let lineNumber: Int
        public let line: String
        public let contextBefore: [String]
        public let contextAfter: [String]

        public init(file: String, lineNumber: Int, line: String, contextBefore: [String], contextAfter: [String]) {
            self.file = file
            self.lineNumber = lineNumber
            self.line = line
            self.contextBefore = contextBefore
            self.contextAfter = contextAfter
        }
    }

    /// Search for text in files using ripgrep (fast) or grep (fallback)
    public static func searchFiles(in path: String, query: String, contextLines: Int = 2, caseSensitive: Bool = false) -> [SearchResult] {
        var results: [SearchResult] = []

        // Try to find ripgrep first (much faster), fall back to grep
        let rgPath = findExecutable("rg") ?? findExecutable("ripgrep")
        let searchTool = rgPath ?? "/usr/bin/grep"
        let isRipgrep = rgPath != nil

        let process = Process()
        process.executableURL = URL(fileURLWithPath: searchTool)

        var args: [String] = []

        if isRipgrep {
            // Ripgrep arguments
            args.append("--line-number")
            args.append("--no-heading")
            args.append("--with-filename")
            args.append("--color=never")

            if !caseSensitive {
                args.append("--ignore-case")
            }

            if contextLines > 0 {
                args.append("--context")
                args.append(String(contextLines))
            }

            args.append(query)
            args.append(path)
        } else {
            // Grep arguments
            args.append("-r")
            args.append("-n")

            if !caseSensitive {
                args.append("-i")
            }

            if contextLines > 0 {
                args.append("-C")
                args.append(String(contextLines))
            }

            args.append(query)
            args.append(path)
        }

        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // Suppress errors

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 || process.terminationStatus == 1 else {
                // Exit code 1 means no matches found (normal), other codes are errors
                return results
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
                return results
            }

            // Parse ripgrep/grep output with context
            // Format: "file:linenum:content" for matches, "file-linenum-content" for context
            let lines = output.components(separatedBy: .newlines)

            var i = 0
            while i < lines.count {
                let line = lines[i]

                if line.isEmpty || line == "--" {
                    i += 1
                    continue
                }

                // Try to parse as match line (file:linenum:content)
                if let colonIndex1 = line.firstIndex(of: ":"),
                   let colonIndex2 = line[line.index(after: colonIndex1)...].firstIndex(of: ":") {

                    let filePath = String(line[..<colonIndex1])
                    let lineNumStr = String(line[line.index(after: colonIndex1)..<colonIndex2])

                    if let lineNum = Int(lineNumStr) {
                        let matchContent = String(line[line.index(after: colonIndex2)...])

                        // Collect context before (look backwards for "-" lines)
                        var beforeContext: [String] = []
                        var j = i - 1
                        while j >= 0 && beforeContext.count < contextLines {
                            let prevLine = lines[j]
                            if prevLine.isEmpty || prevLine == "--" { break }

                            // Check if it's a context line (file-linenum-content)
                            if let dashIndex1 = prevLine.firstIndex(of: "-"),
                               let dashIndex2 = prevLine[prevLine.index(after: dashIndex1)...].firstIndex(of: "-") {
                                let content = String(prevLine[prevLine.index(after: dashIndex2)...])
                                beforeContext.insert(content, at: 0)
                            } else {
                                break
                            }
                            j -= 1
                        }

                        // Collect context after (look forward for "-" lines)
                        var afterContext: [String] = []
                        j = i + 1
                        while j < lines.count && afterContext.count < contextLines {
                            let nextLine = lines[j]
                            if nextLine.isEmpty || nextLine == "--" { break }

                            // Check if it's a context line (file-linenum-content)
                            if let dashIndex1 = nextLine.firstIndex(of: "-"),
                               let dashIndex2 = nextLine[nextLine.index(after: dashIndex1)...].firstIndex(of: "-") {
                                let content = String(nextLine[nextLine.index(after: dashIndex2)...])
                                afterContext.append(content)
                            } else {
                                break
                            }
                            j += 1
                        }

                        results.append(SearchResult(
                            file: filePath,
                            lineNumber: lineNum,
                            line: matchContent,
                            contextBefore: beforeContext,
                            contextAfter: afterContext
                        ))
                    }
                }

                i += 1
            }

        } catch {
            // If search tool fails, return empty results
        }

        return results
    }
}
