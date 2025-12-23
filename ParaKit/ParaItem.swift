//
//  ParaItem.swift
//  ParaKit
//
//  Core data models for the PARA system.
//

import Foundation

/// Represents a project, area, resource, or archive in the PARA system
public struct ParaItem: Identifiable, Codable, Hashable {
    public let id: UUID
    public let name: String
    public let type: ParaItemType
    public let path: String
    public let description: String?
    public let journalPath: String

    public init(
        id: UUID = UUID(),
        name: String,
        type: ParaItemType,
        path: String,
        description: String? = nil,
        journalPath: String
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.path = path
        self.description = description
        self.journalPath = journalPath
    }
}

/// Types of items in the PARA system
public enum ParaItemType: String, Codable, CaseIterable {
    case project
    case area
    case resource
    case archive

    /// Plural form for directory names
    public var pluralName: String {
        switch self {
        case .project: return "projects"
        case .area: return "areas"
        case .resource: return "resources"
        case .archive: return "archive"
        }
    }
}
