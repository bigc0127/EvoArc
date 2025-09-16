//
//  CloudKitPinnedTabTests.swift
//  EvoArcTests
//
//  Created on 2025-09-06.
//

import XCTest
@testable import EvoArc

class CloudKitPinnedTabTests: XCTestCase {
    
    func testHybridManager() throws {
        // Given
        let manager = HybridPinnedTabManager.shared
        let testURL = URL(string: "https://example.com")!
        
        // When - Start with safe manager (CloudKit not ready)
        manager.pinTab(url: testURL, title: "Test Tab")
        
        // Then
        XCTAssertTrue(manager.isTabPinned(url: testURL))
        XCTAssertEqual(manager.pinnedTabs.count, 1)
        XCTAssertEqual(manager.pinnedTabs.first?.urlString, testURL.absoluteString)
        XCTAssertEqual(manager.pinnedTabs.first?.title, "Test Tab")
    }
    
    func testUnpinTab() throws {
        // Given
        let manager = HybridPinnedTabManager.shared
        let testURL = URL(string: "https://example.com")!
        manager.pinTab(url: testURL, title: "Test Tab")
        
        // When
        manager.unpinTab(url: testURL)
        
        // Then
        XCTAssertFalse(manager.isTabPinned(url: testURL))
        XCTAssertEqual(manager.pinnedTabs.count, 0)
    }
    
    func testPinnedTabEntity() throws {
        // Given
        let entity = PinnedTabEntity(
            urlString: "https://example.com",
            title: "Test Tab",
            isPinned: true,
            createdAt: Date(),
            pinnedOrder: 0
        )
        
        // Then
        XCTAssertNotNil(entity.url)
        XCTAssertEqual(entity.url?.absoluteString, "https://example.com")
        XCTAssertEqual(entity.title, "Test Tab")
        XCTAssertTrue(entity.isPinned)
    }
    
    func testReordering() throws {
        // Given
        let manager = HybridPinnedTabManager.shared
        let url1 = URL(string: "https://example1.com")!
        let url2 = URL(string: "https://example2.com")!
        
        manager.pinTab(url: url1, title: "Tab 1")
        manager.pinTab(url: url2, title: "Tab 2")
        
        // When - Reorder
        let reorderedEntities = manager.pinnedTabs.reversed()
        manager.reorderPinnedTabs(Array(reorderedEntities))
        
        // Then
        XCTAssertEqual(manager.pinnedTabs.count, 2)
        XCTAssertEqual(manager.pinnedTabs.first?.urlString, url2.absoluteString)
        XCTAssertEqual(manager.pinnedTabs.last?.urlString, url1.absoluteString)
    }
}
