//
//  ParaVersion.swift
//  ParaKit
//
//  Version information for Para apps.
//

import Foundation

/// Version information for Para
public struct ParaVersion {
    public static let version: String = "0.1"
    public static let buildNumber: String = "51"
    public static let buildTimestamp: String = "2026-01-03 17:41:53 UTC"

    /// Formatted version string
    public static var displayString: String {
        "Version \(version) (build \(buildNumber))"
    }

    /// Full version with timestamp
    public static var fullDisplayString: String {
        "Version \(version) (build \(buildNumber))\nBuilt: \(buildTimestamp)"
    }
}
