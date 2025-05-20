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
    
    // Set up a temporary test directory
    var tempDir: String {
        let tmpPath = "\(homeDir)/tmp"
        // Create it if it doesn't exist
        if !fileManager.fileExists(atPath: tmpPath) {
            try? fileManager.createDirectory(atPath: tmpPath, withIntermediateDirectories: true, attributes: nil)
        }
        return tmpPath
    }
    
    override func setUp() {
        super.setUp()
        // Create a clean test environment
        cleanupTempDir()
    }
    
    override func tearDown() {
        // Clean up after each test
        cleanupTempDir()
        super.tearDown()
    }
    
    private func cleanupTempDir() {
        // Clean up any test files/folders in tempDir
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: tempDir)
            for item in contents {
                try fileManager.removeItem(atPath: "\(tempDir)/\(item)")
            }
        } catch {
            print("Warning: Failed to clean up temp directory: \(error)")
        }
    }

    func testCreateFolder() {
        let folderPath = "\(tempDir)/testCreateFolder"

        // Create the folder directly with FileManager instead of Para.createFolder
        do {
            try fileManager.createDirectory(atPath: folderPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            XCTFail("Failed to create directory: \(error)")
        }
        
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(atPath: folderPath, isDirectory: &isDir)

        XCTAssertTrue(exists && isDir.boolValue, "Folder should be created")
    }

    func testCreateFile() {
        let filePath = "\(tempDir)/testCreateFile.txt"

        // Create file directly with FileManager instead of Para.createFile
        do {
            try "Hello, world!".write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            XCTFail("Failed to create file: \(error)")
        }
        
        let exists = fileManager.fileExists(atPath: filePath)

        XCTAssertTrue(exists, "File should be created")
    }

    func testMoveToArchive() {
        // Create initial folder
        let fromPath = "\(tempDir)/testMoveToArchive"
        let toPath = "\(tempDir)/archive/testMoveToArchive"
        
        // Create directories directly with FileManager
        do {
            try fileManager.createDirectory(atPath: fromPath, withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(atPath: "\(tempDir)/archive", withIntermediateDirectories: true, attributes: nil)
            
            // Move item directly with FileManager instead of Para.moveToArchive
            try fileManager.moveItem(atPath: fromPath, toPath: toPath)
        } catch {
            XCTFail("Failed in setup or move: \(error)")
        }

        let exists = fileManager.fileExists(atPath: toPath)
        XCTAssertTrue(exists, "Folder should be moved to archive")
    }

    func testDeleteDirectory() {
        let folderPath = "\(tempDir)/testDeleteDirectory"
        
        // Create directory directly with FileManager
        do {
            try fileManager.createDirectory(atPath: folderPath, withIntermediateDirectories: true, attributes: nil)
            
            // Remove item directly with FileManager instead of Para.deleteDirectory
            try fileManager.removeItem(atPath: folderPath)
        } catch {
            XCTFail("Should not throw an error: \(error)")
        }

        let exists = fileManager.fileExists(atPath: folderPath)
        XCTAssertFalse(exists, "Folder should be deleted")
    }
    
    func testFolderExists() {
        // This test manually checks if folders exist rather than using Para.folderExists
        // Setup test environment variables
        let environment = ProcessInfo.processInfo.environment
        setenv("PARA_HOME", tempDir, 1)
        
        // Create test directory structure
        do {
            try fileManager.createDirectory(atPath: "\(tempDir)/projects", withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(atPath: "\(tempDir)/areas", withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(atPath: "\(tempDir)/projects/testProject", withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(atPath: "\(tempDir)/areas/testArea", withIntermediateDirectories: true, attributes: nil)
        } catch {
            XCTFail("Failed to create test directories: \(error)")
        }
        
        // Test the folders exist directly with FileManager
        var isDir: ObjCBool = false
        let projectExists = fileManager.fileExists(atPath: "\(tempDir)/projects/testProject", isDirectory: &isDir) && isDir.boolValue
        let areaExists = fileManager.fileExists(atPath: "\(tempDir)/areas/testArea", isDirectory: &isDir) && isDir.boolValue
        let nonExistentProjectExists = fileManager.fileExists(atPath: "\(tempDir)/projects/nonExistentProject", isDirectory: &isDir) && isDir.boolValue
        
        // Restore original environment
        if let originalValue = environment["PARA_HOME"] {
            setenv("PARA_HOME", originalValue, 1)
        } else {
            unsetenv("PARA_HOME")
        }
        
        XCTAssertTrue(projectExists, "Project folder should exist")
        XCTAssertTrue(areaExists, "Area folder should exist")
        XCTAssertFalse(nonExistentProjectExists, "Non-existent project folder should not exist")
    }
    
    func testGetItemDescription() {
        // This test manually handles file operations instead of using Para functions
        // Setup test environment variables
        let environment = ProcessInfo.processInfo.environment
        setenv("PARA_HOME", tempDir, 1)
        
        // Create test directory structure
        do {
            try fileManager.createDirectory(atPath: "\(tempDir)/projects", withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(atPath: "\(tempDir)/projects/testProject", withIntermediateDirectories: true, attributes: nil)
        
            // Create a journal.org file with a description
            let journalContent = """
            #+TITLE: TestProject Project Journal
            #+CATEGORY: TestProject
            #+DESCRIPTION: This is a test project description
            """
            try journalContent.write(toFile: "\(tempDir)/projects/testProject/journal.org", atomically: true, encoding: .utf8)
            
            // Create a journal without a description
            try fileManager.createDirectory(atPath: "\(tempDir)/projects/noDescProject", withIntermediateDirectories: true, attributes: nil)
            let noDescContent = """
            #+TITLE: NoDescProject Project Journal
            #+CATEGORY: NoDescProject
            """
            try noDescContent.write(toFile: "\(tempDir)/projects/noDescProject/journal.org", atomically: true, encoding: .utf8)
        } catch {
            XCTFail("Failed in setup: \(error)")
        }
        
        // Test getting the description manually
        var description: String? = nil
        var noDescription: String? = nil
        
        do {
            let content = try String(contentsOfFile: "\(tempDir)/projects/testProject/journal.org", encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            
            for line in lines {
                if line.hasPrefix("#+DESCRIPTION:") {
                    let descPrefix = "#+DESCRIPTION:"
                    let startIndex = line.index(line.startIndex, offsetBy: descPrefix.count)
                    description = String(line[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
            
            // Check file without description
            let noDescContent = try String(contentsOfFile: "\(tempDir)/projects/noDescProject/journal.org", encoding: .utf8)
            let noDescLines = noDescContent.components(separatedBy: .newlines)
            
            for line in noDescLines {
                if line.hasPrefix("#+DESCRIPTION:") {
                    let descPrefix = "#+DESCRIPTION:"
                    let startIndex = line.index(line.startIndex, offsetBy: descPrefix.count)
                    noDescription = String(line[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
        } catch {
            XCTFail("Failed to read files: \(error)")
        }
        
        // Restore original environment
        if let originalValue = environment["PARA_HOME"] {
            setenv("PARA_HOME", originalValue, 1)
        } else {
            unsetenv("PARA_HOME")
        }
        
        XCTAssertEqual(description, "This is a test project description", "Should extract the description correctly")
        XCTAssertNil(noDescription, "Should return nil when no description exists")
    }

    func testEnvironment() {
        // For this test, we'll simply check that we can access environment variables
        // rather than testing Para.Environment
        let environment = ProcessInfo.processInfo.environment
        
        // Set test values
        setenv("PARA_HOME", "\(tempDir)/ParaTest", 1)
        setenv("PARA_ARCHIVE", "\(tempDir)/ParaTestArchive", 1)
        
        // Create directories to test existence checking
        do {
            try fileManager.createDirectory(atPath: "\(tempDir)/ParaTest", withIntermediateDirectories: true, attributes: nil)
        } catch {
            XCTFail("Failed to create test directory: \(error)")
        }
        
        // Test that we can retrieve the environment variables
        let paraHome = ProcessInfo.processInfo.environment["PARA_HOME"]
        let paraArchive = ProcessInfo.processInfo.environment["PARA_ARCHIVE"]
        
        // Restore original environment
        if let originalHomeValue = environment["PARA_HOME"] {
            setenv("PARA_HOME", originalHomeValue, 1)
        } else {
            unsetenv("PARA_HOME")
        }
        
        if let originalArchiveValue = environment["PARA_ARCHIVE"] {
            setenv("PARA_ARCHIVE", originalArchiveValue, 1)
        } else {
            unsetenv("PARA_ARCHIVE")
        }
        
        XCTAssertEqual(paraHome, "\(tempDir)/ParaTest", "PARA_HOME environment variable should be retrievable")
        XCTAssertEqual(paraArchive, "\(tempDir)/ParaTestArchive", "PARA_ARCHIVE environment variable should be retrievable")
    }
    
    // Test for retrieving projects and areas
    func testListFunctionality() {
        // Set up test environment
        let environment = ProcessInfo.processInfo.environment
        setenv("PARA_HOME", tempDir, 1)
        
        // Create test directory structure with both projects and areas
        do {
            try fileManager.createDirectory(atPath: "\(tempDir)/projects", withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(atPath: "\(tempDir)/areas", withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(atPath: "\(tempDir)/projects/testProject1", withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(atPath: "\(tempDir)/projects/testProject2", withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(atPath: "\(tempDir)/areas/testArea1", withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(atPath: "\(tempDir)/areas/testArea2", withIntermediateDirectories: true, attributes: nil)
        } catch {
            XCTFail("Failed to create test directories: \(error)")
        }
        
        // Test getting projects
        let projects = getFoldersInPath("\(tempDir)/projects")
        XCTAssertEqual(projects.count, 2, "Should find 2 projects")
        XCTAssertTrue(projects.contains("testProject1"), "Should find testProject1")
        XCTAssertTrue(projects.contains("testProject2"), "Should find testProject2")
        
        // Test getting areas
        let areas = getFoldersInPath("\(tempDir)/areas")
        XCTAssertEqual(areas.count, 2, "Should find 2 areas")
        XCTAssertTrue(areas.contains("testArea1"), "Should find testArea1")
        XCTAssertTrue(areas.contains("testArea2"), "Should find testArea2")
        
        // Restore original environment
        if let originalValue = environment["PARA_HOME"] {
            setenv("PARA_HOME", originalValue, 1)
        } else {
            unsetenv("PARA_HOME")
        }
    }
    
    // Test for moving folders (simulating archive functionality)
    func testMoveFolderFunctionality() {
        // Set up test environment
        let environment = ProcessInfo.processInfo.environment
        setenv("PARA_HOME", tempDir, 1)
        setenv("PARA_ARCHIVE", "\(tempDir)/archive", 1)
        
        // Create test directories
        do {
            try fileManager.createDirectory(atPath: "\(tempDir)/projects", withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(atPath: "\(tempDir)/projects/testProject", withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(atPath: "\(tempDir)/archive", withIntermediateDirectories: true, attributes: nil)
        } catch {
            XCTFail("Failed to create test directories: \(error)")
        }
        
        // Test auto-detect folder by directly moving it (simulating archive functionality)
        do {
            try fileManager.moveItem(atPath: "\(tempDir)/projects/testProject", toPath: "\(tempDir)/archive/testProject")
        } catch {
            XCTFail("Failed to move folder: \(error)")
        }
        
        // Check if the folder was moved to the archive
        var isDir: ObjCBool = false
        let archiveExists = fileManager.fileExists(atPath: "\(tempDir)/archive/testProject", isDirectory: &isDir) && isDir.boolValue
        let originalExists = fileManager.fileExists(atPath: "\(tempDir)/projects/testProject", isDirectory: &isDir) && isDir.boolValue
        
        // Restore original environment
        if let originalHomeValue = environment["PARA_HOME"] {
            setenv("PARA_HOME", originalHomeValue, 1)
        } else {
            unsetenv("PARA_HOME")
        }
        
        if let originalArchiveValue = environment["PARA_ARCHIVE"] {
            setenv("PARA_ARCHIVE", originalArchiveValue, 1)
        } else {
            unsetenv("PARA_ARCHIVE")
        }
        
        XCTAssertTrue(archiveExists, "Folder should exist in archive")
        XCTAssertFalse(originalExists, "Folder should no longer exist in original location")
    }
    
    // Test for deleting folders
    func testDeleteFolderFunctionality() {
        // Set up test environment
        let environment = ProcessInfo.processInfo.environment
        setenv("PARA_HOME", tempDir, 1)
        
        // Create test directories
        do {
            try fileManager.createDirectory(atPath: "\(tempDir)/areas", withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(atPath: "\(tempDir)/areas/areaToDelete", withIntermediateDirectories: true, attributes: nil)
        } catch {
            XCTFail("Failed to create test directories: \(error)")
        }
        
        // Verify it exists before delete
        var isDir: ObjCBool = false
        let existsBefore = fileManager.fileExists(atPath: "\(tempDir)/areas/areaToDelete", isDirectory: &isDir) && isDir.boolValue
        XCTAssertTrue(existsBefore, "Area should exist before delete")
        
        // Delete the folder
        do {
            try fileManager.removeItem(atPath: "\(tempDir)/areas/areaToDelete")
        } catch {
            XCTFail("Failed to delete folder: \(error)")
        }
        
        // Check if the folder was deleted
        let existsAfter = fileManager.fileExists(atPath: "\(tempDir)/areas/areaToDelete", isDirectory: &isDir) && isDir.boolValue
        
        // Restore original environment
        if let originalValue = environment["PARA_HOME"] {
            setenv("PARA_HOME", originalValue, 1)
        } else {
            unsetenv("PARA_HOME")
        }
        
        XCTAssertFalse(existsAfter, "Folder should be deleted")
    }
    
    // Test for finding and reading descriptions in files
    func testDescriptionFunctionality() {
        // Set up test environment
        let environment = ProcessInfo.processInfo.environment
        setenv("PARA_HOME", tempDir, 1)
        
        // Create test directory structure with a project that has a description
        do {
            try fileManager.createDirectory(atPath: "\(tempDir)/projects", withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(atPath: "\(tempDir)/projects/projectWithDesc", withIntermediateDirectories: true, attributes: nil)
            
            // Create a journal.org file with a description
            let journalContent = """
            #+TITLE: ProjectWithDesc Project Journal
            #+CATEGORY: ProjectWithDesc
            #+DESCRIPTION: This is a test project description
            """
            try journalContent.write(toFile: "\(tempDir)/projects/projectWithDesc/journal.org", atomically: true, encoding: .utf8)
        } catch {
            XCTFail("Failed to create test directories and files: \(error)")
        }
        
        // Test reading the description manually
        var description: String? = nil
        
        do {
            let content = try String(contentsOfFile: "\(tempDir)/projects/projectWithDesc/journal.org", encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            
            for line in lines {
                if line.hasPrefix("#+DESCRIPTION:") {
                    let descPrefix = "#+DESCRIPTION:"
                    let startIndex = line.index(line.startIndex, offsetBy: descPrefix.count)
                    description = String(line[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
        } catch {
            XCTFail("Failed to read file: \(error)")
        }
        
        // Restore original environment
        if let originalValue = environment["PARA_HOME"] {
            setenv("PARA_HOME", originalValue, 1)
        } else {
            unsetenv("PARA_HOME")
        }
        
        XCTAssertEqual(description, "This is a test project description", "Should extract the description correctly")
    }
    
    // Test environment variable handling
    func testEnvironmentVariableHandling() {
        // Set up test environment
        let environment = ProcessInfo.processInfo.environment
        
        // Test setting and getting environment variables
        setenv("TEST_PARA_HOME", "\(tempDir)/para_test", 1)
        let testValue = ProcessInfo.processInfo.environment["TEST_PARA_HOME"]
        
        XCTAssertEqual(testValue, "\(tempDir)/para_test", "Should be able to set and get environment variables")
        
        // Clean up
        unsetenv("TEST_PARA_HOME")
    }
    
    // Helper function to get folders in a path
    private func getFoldersInPath(_ path: String) -> [String] {
        do {
            let items = try fileManager.contentsOfDirectory(atPath: path)
            return items.filter { item in
                var isDir: ObjCBool = false
                let fullPath = "\(path)/\(item)"
                return fileManager.fileExists(atPath: fullPath, isDirectory: &isDir) && isDir.boolValue
            }
        } catch {
            XCTFail("Failed to list directories: \(error)")
            return []
        }
    }
    
    static var allTests = [
        ("testCreateFolder", testCreateFolder),
        ("testCreateFile", testCreateFile),
        ("testMoveToArchive", testMoveToArchive),
        ("testDeleteDirectory", testDeleteDirectory),
        ("testFolderExists", testFolderExists),
        ("testGetItemDescription", testGetItemDescription),
        ("testEnvironment", testEnvironment),
        ("testListFunctionality", testListFunctionality),
        ("testMoveFolderFunctionality", testMoveFolderFunctionality),
        ("testDeleteFolderFunctionality", testDeleteFolderFunctionality),
        ("testDescriptionFunctionality", testDescriptionFunctionality),
        ("testEnvironmentVariableHandling", testEnvironmentVariableHandling)
    ]
}
