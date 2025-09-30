//
//  UIViewModel.swift
//  EvoArc
//
//  UI state management for Aura-style interface
//

import SwiftUI
import Combine

class UIViewModel: ObservableObject {
    // Command Bar state
    @Published var showCommandBar: Bool = false
    @Published var commandBarText: String = ""
    @Published var searchSuggestions: [String] = []
    
    // Sidebar state
    @AppStorage("sidebarWidth") private var _sidebarWidth: Double = 300
    @AppStorage("showSidebar") var showSidebar: Bool = true
    @AppStorage("sidebarPosition") var sidebarPosition: String = "left" // "left" or "right"
    @AppStorage("autoHideSidebar") var autoHideSidebar: Bool = false
    
    var sidebarWidth: CGFloat {
        get { CGFloat(_sidebarWidth) }
        set { _sidebarWidth = Double(newValue) }
    }
    
    @Published var sidebarOffset: Bool = true
    @Published var hoveringID: String = ""
    
    // Settings
    @Published var showSettings: Bool = false
    
    // Gradient colors for background (single space for now)
    let backgroundGradientColors: [String] = ["8041E6", "A0F2FC"]
    
    var backgroundGradient: [Color] {
        backgroundGradientColors.map { Color(hex: $0) }
    }
    
    var textColor: Color {
        Color(hex: "ffffff")
    }
    
    // MARK: - Search Suggestions
    
    /// Fetch search suggestions from Google's toolbar API
    func updateSearchSuggestions() async {
        guard !commandBarText.isEmpty else {
            await MainActor.run {
                searchSuggestions = []
            }
            return
        }
        
        if let xml = await fetchXML(searchRequest: commandBarText) {
            let suggestions = formatXML(from: xml)
            await MainActor.run {
                searchSuggestions = suggestions
            }
        }
    }
    
    private func fetchXML(searchRequest: String) async -> String? {
        let encodedSearch = searchRequest.replacingOccurrences(of: " ", with: "+")
        guard let url = URL(string: "https://toolbarqueries.google.com/complete/search?q=\(encodedSearch)&output=toolbar&hl=en") else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return String(data: data, encoding: .utf8)
        } catch {
            print("Fetch error: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func formatXML(from input: String) -> [String] {
        var results = [String]()
        var currentIndex = input.startIndex
        
        while let startIndex = input[currentIndex...].range(of: "data=\"")?.upperBound {
            let remainingSubstring = input[startIndex...]
            
            if let endIndex = remainingSubstring.range(of: "\"")?.lowerBound {
                let attributeValue = input[startIndex..<endIndex]
                results.append(String(attributeValue))
                currentIndex = endIndex
            } else {
                break
            }
        }
        
        return results
    }
}

// MARK: - Comparable Extension for Clamping

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}