//
//  SafePinnedTabTests.swift
//  EvoArcTests
//
//  Created on 2025-09-06.
//

import XCTest
@testable import EvoArc

class SafePinnedTabTests: XCTestCase {
    
    func testSafePinnedTabManager() throws {
        // Given
        let manager = SafePinnedTabManager.shared
        let testURL = URL(string: "https://example.com")!
        
        // When
        manager.pinTab(url: testURL, title: "Test Tab")
        
        // Then
        XCTAssertTrue(manager.isTabPinned(url: testURL))
        XCTAssertEqual(manager.pinnedTabs.count, 1)
        XCTAssertTrue(manager.pinnedTabs.contains(testURL.absoluteString))
    }
    
    func testUnpinTab() throws {
        // Given
        let manager = SafePinnedTabManager.shared
        let testURL = URL(string: "https://example.com")!
        manager.pinTab(url: testURL, title: "Test Tab")
        
        // When
        manager.unpinTab(url: testURL)
        
        // Then
        XCTAssertFalse(manager.isTabPinned(url: testURL))
        XCTAssertEqual(manager.pinnedTabs.count, 0)
    }
}
