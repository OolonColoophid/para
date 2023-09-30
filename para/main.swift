//
//  main.swift
//  para
//
//  Created by Ian Hocking on 30/09/2023.
//

import Foundation
import ArgumentParser

struct Para: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A utility for managing PARA organization system",
        discussion: "Examples:\n  para create project roofBuild\n  para archive area guitar\n  para delete project roofBuild",
        subcommands: [Create.self, Archive.self, Delete.self]
    )
}

extension Para {
    static func getFolderPath(type: String, name: String) -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(homeDir)/Documents/\(type)s/\(name)"
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
}

extension Para {
    enum FolderType: String, ExpressibleByArgument {
        case project, area
    }
    struct Create: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Create a new Project or Area. Category will be set based on the name")
        @Argument(help: "Type of folder to create (project or area)")
        var type: FolderType // Changed to Enum
        @Argument(help: "Name of the folder") var name: String

        func validate() throws {
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw ValidationError("Name cannot be empty or just whitespace.")
            }
        }

        func run() throws {
            let folderPath = Para.getFolderPath(type: type.rawValue, name: name)
            Para.createFolder(at: folderPath)
            Para.createFile(at: "\(folderPath)/.projectile", content: "")

            let journalContent = "#+TITLE: \(name.capitalized) \(type.rawValue.capitalized) Journal\n#+CATEGORY: \(name.capitalized)"
            Para.createFile(at: "\(folderPath)/journal.org", content: journalContent)

            print("\(type.rawValue.capitalized) created successfully.")
        }
    }

    struct Archive: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Archive an existing Project or Area.")
        @Argument(help: "Type of folder to archive (project or area)") var type: FolderType
        @Argument(help: "Name of the folder") var name: String

        func run() {
            let fromPath = Para.getFolderPath(type: type.rawValue, name: name)
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            let toPath = "\(homeDir)/Documents/archive/\(name)"

            Para.moveToArchive(from: fromPath, to: toPath)
            print("\(type.rawValue.capitalized) moved to archive successfully.")
        }
    }

    struct Delete: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Delete a project or area")
        @Argument(help: "The type to delete (project/area)") var type: FolderType
        @Argument(help: "The name of the project or area to delete") var name: String

        func run() throws {
            let folderPath = Para.getFolderPath(type: type.rawValue, name: name)
            let expandedPath = (folderPath as NSString).expandingTildeInPath

            do {
                try Para.deleteDirectory(at: expandedPath)
            } catch let error {
                print("Error: \(error)")
            }
        }
    }
}

Para.main()
