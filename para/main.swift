//
//  main.swift
//  para
//
//  Created by Ian Hocking on 30/09/2023.
//

// TODO: Search for text - p, a, r, archive scope. Best to do with:
// > mdfind -onlyin . "kMDItemTextContent == 'Derek'c"
// This will return all files (including non-text files) that contain Derek

import Foundation
import ArgumentParser
import AppKit

// MARK: CLI arguments
struct Para: ParsableCommand {
    static let versionString: String = {
        if let infoDictionary = Bundle.main.infoDictionary,
           let version = infoDictionary["CFBundleShortVersionString"] as? String,
           let build = infoDictionary["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return "Unknown Version"
    }()

    static let configuration = CommandConfiguration(
        abstract: "A utility for managing a local PARA organization system. See [https://fortelabs.com/blog/para/]",
        discussion: "Examples:\n  para create project roofBuild\n  para archive area guitar\n  para delete project roofBuild\n \nThe directory for projects etc. should be specified in $PARA_HOME. Archives will be placed in $PARA_HOME/archive unless you specify a different folder in $PARA_ARCHIVE",
        version: versionString,  // Dynamic version string
        subcommands: [Create.self, Archive.self, Delete.self, List.self, Open.self, Environment.self, Reveal.self]
    )
}

// MARK: Make changes
extension Para {
    enum FolderType: String, ExpressibleByArgument, Decodable {
        case project, area
    }

    struct Create: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Create a new project or area. Org category in-file metadata will be set based on the name")
        @Argument(help: "Type of folder to create (project or area)",
                  completion: CompletionKind.list(["project", "area"]))
        var type: FolderType // Changed to Enum
        @Argument(help: "Name of the folder") var name: String
        @Flag(inversion: .prefixedNo, help: "Provide additional details on success.") var verbose = false
        @Flag(inversion: .prefixedNo, help: "Opens the .org file after project or Area created.") var openOnCreate = true

        func validate() throws {
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw ValidationError("Name cannot be empty or just whitespace.")
            }
        }

        func run() throws {
            let folderPath = Para.getParaFolderPath(type: type.rawValue, name: name)
            Para.createFolder(at: folderPath)
            Para.createFile(at: "\(folderPath)/.projectile", content: "")

            let journalContent = "#+TITLE: \(name.capitalized) \(type.rawValue.capitalized) Journal\n#+CATEGORY: \(name.capitalized)"
            Para.createFile(at: "\(folderPath)/journal.org", content: journalContent)

            if verbose {
                print("\(type.rawValue.capitalized) created successfully.")
            }

            // Open the .org file in the associated app if openOnCreate is true
            if openOnCreate {
                if let url = URL(string: "file://" + "\(folderPath)/journal.org") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    struct Archive: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Archive an existing project or area. If type is not specified, the command will attempt to find the folder in either projects or areas.")

        @Argument(
            help: "Type of folder to archive (project or area)",
            completion: CompletionKind.list(["project", "area"])
        )
        var type: FolderType?

        @Argument(
            help: "Name of the folder",
            completion: CompletionKind.custom { _ in
                var items: [String] = []
                if CommandLine.arguments.contains("project") {
                    items.append(contentsOf: Para.completeFolders(type: "project"))
                } else if CommandLine.arguments.contains("area") {
                    items.append(contentsOf: Para.completeFolders(type: "area"))
                } else {
                    // If no type is specified, show both
                    items.append(contentsOf: Para.completeFolders(type: "project"))
                    items.append(contentsOf: Para.completeFolders(type: "area"))
                }
                return items
            }
        )
        var name: String

        @Flag(inversion: .prefixedNo, help: "Provide additional details on success.") var verbose = false

        func run() {
            let folderType: String
            
            if let specifiedType = type {
                // Use the specified type
                folderType = specifiedType.rawValue
                archiveFolder(type: folderType, name: name)
            } else {
                // Try to find the folder in either projects or areas
                if Para.folderExists(type: "project", name: name) {
                    archiveFolder(type: "project", name: name)
                } else if Para.folderExists(type: "area", name: name) {
                    archiveFolder(type: "area", name: name)
                } else {
                    print("Error: Could not find '\(name)' in either projects or areas.")
                }
            }
        }
        
        func archiveFolder(type: String, name: String) {
            let fromPath: String = Para.getParaFolderPath(type: type, name: name)
            let homeDir: String = FileManager.default.homeDirectoryForCurrentUser.path
            let toPath: String = Para.getArchiveFolderPath(name: name) ?? "\(homeDir)/Dropbox/para/archive/\(name)"

            Para.moveToArchive(from: fromPath, to: toPath)

            if verbose {
                print("\(type.capitalized) moved to archive successfully.")
            }
        }
    }

    struct Delete: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Delete a project or area. If type is not specified, the command will attempt to find the folder in either projects or areas.")

        @Argument(
            help: "Type of folder to delete (project or area)",
            completion: CompletionKind.list(["project", "area"])
        )
        var type: FolderType?        

        @Argument(
            help: "Name of the folder",
            completion: CompletionKind.custom { _ in
                var items: [String] = []
                if CommandLine.arguments.contains("project") {
                    items.append(contentsOf: Para.completeFolders(type: "project"))
                } else if CommandLine.arguments.contains("area") {
                    items.append(contentsOf: Para.completeFolders(type: "area"))
                } else {
                    // If no type is specified, show both
                    items.append(contentsOf: Para.completeFolders(type: "project"))
                    items.append(contentsOf: Para.completeFolders(type: "area"))
                }
                return items
            }
        )
        var name: String

        @Flag(inversion: .prefixedNo, help: "Provide additional details on success.") var verbose = false

        func run() throws {
            if let specifiedType = type {
                // Use the specified type
                deleteFolder(type: specifiedType.rawValue, name: name)
            } else {
                // Try to find the folder in either projects or areas
                if Para.folderExists(type: "project", name: name) {
                    deleteFolder(type: "project", name: name)
                } else if Para.folderExists(type: "area", name: name) {
                    deleteFolder(type: "area", name: name)
                } else {
                    print("Error: Could not find '\(name)' in either projects or areas.")
                }
            }
        }
        
        func deleteFolder(type: String, name: String) {
            let folderPath = Para.getParaFolderPath(type: type, name: name)
            // Use expandedPath directly in the deleteDirectory call
            do {
                try Para.deleteDirectory(at: folderPath)
                if verbose {
                    print("\(type.capitalized) deleted successfully.")
                }
            } catch let error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }

    struct List: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "List existing Projects or Areas. If no type is specified, lists both.")

        @Argument(
            help: "Type of folder to list (project or area)",
            completion: CompletionKind.list(["project", "area"])
        )
        var type: FolderType?

        func run() {
            if let specifiedType = type {
                // List only the specified type
                listFoldersByType(specifiedType.rawValue)
            } else {
                // List both projects and areas
                listFoldersByType("project")
                print("") // Empty line for separation
                listFoldersByType("area")
            }
        }
        
        func listFoldersByType(_ type: String) {
            let items = Para.completeFolders(type: type)
            if items.isEmpty {
                print("No \(type)s found.")
            } else {
                let emoji = type == "project" ? "📁" : "🔄"
                print("\(emoji) \(type.capitalized)s:")
                for item in items {
                    let description = Para.getItemDescription(type: type, name: item)
                    if let desc = description, !desc.isEmpty {
                        // Print with description (truncate if longer than 80 chars)
                        let truncatedDesc = desc.count > 80 ? desc.prefix(77) + "..." : desc
                        print("  - \(item.padded(to: 20)) \(truncatedDesc)")
                    } else {
                        print("  - \(item)")
                    }
                }
            }
        }
    }

    struct Open: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Open a project or area's journal.org file"
        )

        @Argument(
            help: "Type of folder to open (project or area)",
            completion: CompletionKind.list(["project", "area"])
        )
        var type: FolderType

        @Argument(
            help: "Name of the folder",
            completion: CompletionKind.custom { _ in
                if CommandLine.arguments.contains("project") {
                    return Para.completeFolders(type: "project")
                }
                if CommandLine.arguments.contains("area") {
                    return Para.completeFolders(type: "area")
                }
                return []
            }
        )
        var name: String
        
        @Flag(inversion: .prefixedNo, help: "Provide additional details on success.") 
        var verbose = false

        func run() throws {
            let folderPath = Para.getParaFolderPath(type: type.rawValue, name: name)
            
            // Open the journal.org file
            if let url = URL(string: "file://" + "\(folderPath)/journal.org") {
                NSWorkspace.shared.open(url)
                if verbose {
                    print("Opened journal.org for \(type.rawValue): \(name)")
                }
            }
        }
    }
    
    struct Reveal: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Open a project or area's folder in Finder"
        )

        @Argument(
            help: "Type of folder to reveal (project or area)",
            completion: CompletionKind.list(["project", "area"])
        )
        var type: FolderType?

        @Argument(
            help: "Name of the folder",
            completion: CompletionKind.custom { _ in
                var items: [String] = []
                if CommandLine.arguments.contains("project") {
                    items.append(contentsOf: Para.completeFolders(type: "project"))
                } else if CommandLine.arguments.contains("area") {
                    items.append(contentsOf: Para.completeFolders(type: "area"))
                } else {
                    // If no type is specified, show both
                    items.append(contentsOf: Para.completeFolders(type: "project"))
                    items.append(contentsOf: Para.completeFolders(type: "area"))
                }
                return items
            }
        )
        var name: String
        
        @Flag(inversion: .prefixedNo, help: "Provide additional details on success.") 
        var verbose = false

        func run() throws {
            if let specifiedType = type {
                // Use the specified type
                revealFolder(type: specifiedType.rawValue, name: name)
            } else {
                // Try to find the folder in either projects or areas
                if Para.folderExists(type: "project", name: name) {
                    revealFolder(type: "project", name: name)
                } else if Para.folderExists(type: "area", name: name) {
                    revealFolder(type: "area", name: name)
                } else {
                    print("Error: Could not find '\(name)' in either projects or areas.")
                }
            }
        }
        
        func revealFolder(type: String, name: String) {
            let folderPath = Para.getParaFolderPath(type: type, name: name)
            
            // Open the folder in Finder
            if let url = URL(string: "file://" + folderPath) {
                NSWorkspace.shared.open(url)
                if verbose {
                    print("Opened folder for \(type): \(name)")
                }
            }
        }
    }
    
    struct Environment: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Display current environment settings for the PARA system"
        )
        
        func run() {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            
            // Get PARA_HOME value or use default
            let paraHomeEnv = ProcessInfo.processInfo.environment["PARA_HOME"]
            let paraHome = paraHomeEnv ?? "\(homeDir)/Documents/PARA"
            
            // Get PARA_ARCHIVE value or use default
            let paraArchiveEnv = ProcessInfo.processInfo.environment["PARA_ARCHIVE"]
            let paraArchive = paraArchiveEnv ?? "\(homeDir)/Documents/archive"
            
            print("Environment variables:")
            print("  PARA_HOME = \(paraHome)\(paraHomeEnv == nil ? " (default)" : "")")
            print("  PARA_ARCHIVE = \(paraArchive)\(paraArchiveEnv == nil ? " (default)" : "")")
            
            // Check if directories exist
            var isDir: ObjCBool = false
            let homeExists = FileManager.default.fileExists(atPath: paraHome, isDirectory: &isDir) && isDir.boolValue
            let archiveExists = FileManager.default.fileExists(atPath: paraArchive, isDirectory: &isDir) && isDir.boolValue
            
            print("\nDirectory status:")
            print("  PARA_HOME directory: \(homeExists ? "✅ Exists" : "❌ Does not exist")")
            print("  PARA_ARCHIVE directory: \(archiveExists ? "✅ Exists" : "❌ Does not exist")")
            
            if !homeExists || !archiveExists {
                print("\nMissing directories can be created with:")
                if !homeExists {
                    print("  mkdir -p \"\(paraHome)\"")
                    print("  mkdir -p \"\(paraHome)/projects\"")
                    print("  mkdir -p \"\(paraHome)/areas\"")
                }
                if !archiveExists {
                    print("  mkdir -p \"\(paraArchive)\"")
                }
            }
        }
    }
}

// String extension to pad strings to a certain length
extension String {
    func padded(to length: Int) -> String {
        if self.count >= length {
            return self
        }
        return self + String(repeating: " ", count: length - self.count)
    }
}

// MARK: Helpers
extension Para {
    static func getParaFolderPath(type: String, name: String) -> String {
        if let paraHome = ProcessInfo.processInfo.environment["PARA_HOME"] {
            return "\(paraHome)/\(type)s/\(name)"
        } else {
            // Fallback or error handling
            print("Error: PARA_HOME is not set.")
            return ""
        }
    }
    
    static func getItemDescription(type: String, name: String) -> String? {
        let folderPath = getParaFolderPath(type: type, name: name)
        let filePath = "\(folderPath)/journal.org"
        
        do {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            
            // Look for #+DESCRIPTION: line
            for line in lines {
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

    static func getArchiveFolderPath(name: String) -> String? {
        if let archiveFoler = ProcessInfo.processInfo.environment["PARA_ARCHIVE"] {
            return "\(archiveFoler)/\(name)"
        } else {
            return nil
        }
    }

    static func createFolder(at path: String) {
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Error creating folder: \(error)")
        }
    }

    static func createFile(at path: String, content: String) {
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            print("Error creating file: \(error)")
        }
    }

    static func moveToArchive(from: String, to: String) {
        do {
            try FileManager.default.moveItem(atPath: from, toPath: to)
        } catch {
            print("Error moving to archive: \(error)")
        }
    }

    static func deleteDirectory(at path: String) throws {
        let expandedPath = (path as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: expandedPath) {
            try FileManager.default.removeItem(atPath: expandedPath)
        } else {
            throw NSError(domain: "com.para", code: 1, userInfo: [NSLocalizedDescriptionKey: "Directory does not exist"])
        }
    }

    static func completeFolders(type: String) -> [String] {
        guard let paraHome = ProcessInfo.processInfo.environment["PARA_HOME"] else {
            return []
        }

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
    
    static func folderExists(type: String, name: String) -> Bool {
        guard let paraHome = ProcessInfo.processInfo.environment["PARA_HOME"] else {
            return false
        }
        
        let path = "\(paraHome)/\(type)s/\(name)"
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        
        return exists && isDir.boolValue
    }
}

Para.main()
