//
//  NewItemView.swift
//  ParaMenuBar
//
//  Dialog for creating new projects and areas.
//

import SwiftUI
import ParaKit

struct NewItemView: View {
    let itemType: ParaItemType
    let paraManager: ParaManager
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var openAfterCreating: Bool = true
    @State private var errorMessage: String?
    @FocusState private var isNameFocused: Bool

    private var typeName: String {
        itemType == .project ? "Project" : "Area"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Image(systemName: itemType == .project ? "folder.badge.plus" : "hexagon.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                Text("New \(typeName)")
                    .font(.headline)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Form
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("Enter \(typeName.lowercased()) name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .focused($isNameFocused)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Description:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("Optional short description", text: $description)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            createItem()
                        }
                }

                Toggle("Open after creating", isOn: $openAfterCreating)
                    .toggleStyle(.checkbox)

                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.red)
                    }
                    .font(.caption)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Buttons
            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    createItem()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(20)
        }
        .frame(width: 320, height: 310)
        .onAppear {
            isNameFocused = true
        }
    }

    private func createItem() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let trimmedDescription = description.trimmingCharacters(in: .whitespaces)

        do {
            _ = try paraManager.createItem(
                type: itemType,
                name: trimmedName,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                open: openAfterCreating
            )
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Window controller for new item creation
class NewItemWindowController: NSObject {
    static let shared = NewItemWindowController()

    private var window: NSWindow?

    func showNewItem(type: ParaItemType, paraManager: ParaManager) {
        // Close existing window if any
        window?.close()
        window = nil

        let view = NewItemView(itemType: type, paraManager: paraManager) { [weak self] in
            self?.window?.close()
            self?.window = nil
        }

        let hostingController = NSHostingController(rootView: view)

        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "New \(type == .project ? "Project" : "Area")"
        newWindow.styleMask = [.titled, .closable]
        newWindow.center()
        newWindow.isReleasedWhenClosed = false

        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
