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
    public static let buildNumber: String = "PARA_BUILD_NUMBER"
    public static let buildTimestamp: String = "PARA_BUILD_TIMESTAMP"

    /// Formatted version string
    public static var displayString: String {
        "Version \(version) (build \(buildNumber))"
    }

    /// Full version with timestamp
    public static var fullDisplayString: String {
        "Version \(version) (build \(buildNumber))\nBuilt: \(buildTimestamp)"
    }
}
