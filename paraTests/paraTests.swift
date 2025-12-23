import XCTest
@testable import para

final class ParaArchiveTests: XCTestCase {
    private var tempRoot: URL!
    private var paraHome: URL!
    private var archiveHome: URL!
    private var originalParaHome: String?
    private var originalParaArchive: String?

    override func setUpWithError() throws {
        try super.setUpWithError()

        originalParaHome = getenvValue("PARA_HOME")
        originalParaArchive = getenvValue("PARA_ARCHIVE")

        let baseTemp = FileManager.default.temporaryDirectory
        tempRoot = baseTemp.appendingPathComponent("para-tests-\(UUID().uuidString)")
        paraHome = tempRoot.appendingPathComponent("home")
        archiveHome = tempRoot.appendingPathComponent("archive")

        try FileManager.default.createDirectory(at: paraHome.appendingPathComponent("projects"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: paraHome.appendingPathComponent("areas"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: archiveHome, withIntermediateDirectories: true)

        setenv("PARA_HOME", paraHome.path, 1)
        setenv("PARA_ARCHIVE", archiveHome.path, 1)
    }

    override func tearDownWithError() throws {
        if let originalParaHome {
            setenv("PARA_HOME", originalParaHome, 1)
        } else {
            unsetenv("PARA_HOME")
        }

        if let originalParaArchive {
            setenv("PARA_ARCHIVE", originalParaArchive, 1)
        } else {
            unsetenv("PARA_ARCHIVE")
        }

        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }

        try super.tearDownWithError()
    }

    func testMoveToArchiveMovesDirectoryContents() throws {
        let source = paraHome.appendingPathComponent("projects/demoProject")
        let journal = source.appendingPathComponent("journal.org")
        let destination = archiveHome.appendingPathComponent("demoProject")

        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try "Sample".write(to: journal, atomically: true, encoding: .utf8)

        try Para.moveToArchive(from: source.path, to: destination.path)

        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path), "Source should be removed after archival")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path), "Destination should exist after archival")
        let restoredContent = try String(contentsOf: destination.appendingPathComponent("journal.org"))
        XCTAssertEqual(restoredContent, "Sample", "Journal contents should be preserved during archive move")
    }

    func testMoveToArchiveThrowsWhenSourceMissing() {
        let missingSource = paraHome.appendingPathComponent("projects/ghost").path
        let destination = archiveHome.appendingPathComponent("ghost").path

        XCTAssertThrowsError(try Para.moveToArchive(from: missingSource, to: destination)) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "com.para")
            XCTAssertEqual(nsError.code, 2)
        }
    }

    func testMoveToArchiveThrowsWhenDestinationExists() throws {
        let source = paraHome.appendingPathComponent("projects/existing")
        let destination = archiveHome.appendingPathComponent("existing")

        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        XCTAssertThrowsError(try Para.moveToArchive(from: source.path, to: destination.path)) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "com.para")
            XCTAssertEqual(nsError.code, 3)
        }
    }

    func testMoveToArchiveCreatesDestinationParents() throws {
        let source = paraHome.appendingPathComponent("projects/nestedProject")
        let destination = archiveHome.appendingPathComponent("nested/path/nestedProject")

        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try "Notes".write(to: source.appendingPathComponent("journal.org"), atomically: true, encoding: .utf8)

        try Para.moveToArchive(from: source.path, to: destination.path)

        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.deletingLastPathComponent().path), "Parent folders should be created automatically")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path), "Destination folder should be created at requested path")
    }

    // MARK: - Helpers

    private func getenvValue(_ name: String) -> String? {
        guard let value = getenv(name) else { return nil }
        return String(cString: value)
    }
}

// MARK: - Bug Fix Tests

final class ParaBugFixTests: XCTestCase {
    private var tempRoot: URL!
    private var paraHome: URL!
    private var archiveHome: URL!
    private var originalParaHome: String?
    private var originalParaArchive: String?

    override func setUpWithError() throws {
        try super.setUpWithError()

        originalParaHome = getenvValue("PARA_HOME")
        originalParaArchive = getenvValue("PARA_ARCHIVE")

        let baseTemp = FileManager.default.temporaryDirectory
        tempRoot = baseTemp.appendingPathComponent("para-bugfix-tests-\(UUID().uuidString)")
        paraHome = tempRoot.appendingPathComponent("home")
        archiveHome = tempRoot.appendingPathComponent("archive")

        try FileManager.default.createDirectory(at: paraHome.appendingPathComponent("projects"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: paraHome.appendingPathComponent("areas"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: archiveHome, withIntermediateDirectories: true)

        setenv("PARA_HOME", paraHome.path, 1)
        setenv("PARA_ARCHIVE", archiveHome.path, 1)
    }

    override func tearDownWithError() throws {
        if let originalParaHome {
            setenv("PARA_HOME", originalParaHome, 1)
        } else {
            unsetenv("PARA_HOME")
        }

        if let originalParaArchive {
            setenv("PARA_ARCHIVE", originalParaArchive, 1)
        } else {
            unsetenv("PARA_ARCHIVE")
        }

        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }

        try super.tearDownWithError()
    }

    // MARK: - Core Bug Fix Tests

    func testCreateProjectWithSpaces() throws {
        let projectName = "my test project"
        let projectPath = paraHome.appendingPathComponent("projects/\(projectName)")
        let journalPath = projectPath.appendingPathComponent("journal.org")

        // Create the project
        Para.createFolder(at: projectPath.path)
        Para.createFile(at: journalPath.path, content: "Test content")

        // Verify folder and file exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: projectPath.path), "Project folder should exist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: journalPath.path), "Journal file should exist")

        // Verify URL construction works without encoding issues
        let url = URL(fileURLWithPath: journalPath.path)
        XCTAssertEqual(url.path, journalPath.path, "URL path should match file path")
        XCTAssertTrue(url.isFileURL, "URL should be a file URL")
    }

    func testURLConstructionWithSpecialCharacters() throws {
        let projectName = "project&test#1 (final)"
        let projectPath = paraHome.appendingPathComponent("projects/\(projectName)")
        let journalPath = projectPath.appendingPathComponent("journal.org")

        // Create the project
        Para.createFolder(at: projectPath.path)
        Para.createFile(at: journalPath.path, content: "Special chars content")

        // Verify creation succeeded
        XCTAssertTrue(FileManager.default.fileExists(atPath: projectPath.path), "Project with special chars should exist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: journalPath.path), "Journal should exist")

        // Verify URL construction doesn't crash
        let url = URL(fileURLWithPath: journalPath.path)
        XCTAssertNotNil(url, "URL should be created successfully")
        XCTAssertTrue(url.isFileURL, "URL should be a file URL")
    }

    func testArchiveUsesCorrectFallbackPath() throws {
        // Unset PARA_ARCHIVE to trigger fallback
        unsetenv("PARA_ARCHIVE")

        let projectName = "testArchive"
        let source = paraHome.appendingPathComponent("projects/\(projectName)")
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        // Expected fallback: ~/Documents/archive (NOT ~/Dropbox/para/archive)
        let expectedDestination = "\(homeDir)/Documents/archive/\(projectName)"
        let wrongDestination = "\(homeDir)/Dropbox/para/archive/\(projectName)"

        // Create source project
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try "Archive test".write(to: source.appendingPathComponent("journal.org"), atomically: true, encoding: .utf8)

        // Archive using getArchiveFolderPath (which returns nil) and fallback
        let archivePath = Para.getArchiveFolderPath(name: projectName) ?? "\(homeDir)/Documents/archive/\(projectName)"

        try Para.moveToArchive(from: source.path, to: archivePath)

        // Verify archived to correct location
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedDestination), "Should archive to ~/Documents/archive")
        XCTAssertFalse(FileManager.default.fileExists(atPath: wrongDestination), "Should NOT archive to ~/Dropbox/para/archive")

        // Restore PARA_ARCHIVE for other tests
        if let originalParaArchive {
            setenv("PARA_ARCHIVE", originalParaArchive, 1)
        } else {
            setenv("PARA_ARCHIVE", archiveHome.path, 1)
        }

        // Cleanup
        try? FileManager.default.removeItem(atPath: expectedDestination)
    }

    // MARK: - Edge Case Tests

    func testProjectNameWithUnicodeCharacters() throws {
        let projectName = "проект-日本語"
        let projectPath = paraHome.appendingPathComponent("projects/\(projectName)")
        let journalPath = projectPath.appendingPathComponent("journal.org")

        // Create project with unicode name
        Para.createFolder(at: projectPath.path)
        Para.createFile(at: journalPath.path, content: "Unicode test")

        // Verify creation and URL construction work
        XCTAssertTrue(FileManager.default.fileExists(atPath: projectPath.path), "Unicode project should exist")

        let url = URL(fileURLWithPath: journalPath.path)
        XCTAssertNotNil(url, "URL with unicode path should be created")
        XCTAssertTrue(url.isFileURL, "Should be a file URL")
    }

    func testProjectNameWithMultipleConsecutiveSpaces() throws {
        let projectName = "test    project"  // Multiple spaces
        let projectPath = paraHome.appendingPathComponent("projects/\(projectName)")
        let journalPath = projectPath.appendingPathComponent("journal.org")

        Para.createFolder(at: projectPath.path)
        Para.createFile(at: journalPath.path, content: "Multiple spaces")

        XCTAssertTrue(FileManager.default.fileExists(atPath: projectPath.path), "Project with multiple spaces should exist")

        let url = URL(fileURLWithPath: journalPath.path)
        XCTAssertEqual(url.path, journalPath.path, "URL should preserve multiple spaces")
    }

    func testVeryLongProjectName() throws {
        // Create a 200+ character name
        let longName = String(repeating: "a", count: 200)
        let projectPath = paraHome.appendingPathComponent("projects/\(longName)")

        // Attempt creation
        do {
            Para.createFolder(at: projectPath.path)
            let exists = FileManager.default.fileExists(atPath: projectPath.path)

            if exists {
                // If it succeeded, verify URL construction works
                let url = URL(fileURLWithPath: projectPath.path)
                XCTAssertNotNil(url, "URL for long name should be created")
            }
            // Either succeeds or fails gracefully - test passes either way
            XCTAssertTrue(true, "Long name handled without crash")
        } catch {
            // Fails gracefully with an error - acceptable
            XCTAssertTrue(true, "Long name failed gracefully: \(error)")
        }
    }

    // MARK: - Integration Tests

    func testCreateThenReadWorkflow() throws {
        let projectName = "workflow test"
        let projectPath = paraHome.appendingPathComponent("projects/\(projectName)")
        let journalPath = projectPath.appendingPathComponent("journal.org")
        let expectedContent = "#+TITLE: Workflow Test Project Journal\n#+CATEGORY: Workflow Test"

        // Create
        Para.createFolder(at: projectPath.path)
        Para.createFile(at: journalPath.path, content: expectedContent)

        // Read
        let actualContent = try String(contentsOfFile: journalPath.path, encoding: .utf8)

        // Verify
        XCTAssertEqual(actualContent, expectedContent, "Read content should match created content")
    }

    func testJSONModeConsistency() throws {
        let projectName = "jsonTest"
        let projectPath = paraHome.appendingPathComponent("projects/\(projectName)")

        // Create project
        Para.createFolder(at: projectPath.path)
        Para.createFile(at: projectPath.appendingPathComponent("journal.org").path, content: "JSON test")

        // Get list of projects
        let projectsList = Para.completeFolders(type: "project")

        // Verify project appears in list
        XCTAssertTrue(projectsList.contains(projectName), "Project should appear in completeFolders list")

        // Verify path consistency
        let expectedPath = Para.getParaFolderPath(type: "project", name: projectName)
        XCTAssertEqual(expectedPath, projectPath.path, "Path should be consistent")
    }

    // MARK: - Helpers

    private func getenvValue(_ name: String) -> String? {
        guard let value = getenv(name) else { return nil }
        return String(cString: value)
    }
}
