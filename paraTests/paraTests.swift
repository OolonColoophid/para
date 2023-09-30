//
//  paraTests.swift
//  paraTests
//
//  Created by Ian Hocking on 30/09/2023.
//

import XCTest
@testable import para  // Replace with the actual module name containing the Para code

class ParaTests: XCTestCase {

    let fileManager = FileManager.default
    var homeDir: String { fileManager.homeDirectoryForCurrentUser.path }

    func testCreateFolder() {
        let folderPath = "\(homeDir)/Documents/testCreateFolder"

        Para.createFolder(at: folderPath)
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(atPath: folderPath, isDirectory: &isDir)

        XCTAssertTrue(exists && isDir.boolValue, "Folder should be created")

        // Cleanup
        try? fileManager.removeItem(atPath: folderPath)
    }

    func testCreateFile() {
        let filePath = "\(homeDir)/Documents/testCreateFile.txt"

        Para.createFile(at: filePath, content: "Hello, world!")
        let exists = fileManager.fileExists(atPath: filePath)

        XCTAssertTrue(exists, "File should be created")

        // Cleanup
        try? fileManager.removeItem(atPath: filePath)
    }

    func testMoveToArchive() {
        // Create initial folder
        let fromPath = "\(homeDir)/Documents/testMoveToArchive"
        let toPath = "\(homeDir)/Documents/archive/testMoveToArchive"
        Para.createFolder(at: fromPath)

        Para.moveToArchive(from: fromPath, to: toPath)
        let exists = fileManager.fileExists(atPath: toPath)

        XCTAssertTrue(exists, "Folder should be moved to archive")

        // Cleanup
        try? fileManager.removeItem(atPath: fromPath)
        try? fileManager.removeItem(atPath: toPath)
    }

    func testDeleteDirectory() {
        let folderPath = "\(homeDir)/Documents/testDeleteDirectory"
        Para.createFolder(at: folderPath)

        do {
            try Para.deleteDirectory(at: folderPath)
        } catch {
            XCTFail("Should not throw an error")
        }

        let exists = fileManager.fileExists(atPath: folderPath)
        XCTAssertFalse(exists, "Folder should be deleted")

        // No cleanup necessary as folder should be deleted
    }

    static var allTests = [
        ("testCreateFolder", testCreateFolder),
        ("testCreateFile", testCreateFile),
        ("testMoveToArchive", testMoveToArchive),
        ("testDeleteDirectory", testDeleteDirectory)
    ]
}
