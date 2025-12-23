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
}
