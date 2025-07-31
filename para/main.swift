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
    static let versionString: String = "0.1"
    static let buildNumber: String = {
        // Try to get git commit count as build number, fallback to timestamp
        let task = Process()
        task.launchPath = "/usr/bin/git"
        task.arguments = ["rev-list", "--count", "HEAD"]
        task.currentDirectoryPath = FileManager.default.currentDirectoryPath
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe() // Suppress errors
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !output.isEmpty {
                    return output
                }
            }
        } catch {
            // Git command failed, fallback to date-based build number
        }
        
        // Fallback: use compilation date as build identifier
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }()

    static let configuration = CommandConfiguration(
        abstract: "A utility for managing a local PARA organization system. See [https://fortelabs.com/blog/para/]",
        discussion: "Examples:\n  para create project roofBuild\n  para archive area guitar\n  para delete project roofBuild\n  para reveal project roofBuild\n \nThe directory for projects etc. should be specified in $PARA_HOME. Archives will be placed in $PARA_HOME/archive unless you specify a different folder in $PARA_ARCHIVE\n\nFor AI usage, add --json flag for machine-readable output.",
        version: versionString,  // Dynamic version string
        subcommands: [Create.self, Archive.self, Delete.self, List.self, Open.self, Reveal.self, Directory.self, Read.self, Headings.self, Environment.self, Version.self, AIOverview.self]
    )
    
    @Flag(help: "Output results in JSON format (recommended for AI/programmatic use)")
    var json = false
}

// MARK: Global state for JSON mode
struct ParaGlobals {
    static var jsonMode = false
}

// MARK: JSON output helpers
extension Para {
    static func outputJSON<T: Codable>(_ data: T) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let jsonData = try? encoder.encode(data),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }
    
    static func outputJSONAny(_ data: [String: Any]) {
        if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }
    
    static func outputError(_ message: String, code: Int = 1) {
        if ParaGlobals.jsonMode {
            let error = ["error": ["message": message, "code": code]] as [String: Any]
            if let jsonData = try? JSONSerialization.data(withJSONObject: error, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        } else {
            print("Error: \(message)")
        }
    }
    
    static func outputSuccess(_ message: String, data: [String: Any]? = nil) {
        if ParaGlobals.jsonMode {
            var response: [String: Any] = ["success": true, "message": message]
            if let data = data {
                response["data"] = data
            }
            if let jsonData = try? JSONSerialization.data(withJSONObject: response, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        } else {
            print(message)
        }
    }
}

// MARK: Make changes
extension Para {
    enum FolderType: String, ExpressibleByArgument, Decodable {
        case project, area
    }
    
    func run() throws {
        ParaGlobals.jsonMode = json
        
        if ParaGlobals.jsonMode {
            let data: [String: Any] = [
                "name": "Para",
                "version": Para.versionString,
                "build": Para.buildNumber,
                "description": "A utility for managing a local PARA organization system",
                "usage": "Run 'para --help' for available commands",
                "aiUsage": "Use 'para --json <command>' for machine-readable output",
                "documentation": "Run 'para ai-overview' for comprehensive documentation"
            ]
            Para.outputJSONAny(data)
        } else {
            print("Para v\(Para.versionString) (build \(Para.buildNumber)) - PARA Organization System Manager")
            print("")
            print("Manage your Projects, Areas, Resources, and Archives from the command line.")
            print("")
            print("Common commands:")
            print("  para list                    # List all projects and areas")
            print("  para create project <name>   # Create a new project")
            print("  para create area <name>      # Create a new area")
            print("  para read <type> <name>      # Read journal content")
            print("  para headings <type> <name>  # Show org-mode headings")
            print("  para open <type> <name>      # Open project/area journal")
            print("  para reveal <type> <name>    # Open folder in Finder")
            print("")
            print("For complete documentation:")
            print("  para --help                  # Show all commands")
            print("  para ai-overview             # Comprehensive guide")
            print("")
            print("For AI/programmatic usage:")
            print("  para --json <command>        # Get machine-readable output")
            print("")
            print("Environment setup:")
            print("  para environment             # Check configuration")
        }
    }

    struct Create: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Create a new project or area. Org category in-file metadata will be set based on the name")
        @Argument(help: "Type of folder to create (project or area)",
                  completion: CompletionKind.list(["project", "area"]))
        var type: FolderType // Changed to Enum
        @Argument(help: "Name of the folder") var name: String
        @Flag(inversion: .prefixedNo, help: "Provide additional details on success.") var verbose = false
        @Flag(inversion: .prefixedNo, help: "Opens the .org file after project or Area created.") var openOnCreate = true
        @OptionGroup var globalOptions: Para

        func validate() throws {
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw ValidationError("Name cannot be empty or just whitespace.")
            }
        }

        func run() throws {
            ParaGlobals.jsonMode = globalOptions.json
            let folderPath = Para.getParaFolderPath(type: type.rawValue, name: name)
            Para.createFolder(at: folderPath)

            let journalContent = "#+TITLE: \(name.capitalized) \(type.rawValue.capitalized) Journal\n#+CATEGORY: \(name.capitalized)"
            Para.createFile(at: "\(folderPath)/journal.org", content: journalContent)

            let data: [String: Any] = [
                "type": type.rawValue,
                "name": name,
                "path": folderPath,
                "journalPath": "\(folderPath)/journal.org"
            ]
            
            Para.outputSuccess("\(type.rawValue.capitalized) '\(name)' created successfully", data: data)

            // Open the .org file in the associated app if openOnCreate is true
            if openOnCreate && !ParaGlobals.jsonMode {
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
        @OptionGroup var globalOptions: Para

        func run() {
            ParaGlobals.jsonMode = globalOptions.json
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
                    Para.outputError("Could not find '\(name)' in either projects or areas")
                }
            }
        }
        
        func archiveFolder(type: String, name: String) {
            let fromPath: String = Para.getParaFolderPath(type: type, name: name)
            let homeDir: String = FileManager.default.homeDirectoryForCurrentUser.path
            let toPath: String = Para.getArchiveFolderPath(name: name) ?? "\(homeDir)/Dropbox/para/archive/\(name)"

            Para.moveToArchive(from: fromPath, to: toPath)

            let data: [String: Any] = [
                "type": type,
                "name": name,
                "fromPath": fromPath,
                "toPath": toPath
            ]
            
            Para.outputSuccess("\(type.capitalized) '\(name)' archived successfully", data: data)
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
        @OptionGroup var globalOptions: Para

        func run() throws {
            ParaGlobals.jsonMode = globalOptions.json
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
                    Para.outputError("Could not find '\(name)' in either projects or areas")
                }
            }
        }
        
        func deleteFolder(type: String, name: String) {
            let folderPath = Para.getParaFolderPath(type: type, name: name)
            // Use expandedPath directly in the deleteDirectory call
            do {
                try Para.deleteDirectory(at: folderPath)
                let data: [String: Any] = [
                    "type": type,
                    "name": name,
                    "path": folderPath
                ]
                Para.outputSuccess("\(type.capitalized) '\(name)' deleted successfully", data: data)
            } catch let error {
                Para.outputError(error.localizedDescription)
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
        
        @OptionGroup var globalOptions: Para

        func run() {
            ParaGlobals.jsonMode = globalOptions.json
            if ParaGlobals.jsonMode {
                outputJSONList()
            } else {
                outputHumanList()
            }
        }
        
        func outputJSONList() {
            let types = type?.rawValue != nil ? [type!.rawValue] : ["project", "area"]
            var result: [String: Any] = [:]
            
            for folderType in types {
                let items = Para.completeFolders(type: folderType)
                var itemsData: [[String: Any]] = []
                
                for item in items {
                    let path = Para.getParaFolderPath(type: folderType, name: item)
                    let description = Para.getItemDescription(type: folderType, name: item)
                    let itemData: [String: Any] = [
                        "name": item,
                        "path": path,
                        "description": description ?? ""
                    ]
                    itemsData.append(itemData)
                }
                
                result["\(folderType)s"] = itemsData
            }
            
            Para.outputJSONAny(result)
        }
        
        func outputHumanList() {
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
                print("\(type.capitalized)s:")
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
        @OptionGroup var globalOptions: Para

        func run() throws {
            ParaGlobals.jsonMode = globalOptions.json
            let folderPath = Para.getParaFolderPath(type: type.rawValue, name: name)
            let journalPath = "\(folderPath)/journal.org"
            
            // Open the journal.org file (only in human mode)
            if !ParaGlobals.jsonMode {
                if let url = URL(string: "file://" + journalPath) {
                    NSWorkspace.shared.open(url)
                }
            }
            
            let data: [String: Any] = [
                "type": type.rawValue,
                "name": name,
                "path": folderPath,
                "journalPath": journalPath,
                "opened": !ParaGlobals.jsonMode
            ]
            
            Para.outputSuccess("Opened journal.org for \(type.rawValue): \(name)", data: data)
        }
    }
    
    struct Reveal: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Open a project or area's folder in Finder"
        )

        @Argument(
            help: "Type of folder to reveal (project or area)",
            completion: .list(["project", "area"])
        )
        var type: FolderType

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
            revealFolder(type: type.rawValue, name: name)
        }
        
        func revealFolder(type: String, name: String) {
            let folderPath = Para.getParaFolderPath(type: type, name: name)
            
            // Open the folder in Finder (only in human mode)
            if !ParaGlobals.jsonMode {
                if let url = URL(string: "file://" + folderPath) {
                    NSWorkspace.shared.open(url)
                }
            }
            
            let data: [String: Any] = [
                "type": type,
                "name": name,
                "path": folderPath,
                "revealed": !ParaGlobals.jsonMode
            ]
            
            Para.outputSuccess("Revealed folder for \(type): \(name)", data: data)
        }
    }
    
    struct Directory: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Return the directory path of a project or area"
        )

        @Argument(
            help: "Type of folder (project or area)",
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

        func run() throws {
            let folderPath = Para.getParaFolderPath(type: type.rawValue, name: name)
            
            // Check if the folder exists
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: folderPath, isDirectory: &isDir) && isDir.boolValue else {
                Para.outputError("\(type.rawValue.capitalized) '\(name)' does not exist")
                return
            }
            
            if ParaGlobals.jsonMode {
                let data: [String: Any] = [
                    "type": type.rawValue,
                    "name": name,
                    "path": folderPath
                ]
                Para.outputJSONAny(data)
            } else {
                print(folderPath)
            }
        }
    }
    
    struct Read: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Read the entire journal.org file of a project or area"
        )

        @Argument(
            help: "Type of folder (project or area)",
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

        func run() throws {
            let folderPath = Para.getParaFolderPath(type: type.rawValue, name: name)
            let journalPath = "\(folderPath)/journal.org"
            
            // Check if the file exists
            guard FileManager.default.fileExists(atPath: journalPath) else {
                Para.outputError("Journal file not found for \(type.rawValue) '\(name)'")
                return
            }
            
            do {
                let content = try String(contentsOfFile: journalPath, encoding: .utf8)
                
                if ParaGlobals.jsonMode {
                    let data: [String: Any] = [
                        "type": type.rawValue,
                        "name": name,
                        "journalPath": journalPath,
                        "content": content,
                        "lineCount": content.components(separatedBy: .newlines).count
                    ]
                    Para.outputJSONAny(data)
                } else {
                    print(content)
                }
            } catch {
                Para.outputError("Failed to read journal file: \(error.localizedDescription)")
            }
        }
    }
    
    struct Headings: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Read only the org-mode headings from a project or area's journal"
        )

        @Argument(
            help: "Type of folder (project or area)",
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

        func run() throws {
            let folderPath = Para.getParaFolderPath(type: type.rawValue, name: name)
            let journalPath = "\(folderPath)/journal.org"
            
            // Check if the file exists
            guard FileManager.default.fileExists(atPath: journalPath) else {
                Para.outputError("Journal file not found for \(type.rawValue) '\(name)'")
                return
            }
            
            do {
                let content = try String(contentsOfFile: journalPath, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                
                // Filter lines that start with '* ' (org-mode headings)
                let headings = lines.filter { line in
                    line.hasPrefix("* ")
                }
                
                if ParaGlobals.jsonMode {
                    let data: [String: Any] = [
                        "type": type.rawValue,
                        "name": name,
                        "journalPath": journalPath,
                        "headings": headings,
                        "headingCount": headings.count
                    ]
                    Para.outputJSONAny(data)
                } else {
                    if headings.isEmpty {
                        print("No headings found in \(type.rawValue) '\(name)'")
                    } else {
                        for heading in headings {
                            print(heading)
                        }
                    }
                }
            } catch {
                Para.outputError("Failed to read journal file: \(error.localizedDescription)")
            }
        }
    }
    
    struct Environment: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Display current environment settings for the PARA system"
        )
        
        @OptionGroup var globalOptions: Para
        
        func run() {
            ParaGlobals.jsonMode = globalOptions.json
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            
            // Get PARA_HOME value or use default
            let paraHomeEnv = ProcessInfo.processInfo.environment["PARA_HOME"]
            let paraHome = paraHomeEnv ?? "\(homeDir)/Documents/PARA"
            
            // Get PARA_ARCHIVE value or use default
            let paraArchiveEnv = ProcessInfo.processInfo.environment["PARA_ARCHIVE"]
            let paraArchive = paraArchiveEnv ?? "\(homeDir)/Documents/archive"
            
            // Check if directories exist
            var isDir: ObjCBool = false
            let homeExists = FileManager.default.fileExists(atPath: paraHome, isDirectory: &isDir) && isDir.boolValue
            let archiveExists = FileManager.default.fileExists(atPath: paraArchive, isDirectory: &isDir) && isDir.boolValue
            
            if ParaGlobals.jsonMode {
                let data: [String: Any] = [
                    "environment": [
                        "PARA_HOME": [
                            "value": paraHome,
                            "isDefault": paraHomeEnv == nil,
                            "exists": homeExists
                        ],
                        "PARA_ARCHIVE": [
                            "value": paraArchive,
                            "isDefault": paraArchiveEnv == nil,
                            "exists": archiveExists
                        ]
                    ],
                    "setup": [
                        "allDirectoriesExist": homeExists && archiveExists,
                        "missingDirectories": !homeExists || !archiveExists ? [
                            homeExists ? nil : paraHome,
                            archiveExists ? nil : paraArchive
                        ].compactMap { $0 } : []
                    ]
                ]
                Para.outputJSONAny(data)
            } else {
                print("Environment variables:")
                print("  PARA_HOME = \(paraHome)\(paraHomeEnv == nil ? " (default)" : "")")
                print("  PARA_ARCHIVE = \(paraArchive)\(paraArchiveEnv == nil ? " (default)" : "")")
                
                print("\nDirectory status:")
                print("  PARA_HOME directory: \(homeExists ? "Exists" : "Does not exist")")
                print("  PARA_ARCHIVE directory: \(archiveExists ? "Exists" : "Does not exist")")
                
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
    
    struct Version: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Display Para version information"
        )
        
        @OptionGroup var globalOptions: Para
        
        func run() {
            ParaGlobals.jsonMode = globalOptions.json
            if ParaGlobals.jsonMode {
                let data: [String: Any] = [
                    "version": Para.versionString,
                    "build": Para.buildNumber,
                    "name": "Para",
                    "description": "A utility for managing a local PARA organization system"
                ]
                Para.outputJSONAny(data)
            } else {
                print("Para version \(Para.versionString) (build \(Para.buildNumber))")
                print("A utility for managing a local PARA organization system")
                print("https://fortelabs.com/blog/para/")
            }
        }
    }
    
    struct AIOverview: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "ai-overview",
            abstract: "Comprehensive overview of Para for AI understanding"
        )
        
        func run() {
            print("""
# Para CLI Tool - AI Overview (v0.1)

## RECOMMENDED FOR AI USAGE
**Always use the `--json` flag for machine-readable output:**
```bash
para --json list
para --json create project example
para --json environment
```

JSON mode provides structured data that's easier to parse programmatically, while human mode includes formatting designed for terminal display.

## Purpose & Context
Para is a command-line tool for managing a PARA (Projects, Areas, Resources, Archives) productivity system. 
PARA is a methodology developed by Tiago Forte for organizing digital information and tasks.

## Core Concepts
- **Projects**: Specific outcomes with deadlines (e.g., "renovate kitchen", "launch website")
- **Areas**: Ongoing responsibilities to maintain (e.g., "health", "finances", "team management")
- **Resources**: Topics of ongoing interest (e.g., "web design", "productivity tips")
- **Archives**: Inactive items from the other categories

## File System Structure
Para expects this directory structure:
```
$PARA_HOME/
├── projects/
│   ├── projectName1/
│   │   └── journal.org
│   └── projectName2/
│       └── journal.org
└── areas/
    ├── areaName1/
    │   └── journal.org
    └── areaName2/
        └── journal.org
```

## Environment Variables
- **PARA_HOME**: Base directory (default: ~/Documents/PARA)
- **PARA_ARCHIVE**: Archive location (default: ~/Documents/archive)

## Output Modes

### Human-Readable Mode (Default)
- Includes formatted text for readability
- Designed for terminal display and human consumption
- Opens files/folders automatically when appropriate
- Example: `para list` shows "Projects:" with indented formatting

### JSON Mode (Recommended for AI/Programmatic Use)
- Structured, machine-readable output
- No visual formatting or colors
- Consistent schema across all commands
- Disables automatic file/folder opening for safety
- Always returns valid JSON with success/error status
- Example: `para --json list` returns structured data with paths and metadata

**Key JSON advantages for AI:**
- Predictable data structure
- Full paths included in responses
- Complete metadata (descriptions, timestamps, etc.)
- Error handling with consistent format
- No terminal-specific formatting to parse

## Command Reference

### 1. CREATE
**Purpose**: Create new projects or areas with required files
**Syntax**: `para [--json] create <type> <name> [--no-open-on-create] [--no-verbose]`
**Examples**:
  - `para create project roofBuild` (human-readable)
  - `para --json create area guitar` (JSON output)
**What it does**:
  - Creates directory: $PARA_HOME/{type}s/{name}/
  - Creates journal.org with title and category metadata
  - Opens journal.org in default app (unless --no-open-on-create or JSON mode)

### 2. ARCHIVE
**Purpose**: Move completed projects/areas to archive location
**Syntax**: `para archive [type] <name> [--no-verbose]`
**Examples**:
  - `para archive project roofBuild`
  - `para archive guitar` (auto-detects type)
**What it does**:
  - Moves folder from $PARA_HOME/{type}s/{name} to $PARA_ARCHIVE/{name}
  - If type omitted, searches both projects and areas
  - Preserves all files and subdirectories

### 3. DELETE
**Purpose**: Permanently remove projects/areas
**Syntax**: `para delete [type] <name> [--no-verbose]`
**Examples**:
  - `para delete project oldProject`
  - `para delete someFolder` (auto-detects type)
**What it does**:
  - Permanently deletes the entire folder and contents
  - If type omitted, searches both projects and areas
  - No recovery mechanism - use carefully

### 4. LIST
**Purpose**: Display existing projects and/or areas
**Syntax**: `para [--json] list [type]`
**Examples**:
  - `para list` (human: shows both projects and areas with formatting)
  - `para --json list project` (JSON: structured data with paths and descriptions)
  - `para --json list area`
**What it does**:
  - Human mode: Shows projects and areas with indented formatting, truncated descriptions
  - JSON mode: Returns structured data with name, path, and full description for each item

### 5. OPEN
**Purpose**: Open journal.org file in default application
**Syntax**: `para open <type> <name> [--no-verbose]`
**Examples**:
  - `para open project roofBuild`
  - `para open area guitar`
**What it does**:
  - Opens {folder}/journal.org in system default app (usually text editor)
  - Useful for quick access to project notes and metadata

### 6. REVEAL
**Purpose**: Open project/area folder in Finder (macOS only)
**Syntax**: `para reveal <type> <name> [--no-verbose]`
**Examples**:
  - `para reveal project roofBuild`
  - `para reveal area guitar`
**What it does**:
  - Opens the folder in macOS Finder specifically
  - Allows browsing all files within the project/area
  - macOS-specific command using NSWorkspace

### 7. DIRECTORY
**Purpose**: Return the absolute path to a project/area directory
**Syntax**: `para [--json] directory <type> <name>`
**Examples**:
  - `para directory project roofBuild` → `/Users/user/Dropbox/para/projects/roofBuild`
  - `para --json directory area guitar` → structured path data
**What it does**:
  - Outputs the full filesystem path
  - Useful for scripting and automation
  - Validates folder exists before returning path

### 8. READ
**Purpose**: Read the entire journal.org file of a project or area
**Syntax**: `para [--json] read <type> <name>`
**Examples**:
  - `para read project roofBuild` (human: outputs file content)
  - `para --json read area guitar` (JSON: structured content with metadata)
**What it does**:
  - Reads and displays the complete journal.org file content
  - Human mode: Prints file content directly to console
  - JSON mode: Returns content with metadata (path, line count)

### 9. HEADINGS
**Purpose**: Read only the org-mode headings from a project/area's journal
**Syntax**: `para [--json] headings <type> <name>`
**Examples**:
  - `para headings project roofBuild` (human: lists headings)
  - `para --json headings area guitar` (JSON: structured heading data)
**What it does**:
  - Extracts and displays only lines starting with '* ' (org-mode headings)
  - Human mode: Prints each heading on a separate line
  - JSON mode: Returns headings array with count metadata

### 10. ENVIRONMENT
**Purpose**: Display configuration and validate setup
**Syntax**: `para [--json] environment`
**What it does**:
  - Shows PARA_HOME and PARA_ARCHIVE values (and whether they're defaults)
  - Checks if required directories exist
  - Provides mkdir commands for missing directories

### 11. VERSION
**Purpose**: Display Para version information
**Syntax**: `para [--json] version`
**Examples**:
  - `para version` (human: shows version with description)
  - `para --json version` (JSON: structured version data)
**What it does**:
  - Shows current Para version (0.1)
  - Provides tool description and project URL
  - JSON mode returns structured version metadata

## Tab Completion
- All commands support tab completion for types (project/area)
- Folder name arguments complete from existing projects/areas
- Archive/delete commands complete from available folders

## File Conventions
- **journal.org**: Main file with Org-mode format
  - Contains #+TITLE: and #+CATEGORY: metadata
  - Optional #+DESCRIPTION: for list display

## Common Workflows

### Human Workflows
1. **Start new project**: `para create project newWebsite`
2. **Work on project**: `para open project newWebsite`
3. **View progress**: `para list project`
4. **Read project journal**: `para read project newWebsite`
5. **Check project structure**: `para headings project newWebsite`
6. **Complete project**: `para archive project newWebsite`
7. **Browse files**: `para reveal project newWebsite`
8. **Get path for scripts**: `para directory project newWebsite`

### AI/Programmatic Workflows
1. **Check version**: `para --json version`
2. **Create and get data**: `para --json create project newWebsite`
3. **List all items with metadata**: `para --json list`
4. **Read journal content**: `para --json read project newWebsite`
5. **Extract headings/structure**: `para --json headings project newWebsite`
6. **Get environment status**: `para --json environment`
7. **Get project path**: `para --json directory project newWebsite`
8. **Archive with confirmation**: `para --json archive project newWebsite`

## Integration Notes
- Designed for Org-mode users (Emacs)
- Reveal command is macOS-specific (uses NSWorkspace/Finder)
- Environment commands help with setup validation
- Directory command enables shell scripting integration
""")
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
