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
        subcommands: [Create.self, Archive.self, Delete.self, List.self, Open.self]
    )
}

// MARK: Make changes
extension Para {
    enum FolderType: String, ExpressibleByArgument {
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
        static var configuration = CommandConfiguration(abstract: "Archive an existing project or area.")

        @Argument(
            help: "Type of folder to archive (project or area)",
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

        @Flag(inversion: .prefixedNo, help: "Provide additional details on success.") var verbose = false

        func run() {
            let fromPath: String = Para.getParaFolderPath(type: type.rawValue, name: name)
            let homeDir: String = FileManager.default.homeDirectoryForCurrentUser.path
            let toPath: String = Para.getArchiveFolderPath(name: name) ?? "\(homeDir)/Documents/archive/\(name)"

            Para.moveToArchive(from: fromPath, to: toPath)

            if verbose {
                print("\(type.rawValue.capitalized) moved to archive successfully.")
            }
        }
    }

    struct Delete: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Delete a project or area")

        @Argument(
            help: "Type of folder to delete (project or area)",
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

        @Flag(inversion: .prefixedNo, help: "Provide additional details on success.") var verbose = false

        func run() throws {
            let folderPath = Para.getParaFolderPath(type: type.rawValue, name: name)
            let expandedPath = (folderPath as NSString).expandingTildeInPath

            do {
                try Para.deleteDirectory(at: expandedPath)
            } catch let error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }

    struct List: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "List existing Projects or Areas.")

        @Argument(help: "Type of folder to list (project or area)",
                  completion: CompletionKind.list(["project", "area"]))
        var type: FolderType

        func run() {
            let items = Para.completeFolders(type: type.rawValue)
            if items.isEmpty {
                print("No \(type.rawValue)s found.")
            } else {
                print("\(type.rawValue.capitalized)s:")
                for item in items {
                    print("  - \(item)")
                }
            }
        }
    }

    struct Open: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Open a project or area")

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

        @Flag(inversion: .prefixedNo, help: "Provide additional details on success.") var verbose = false

        func run() throws {
            let folderPath = Para.getParaFolderPath(type: type.rawValue, name: name)
            let expandedPath = (folderPath as NSString).expandingTildeInPath

            if let url = URL(string: "file://" + "\(folderPath)/journal.org") {
                NSWorkspace.shared.open(url)
            }
        }
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
}

Para.main()
