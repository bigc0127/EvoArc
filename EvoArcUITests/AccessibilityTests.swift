//
//  AccessibilityTests.swift
//  EvoArcUITests
//
//  Created by Connor W. Needling on 2025-09-17.
//

import XCTest

/// Test suite for verifying accessibility features and dynamic scaling behavior
final class AccessibilityTests: XCTestCase {
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }
    
    // MARK: - Dynamic Type Tests
    
    /// Test that text scales properly with different Dynamic Type sizes
    func testDynamicTypeScaling() throws {
        // Test accessibility text sizes in order
        let contentSizes: [String] = [
            "AX1", "AX2", "AX3", "AX4", "AX5"
        ]
        
        for size in contentSizes {
            // Set content size via internal accessibility command
            app.commands.element(boundBy: 0).tap()
            app.buttons["Set Dynamic Type Size"].tap()
            app.buttons[size].tap()
            
            // Verify bottom bar remains usable
            XCTAssertTrue(app.buttons["Search or enter address"].exists)
            XCTAssertTrue(app.buttons["Search or enter address"].isHittable)
            
            // Test URL bar input
            app.textFields["Search or enter address"].tap()
            app.textFields["Search or enter address"].typeText("example.com")
            
            // Verify suggestions view remains usable
            XCTAssertTrue(app.scrollViews["Suggestions"].exists)
            XCTAssertTrue(app.scrollViews["Suggestions"].isHittable)
            
            // Test tab drawer
            app.buttons["Show Tabs"].tap()
            XCTAssertTrue(app.scrollViews["Tab Drawer"].exists)
            XCTAssertTrue(app.buttons["New Tab"].isHittable)
            
            // Close tab drawer
            app.buttons["Close Tabs"].tap()
            
            // Open settings
            app.buttons["Settings"].tap()
            
            // Verify key settings elements are accessible
            XCTAssertTrue(app.buttons["Done"].isHittable)
            XCTAssertTrue(app.switches["Request Desktop Website"].exists)
            XCTAssertTrue(app.switches["Auto-hide URL Bar"].exists)
            
            // Close settings
            app.buttons["Done"].tap()
        }
    }
    
    // MARK: - Zoom Tests
    
    /// Test that UI remains usable with zoom enabled
    func testZoomScaling() throws {
        // Enable zoom via internal accessibility command
        app.commands.element(boundBy: 0).tap()
        app.buttons["Enable Zoom"].tap()
        
        // Set different zoom levels
        let zoomLevels: [CGFloat] = [1.5, 2.0, 2.5, 3.0]
        
        for zoom in zoomLevels {
            // Set zoom level
            app.commands.element(boundBy: 0).tap()
            app.buttons["Set Zoom Level"].tap()
            app.sliders["Zoom"].adjust(toNormalizedSliderPosition: Double(zoom - 1.0) / 2.0)
            
            // Test core functionality remains accessible
            XCTAssertTrue(app.buttons["Search or enter address"].isHittable)
            XCTAssertTrue(app.buttons["Show Tabs"].isHittable)
            XCTAssertTrue(app.buttons["Settings"].isHittable)
            
            // Test tab drawer
            app.buttons["Show Tabs"].tap()
            XCTAssertTrue(app.scrollViews["Tab Drawer"].exists)
            XCTAssertTrue(app.buttons["New Tab"].isHittable)
            app.buttons["Close Tabs"].tap()
            
            // Test settings
            app.buttons["Settings"].tap()
            XCTAssertTrue(app.buttons["Done"].isHittable)
            app.buttons["Done"].tap()
        }
    }
    
    // MARK: - Device Orientation Tests
    
    /// Test UI adaptation in different orientations
    func testOrientationScaling() throws {
        // Test portrait
        XCUIDevice.shared.orientation = .portrait
        verifyUIAccessibility()
        
        // Test landscape
        XCUIDevice.shared.orientation = .landscapeLeft
        verifyUIAccessibility()
        
        // Test portrait upside down
        XCUIDevice.shared.orientation = .portraitUpsideDown
        verifyUIAccessibility()
        
        // Test other landscape
        XCUIDevice.shared.orientation = .landscapeRight
        verifyUIAccessibility()
    }
    
    // MARK: - VoiceOver Tests
    
    /// Test VoiceOver accessibility
    func testVoiceOverAccessibility() throws {
        // Enable VoiceOver via internal accessibility command
        app.commands.element(boundBy: 0).tap()
        app.buttons["Enable VoiceOver"].tap()
        
        // Test URL bar
        let urlBar = app.textFields["Search or enter address"]
        XCTAssertTrue(urlBar.exists)
        XCTAssertNotNil(urlBar.value as? String)
        
        // Test tab drawer
        let tabButton = app.buttons["Show Tabs"]
        XCTAssertTrue(tabButton.exists)
        XCTAssertNotNil(tabButton.label)
        
        tabButton.tap()
        let newTabButton = app.buttons["New Tab"]
        XCTAssertTrue(newTabButton.exists)
        XCTAssertNotNil(newTabButton.label)
        
        // Test settings
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.exists)
        XCTAssertNotNil(settingsButton.label)
        
        settingsButton.tap()
        let switches = app.switches.allElementsBoundByIndex
        for toggle in switches {
            XCTAssertNotNil(toggle.label)
            XCTAssertNotNil(toggle.value as? String)
        }
        
        // Disable VoiceOver
        app.commands.element(boundBy: 0).tap()
        app.buttons["Disable VoiceOver"].tap()
    }
    
    // MARK: - Helper Methods
    
    /// Verify core UI elements remain accessible
    private func verifyUIAccessibility() {
        // Verify bottom bar elements
        XCTAssertTrue(app.buttons["Search or enter address"].isHittable)
        XCTAssertTrue(app.buttons["Show Tabs"].isHittable)
        XCTAssertTrue(app.buttons["Settings"].isHittable)
        
        // Test tab drawer interaction
        app.buttons["Show Tabs"].tap()
        XCTAssertTrue(app.scrollViews["Tab Drawer"].exists)
        XCTAssertTrue(app.buttons["New Tab"].isHittable)
        app.buttons["Close Tabs"].tap()
        
        // Test settings interaction
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["Done"].isHittable)
        app.buttons["Done"].tap()
    }
}