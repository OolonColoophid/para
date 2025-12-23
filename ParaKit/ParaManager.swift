//
//  ParaManager.swift
//  ParaKit
//
//  Core business logic for managing PARA items.
//

import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Main manager for PARA operations, observable for UI updates
public class ParaManager: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var projects: [ParaItem] = []
    @Published public private(set) var areas: [ParaItem] = []
    @Published public private(set) var hasResources: Bool = false
    @Published public private(set) var hasArchive: Bool = false

    // MARK: - Initialization

    public init() {
        refresh()
    }

    // MARK: - Refresh

    /// Reload all items from the file system
    public func refresh() {
        projects = loadItems(type: .project)
        areas = loadItems(type: .area)
        hasResources = ParaFileSystem.directoryExists(at: ParaEnvironment.resourcesPath)
        hasArchive = ParaFileSystem.directoryExists(at: ParaEnvironment.archivePath)
    }

    // MARK: - Loading Items

    /// Load all items of a specific type
    private func loadItems(type: ParaItemType) -> [ParaItem] {
        let folders = ParaFileSystem.completeFolders(type: type.rawValue)

        return folders.compactMap { name in
            let path = ParaFileSystem.getParaFolderPath(type: type.rawValue, name: name)
            let journalPath = "\(path)/journal.org"
            let description = ParaFileSystem.getItemDescription(type: type.rawValue, name: name)

            return ParaItem(
                name: name,
                type: type,
                path: path,
                description: description,
                journalPath: journalPath
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Create

    /// Create a new project or area
    public func createItem(type: ParaItemType, name: String, open: Bool = false) throws -> ParaItem {
        guard type == .project || type == .area else {
            throw ParaError.invalidOperation("Can only create projects and areas")
        }

        let folderPath = ParaFileSystem.getParaFolderPath(type: type.rawValue, name: name)

        // Create the folder
        try ParaFileSystem.createFolder(at: folderPath)

        // Create journal.org file with template
        let journalPath = "\(folderPath)/journal.org"
        let journalContent = """
        #+TITLE: \(name)
        #+CATEGORY: \(name)

        * Notes


        """

        try ParaFileSystem.createFile(at: journalPath, content: journalContent)

        // Create the ParaItem
        let item = ParaItem(
            name: name,
            type: type,
            path: folderPath,
            description: nil,
            journalPath: journalPath
        )

        // Open if requested
        if open {
            openJournal(item)
        }

        // Refresh to update UI
        refresh()

        return item
    }

    // MARK: - Archive

    /// Archive an item (move to archive directory)
    public func archiveItem(_ item: ParaItem) throws {
        guard let archivePath = ParaFileSystem.getArchiveFolderPath(name: item.name) else {
            throw ParaError.invalidOperation("Archive path not configured")
        }

        try ParaFileSystem.moveToArchive(from: item.path, to: archivePath)

        // Refresh to update UI
        refresh()
    }

    // MARK: - Delete

    /// Delete an item permanently
    public func deleteItem(_ item: ParaItem) throws {
        try ParaFileSystem.deleteDirectory(at: item.path)

        // Refresh to update UI
        refresh()
    }

    // MARK: - Open/Reveal

    /// Open the journal.org file in the default application
    public func openJournal(_ item: ParaItem) {
        #if canImport(AppKit)
        let url = URL(fileURLWithPath: item.journalPath)
        NSWorkspace.shared.open(url)
        #endif
    }

    /// Reveal the item folder in Finder
    public func revealInFinder(_ item: ParaItem) {
        #if canImport(AppKit)
        let url = URL(fileURLWithPath: item.path)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
        #endif
    }

    /// Reveal a specific path in Finder
    public func revealPath(_ path: String) {
        #if canImport(AppKit)
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
        #endif
    }

    // MARK: - Utilities

    /// Get all items (projects and areas combined)
    public func getAllItems() -> [ParaItem] {
        return projects + areas
    }

    /// Find an item by name (searches projects first, then areas)
    public func findItem(name: String) -> ParaItem? {
        if let project = projects.first(where: { $0.name == name }) {
            return project
        }
        if let area = areas.first(where: { $0.name == name }) {
            return area
        }
        return nil
    }
}
