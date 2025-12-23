//
//  ParaError.swift
//  ParaKit
//
//  Error types for PARA operations.
//

import Foundation

/// Errors that can occur during PARA operations
public enum ParaError: Error, LocalizedError {
    case sourceNotFound(String)
    case destinationExists(String)
    case directoryNotFound(String)
    case invalidOperation(String)
    case fileSystemError(String)

    public var errorDescription: String? {
        switch self {
        case .sourceNotFound(let path):
            return "Source not found at: \(path)"
        case .destinationExists(let path):
            return "Destination already exists at: \(path)"
        case .directoryNotFound(let path):
            return "Directory not found: \(path)"
        case .invalidOperation(let message):
            return "Invalid operation: \(message)"
        case .fileSystemError(let message):
            return "File system error: \(message)"
        }
    }
}
