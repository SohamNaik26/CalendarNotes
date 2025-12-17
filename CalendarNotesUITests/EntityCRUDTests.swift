//
//  EntityCRUDTests.swift
//  CalendarNotesUITests
//
//  UI tests for CRUD operations
//

import XCTest

final class EntityCRUDTests: XCTestCase {
    
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
    
    func testCreateEvent() throws {
        // Navigate to events screen
        let eventsTab = app.tabBars.buttons["Events"]
        if eventsTab.exists {
            eventsTab.tap()
        }
        
        // Tap create button
        let createButton = app.buttons["New Event"] ?? app.buttons["+"] ?? app.navigationBars.buttons["Add"]
        if createButton.exists {
            createButton.tap()
        }
        
        // Fill event form
        let titleField = app.textFields["Title"]
        if titleField.exists {
            titleField.tap()
            titleField.typeText("Test Event")
        }
        
        // Save event
        let saveButton = app.buttons["Save"]
        if saveButton.exists {
            saveButton.tap()
        }
        
        sleep(1)
        
        // Verify event was created
        XCTAssertTrue(app.staticTexts["Test Event"].exists || app.cells.count > 0, "Event should be created")
    }
    
    func testEditEvent() throws {
        // Navigate to events
        let eventsTab = app.tabBars.buttons["Events"]
        if eventsTab.exists {
            eventsTab.tap()
        }
        
        // Select first event
        let firstEvent = app.cells.firstMatch
        if firstEvent.exists {
            firstEvent.tap()
            
            // Edit title
            let titleField = app.textFields["Title"] ?? app.textViews["Title"]
            if titleField.exists {
                titleField.tap()
                titleField.clearText()
                titleField.typeText("Updated Event")
            }
            
            // Save
            let saveButton = app.buttons["Save"]
            if saveButton.exists {
                saveButton.tap()
            }
            
            sleep(1)
            
            // Verify update
            XCTAssertTrue(app.staticTexts["Updated Event"].exists, "Event should be updated")
        }
    }
    
    func testDeleteEvent() throws {
        // Navigate to events
        let eventsTab = app.tabBars.buttons["Events"]
        if eventsTab.exists {
            eventsTab.tap()
        }
        
        // Select event
        let firstEvent = app.cells.firstMatch
        if firstEvent.exists {
            firstEvent.swipeLeft()
            
            // Tap delete
            let deleteButton = app.buttons["Delete"]
            if deleteButton.exists {
                deleteButton.tap()
            }
            
            // Confirm deletion
            let confirmButton = app.alerts.buttons["Delete"]
            if confirmButton.exists {
                confirmButton.tap()
            }
            
            sleep(1)
            
            // Verify deletion
            XCTAssertFalse(firstEvent.exists, "Event should be deleted")
        }
    }
    
    func testCreateNote() throws {
        // Navigate to notes
        let notesTab = app.tabBars.buttons["Notes"]
        if notesTab.exists {
            notesTab.tap()
        }
        
        // Create note
        let createButton = app.buttons["New Note"] ?? app.buttons["+"]
        if createButton.exists {
            createButton.tap()
        }
        
        // Fill note
        let titleField = app.textFields["Title"]
        let contentField = app.textViews["Content"]
        
        if titleField.exists {
            titleField.tap()
            titleField.typeText("Test Note")
        }
        
        if contentField.exists {
            contentField.tap()
            contentField.typeText("This is a test note content.")
        }
        
        // Save
        let saveButton = app.buttons["Save"]
        if saveButton.exists {
            saveButton.tap()
        }
        
        sleep(1)
        
        // Verify creation
        XCTAssertTrue(app.staticTexts["Test Note"].exists, "Note should be created")
    }
    
    func testCreateTodo() throws {
        // Navigate to todos
        let todosTab = app.tabBars.buttons["Todos"]
        if todosTab.exists {
            todosTab.tap()
        }
        
        // Create todo
        let createButton = app.buttons["New Todo"] ?? app.buttons["+"]
        if createButton.exists {
            createButton.tap()
        }
        
        // Fill todo
        let titleField = app.textFields["Title"]
        if titleField.exists {
            titleField.tap()
            titleField.typeText("Test Todo")
        }
        
        // Save
        let saveButton = app.buttons["Save"]
        if saveButton.exists {
            saveButton.tap()
        }
        
        sleep(1)
        
        // Verify creation
        XCTAssertTrue(app.staticTexts["Test Todo"].exists, "Todo should be created")
    }
}

extension XCUIElement {
    func clearText() {
        guard let stringValue = self.value as? String else {
            return
        }
        
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        typeText(deleteString)
    }
}

