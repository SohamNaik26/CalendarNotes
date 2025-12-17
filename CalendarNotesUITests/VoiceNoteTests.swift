//
//  VoiceNoteTests.swift
//  CalendarNotesUITests
//
//  UI tests for voice note recording
//

import XCTest

final class VoiceNoteTests: XCTestCase {
    
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
    
    func testVoiceNoteRecording() throws {
        // Navigate to voice notes
        let voiceNotesTab = app.tabBars.buttons["Voice Notes"]
        if voiceNotesTab.exists {
            voiceNotesTab.tap()
        }
        
        // Tap record button
        let recordButton = app.buttons["Record"] ?? app.buttons["Start Recording"]
        if recordButton.exists {
            recordButton.tap()
            
            // Wait for recording to start
            sleep(2)
            
            // Stop recording
            let stopButton = app.buttons["Stop"] ?? app.buttons["Stop Recording"]
            if stopButton.exists {
                stopButton.tap()
            }
            
            sleep(1)
            
            // Verify recording was created
            XCTAssertTrue(app.cells.count > 0 || app.staticTexts.matching(identifier: "Voice Note").count > 0, "Voice note should be recorded")
        }
    }
    
    func testVoiceNotePlayback() throws {
        // Navigate to voice notes
        let voiceNotesTab = app.tabBars.buttons["Voice Notes"]
        if voiceNotesTab.exists {
            voiceNotesTab.tap()
        }
        
        // Select a voice note
        let firstNote = app.cells.firstMatch
        if firstNote.exists {
            firstNote.tap()
            
            // Tap play button
            let playButton = app.buttons["Play"]
            if playButton.exists {
                playButton.tap()
                
                sleep(1)
                
                // Verify playback started
                let pauseButton = app.buttons["Pause"]
                XCTAssertTrue(pauseButton.exists, "Playback should start")
            }
        }
    }
    
    func testVoiceNoteTranscription() throws {
        // Navigate to voice notes
        let voiceNotesTab = app.tabBars.buttons["Voice Notes"]
        if voiceNotesTab.exists {
            voiceNotesTab.tap()
        }
        
        // Select a voice note
        let firstNote = app.cells.firstMatch
        if firstNote.exists {
            firstNote.tap()
            
            // Tap transcribe button
            let transcribeButton = app.buttons["Transcribe"]
            if transcribeButton.exists {
                transcribeButton.tap()
                
                // Wait for transcription
                sleep(5)
                
                // Verify transcription is displayed
                let transcriptionText = app.textViews["Transcription"] ?? app.staticTexts.matching(identifier: "Transcription").firstMatch
                XCTAssertTrue(transcriptionText.exists, "Transcription should be displayed")
            }
        }
    }
}

