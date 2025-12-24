//
//  SettingsView.swift
//  ParaMenuBar
//
//  Settings window for configuring PARA paths.
//

import SwiftUI
import ParaKit

struct SettingsView: View {
    @ObservedObject private var settings = ParaSettings.shared
    @State private var paraHomeText: String = ""
    @State private var paraArchiveText: String = ""
    @Environment(\.dismiss) private var dismiss

    private let labelWidth: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Current paths section
            GroupBox("Current Paths") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text("PARA Home:")
                            .frame(width: 80, alignment: .trailing)
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(settings.effectiveParaHome)
                                .textSelection(.enabled)
                            Text("Source: \(settings.paraHomeSource.rawValue)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    HStack(alignment: .top) {
                        Text("Archive:")
                            .frame(width: 80, alignment: .trailing)
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(settings.effectiveParaArchive)
                                .textSelection(.enabled)
                            Text("Source: \(settings.paraArchiveSource.rawValue)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
            }

            // Custom paths section
            GroupBox("Custom Paths (optional)") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Override the default paths or environment variables:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // PARA Home
                    HStack {
                        Text("PARA Home:")
                            .frame(width: 80, alignment: .trailing)
                        TextField("Leave empty for default", text: $paraHomeText)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse...") {
                            browseForFolder { paraHomeText = $0 }
                        }
                    }

                    // Archive
                    HStack {
                        Text("Archive:")
                            .frame(width: 80, alignment: .trailing)
                        TextField("Leave empty for default", text: $paraArchiveText)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse...") {
                            browseForFolder { paraArchiveText = $0 }
                        }
                    }

                    // Validation
                    if !paraHomeText.isEmpty || !paraArchiveText.isEmpty {
                        HStack(spacing: 12) {
                            if !paraHomeText.isEmpty {
                                validationBadge(for: paraHomeText, label: "PARA Home")
                            }
                            if !paraArchiveText.isEmpty {
                                validationBadge(for: paraArchiveText, label: "Archive")
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(8)
            }

            Divider()

            // Buttons
            HStack {
                Button("Reset") {
                    paraHomeText = ""
                    paraArchiveText = ""
                    settings.paraHome = nil
                    settings.paraArchive = nil
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    settings.paraHome = paraHomeText.isEmpty ? nil : paraHomeText
                    settings.paraArchive = paraArchiveText.isEmpty ? nil : paraArchiveText
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 500)
        .fixedSize()
        .onAppear {
            paraHomeText = settings.paraHome ?? ""
            paraArchiveText = settings.paraArchive ?? ""
        }
    }

    @ViewBuilder
    private func validationBadge(for path: String, label: String) -> some View {
        let exists = directoryExists(path)
        HStack(spacing: 4) {
            Image(systemName: exists ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(exists ? .green : .orange)
            Text(exists ? "\(label) exists" : "\(label) not found")
                .font(.caption)
                .foregroundColor(exists ? .green : .orange)
        }
    }

    private func browseForFolder(completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            if path.hasPrefix(home) {
                completion("~" + path.dropFirst(home.count))
            } else {
                completion(path)
            }
        }
    }

    private func directoryExists(_ path: String) -> Bool {
        let expandedPath = NSString(string: path).expandingTildeInPath
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}

/// Window controller for settings
class SettingsWindowController: NSObject {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func showSettings() {
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "Para Settings"
        newWindow.styleMask = [.titled, .closable]
        newWindow.center()
        newWindow.isReleasedWhenClosed = false

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: newWindow,
            queue: .main
        ) { [weak self] _ in
            self?.window = nil
            NotificationCenter.default.post(name: .paraSettingsChanged, object: nil)
        }

        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension Notification.Name {
    static let paraSettingsChanged = Notification.Name("paraSettingsChanged")
}
