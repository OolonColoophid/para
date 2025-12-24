//
//  ParaSettings.swift
//  ParaKit
//
//  User settings stored in UserDefaults.
//

import Foundation

/// Keys for UserDefaults storage
private enum SettingsKey: String {
    case paraHome = "ParaHome"
    case paraArchive = "ParaArchive"
    case terminalApp = "TerminalApp"
}

/// User-configurable settings for the PARA system
public class ParaSettings: ObservableObject {

    /// Shared singleton instance
    public static let shared = ParaSettings()

    private let defaults = UserDefaults.standard

    /// Custom PARA home directory (nil means use environment or default)
    @Published public var paraHome: String? {
        didSet {
            if let value = paraHome, !value.isEmpty {
                defaults.set(value, forKey: SettingsKey.paraHome.rawValue)
            } else {
                defaults.removeObject(forKey: SettingsKey.paraHome.rawValue)
            }
        }
    }

    /// Custom archive directory (nil means use environment or default)
    @Published public var paraArchive: String? {
        didSet {
            if let value = paraArchive, !value.isEmpty {
                defaults.set(value, forKey: SettingsKey.paraArchive.rawValue)
            } else {
                defaults.removeObject(forKey: SettingsKey.paraArchive.rawValue)
            }
        }
    }

    /// Terminal application to use (nil means use default Terminal.app)
    @Published public var terminalApp: String? {
        didSet {
            if let value = terminalApp, !value.isEmpty {
                defaults.set(value, forKey: SettingsKey.terminalApp.rawValue)
            } else {
                defaults.removeObject(forKey: SettingsKey.terminalApp.rawValue)
            }
        }
    }

    private init() {
        // Load saved values
        self.paraHome = defaults.string(forKey: SettingsKey.paraHome.rawValue)
        self.paraArchive = defaults.string(forKey: SettingsKey.paraArchive.rawValue)
        self.terminalApp = defaults.string(forKey: SettingsKey.terminalApp.rawValue)
    }

    /// Get the effective PARA home path (UserDefaults > Environment > Default)
    public var effectiveParaHome: String {
        // 1. Check UserDefaults
        if let saved = paraHome, !saved.isEmpty {
            return NSString(string: saved).expandingTildeInPath
        }
        // 2. Check environment variable
        if let env = ProcessInfo.processInfo.environment["PARA_HOME"] {
            return env
        }
        // 3. Fall back to default
        return NSString(string: "~/Dropbox/para").expandingTildeInPath
    }

    /// Get the effective archive path (UserDefaults > Environment > Default)
    public var effectiveParaArchive: String {
        // 1. Check UserDefaults
        if let saved = paraArchive, !saved.isEmpty {
            return NSString(string: saved).expandingTildeInPath
        }
        // 2. Check environment variable
        if let env = ProcessInfo.processInfo.environment["PARA_ARCHIVE"] {
            return env
        }
        // 3. Fall back to default
        return NSString(string: "~/Dropbox/archive").expandingTildeInPath
    }

    /// Source of current PARA home setting
    public var paraHomeSource: SettingSource {
        if let saved = paraHome, !saved.isEmpty {
            return .userDefaults
        }
        if ProcessInfo.processInfo.environment["PARA_HOME"] != nil {
            return .environment
        }
        return .defaultValue
    }

    /// Source of current archive setting
    public var paraArchiveSource: SettingSource {
        if let saved = paraArchive, !saved.isEmpty {
            return .userDefaults
        }
        if ProcessInfo.processInfo.environment["PARA_ARCHIVE"] != nil {
            return .environment
        }
        return .defaultValue
    }

    /// Get the effective terminal app (UserDefaults > Default)
    public var effectiveTerminalApp: String {
        if let saved = terminalApp, !saved.isEmpty {
            return saved
        }
        return "Terminal"  // macOS default
    }

    /// Source of current terminal app setting
    public var terminalAppSource: SettingSource {
        if let saved = terminalApp, !saved.isEmpty {
            return .userDefaults
        }
        return .defaultValue
    }
}

/// Indicates where a setting value came from
public enum SettingSource: String {
    case userDefaults = "Settings"
    case environment = "Environment"
    case defaultValue = "Default"
}
