//
//  FileWatcher.swift
//  ParaMenuBar
//
//  Monitors file system changes and triggers refreshes.
//

import Foundation
import ParaKit

class FileWatcher: ObservableObject {
    private var sources: [DispatchSourceFileSystemObject] = []
    private let paraManager: ParaManager
    private var refreshTimer: Timer?

    init(paraManager: ParaManager) {
        self.paraManager = paraManager
        startWatching()
    }

    deinit {
        stopWatching()
    }

    func startWatching() {
        // Paths to monitor
        let paths = [
            ParaEnvironment.projectsPath,
            ParaEnvironment.areasPath
        ]

        for path in paths {
            // Open file descriptor for directory
            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else {
                print("Failed to open \(path) for monitoring")
                continue
            }

            // Create dispatch source for file system events
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .delete, .rename, .extend],
                queue: .main
            )

            source.setEventHandler { [weak self] in
                // Debounce rapid changes
                self?.scheduleRefresh()
            }

            source.setCancelHandler {
                // Close file descriptor when cancelled
                close(fd)
            }

            source.resume()
            sources.append(source)
        }
    }

    func stopWatching() {
        for source in sources {
            source.cancel()
        }
        sources.removeAll()
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func scheduleRefresh() {
        // Cancel existing timer
        refreshTimer?.invalidate()

        // Schedule new refresh after 500ms delay (debouncing)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.paraManager.refresh()
        }
    }
}
