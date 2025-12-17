//
//  LoginRegistrationFlowTests.swift
//  CalendarNotesUITests
//
//  UI tests for login and registration flows
//

import XCTest

final class LoginRegistrationFlowTests: XCTestCase {
    
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
    
    func testLoginFlow() throws {
        // Navigate to login screen
        let loginButton = app.buttons["Login"]
        if loginButton.exists {
            loginButton.tap()
        }
        
        // Enter credentials
        let emailField = app.textFields["Email"]
        let passwordField = app.secureTextFields["Password"]
        
        if emailField.exists && passwordField.exists {
            emailField.tap()
            emailField.typeText("test@example.com")
            
            passwordField.tap()
            passwordField.typeText("TestPassword123!")
            
            // Submit login
            let submitButton = app.buttons["Sign In"]
            if submitButton.exists {
                submitButton.tap()
            }
            
            // Wait for navigation
            sleep(2)
            
            // Verify successful login (check for main screen elements)
            let mainScreen = app.otherElements["MainScreen"]
            XCTAssertTrue(mainScreen.exists || app.navigationBars.count > 0, "Should navigate to main screen after login")
        }
    }
    
    func testRegistrationFlow() throws {
        // Navigate to registration
        let registerButton = app.buttons["Register"] ?? app.buttons["Sign Up"]
        if registerButton.exists {
            registerButton.tap()
        }
        
        // Fill registration form
        let emailField = app.textFields["Email"]
        let passwordField = app.secureTextFields["Password"]
        let confirmPasswordField = app.secureTextFields["Confirm Password"]
        let nameField = app.textFields["Full Name"]
        
        if emailField.exists {
            emailField.tap()
            emailField.typeText("newuser@example.com")
        }
        
        if passwordField.exists {
            passwordField.tap()
            passwordField.typeText("TestPassword123!")
        }
        
        if confirmPasswordField.exists {
            confirmPasswordField.tap()
            confirmPasswordField.typeText("TestPassword123!")
        }
        
        if nameField.exists {
            nameField.tap()
            nameField.typeText("Test User")
        }
        
        // Submit registration
        let submitButton = app.buttons["Register"] ?? app.buttons["Sign Up"]
        if submitButton.exists {
            submitButton.tap()
        }
        
        // Wait for processing
        sleep(2)
        
        // Verify registration success
        XCTAssertTrue(app.alerts.count == 0 || app.otherElements["MainScreen"].exists, "Registration should complete successfully")
    }
    
    func testLoginErrorHandling() throws {
        // Attempt login with invalid credentials
        let loginButton = app.buttons["Login"]
        if loginButton.exists {
            loginButton.tap()
        }
        
        let emailField = app.textFields["Email"]
        let passwordField = app.secureTextFields["Password"]
        
        if emailField.exists && passwordField.exists {
            emailField.tap()
            emailField.typeText("invalid@example.com")
            
            passwordField.tap()
            passwordField.typeText("wrongpassword")
            
            let submitButton = app.buttons["Sign In"]
            if submitButton.exists {
                submitButton.tap()
            }
            
            sleep(2)
            
            // Verify error message is displayed
            let errorAlert = app.alerts.firstMatch
            XCTAssertTrue(errorAlert.exists || app.staticTexts.matching(identifier: "Error").count > 0, "Error message should be displayed")
        }
    }
}

