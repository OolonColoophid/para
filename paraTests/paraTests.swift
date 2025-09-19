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
