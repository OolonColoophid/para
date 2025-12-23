//
//  ParaEnvironment.swift
//  ParaKit
//
//  Environment configuration for the PARA system.
//

import Foundation

/// Environment configuration and paths for the PARA system
public struct ParaEnvironment {
    /// Base directory for PARA system (from PARA_HOME environment variable)
    public static var paraHome: String {
        ProcessInfo.processInfo.environment["PARA_HOME"] ??
            NSString(string: "~/Documents/PARA").expandingTildeInPath
    }

    /// Archive directory (from PARA_ARCHIVE environment variable)
    public static var paraArchive: String {
        ProcessInfo.processInfo.environment["PARA_ARCHIVE"] ??
            NSString(string: "~/Documents/archive").expandingTildeInPath
    }

    /// Path to projects directory
    public static var projectsPath: String {
        "\(paraHome)/projects"
    }

    /// Path to areas directory
    public static var areasPath: String {
        "\(paraHome)/areas"
    }

    /// Path to resources directory
    public static var resourcesPath: String {
        "\(paraHome)/resources"
    }

    /// Path to archive directory
    public static var archivePath: String {
        paraArchive
    }

    /// Get path for a specific item type directory
    public static func path(for type: ParaItemType) -> String {
        switch type {
        case .project:
            return projectsPath
        case .area:
            return areasPath
        case .resource:
            return resourcesPath
        case .archive:
            return archivePath
        }
    }

    /// Get path for a specific item
    public static func itemPath(type: ParaItemType, name: String) -> String {
        "\(path(for: type))/\(name)"
    }
}
