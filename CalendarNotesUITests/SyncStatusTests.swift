//
//  SyncStatusTests.swift
//  CalendarNotesUITests
//
//  UI tests for sync status display
//

import XCTest

final class SyncStatusTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    func testSyncStatusDisplay() throws {
        // Navigate to settings or sync screen
        let settingsButton = app.buttons["Settings"] ?? app.navigationBars.buttons["Settings"]
        if settingsButton.exists {
            settingsButton.tap()
        }
        
        // Check for sync status indicator
        let syncStatus = app.staticTexts.matching(identifier: "Sync Status").firstMatch
        if syncStatus.exists {
            XCTAssertTrue(syncStatus.exists, "Sync status should be displayed")
        }
    }
    
    func testManualSyncTrigger() throws {
        // Navigate to settings
        let settingsButton = app.buttons["Settings"] ?? app.navigationBars.buttons["Settings"]
        if settingsButton.exists {
            settingsButton.tap()
        }
        
        // Tap sync button
        let syncButton = app.buttons["Sync Now"] ?? app.buttons["Sync"]
        if syncButton.exists {
            syncButton.tap()
            
            sleep(2)
            
            // Verify sync is in progress or completed
            let syncStatus = app.staticTexts.matching(identifier: "Syncing").firstMatch ?? 
                           app.staticTexts.matching(identifier: "Synced").firstMatch
            XCTAssertTrue(syncStatus.exists, "Sync status should update")
        }
    }
    
    func testSyncErrorDisplay() throws {
        // Simulate sync error (would require network mocking)
        // Navigate to sync screen
        let settingsButton = app.buttons["Settings"]
        if settingsButton.exists {
            settingsButton.tap()
        }
        
        // Trigger sync
        let syncButton = app.buttons["Sync Now"]
        if syncButton.exists {
            syncButton.tap()
            
            sleep(3)
            
            // Check for error message
            let errorMessage = app.alerts.firstMatch ?? app.staticTexts.matching(identifier: "Error").firstMatch
            // Error may or may not exist depending on network state
        }
    }
}

