//
//  CommandBarView.swift
//  EvoArc
//
//  ARC Like UI command bar for search and navigation
//

import SwiftUI

struct CommandBarView: View {
    @ObservedObject var tabManager: TabManager
    @ObservedObject var uiViewModel: UIViewModel
    @StateObject private var settings = BrowserSettings.shared
    
    @FocusState private var commandBarFocus: Bool
    @State private var currentSuggestionIndex = -1
    @State private var previewSuggestionInCommandBar = ""
    
    let geo: GeometryProxy
    
    var body: some View {
        VStack {
            content
                .padding(5)
                .background(
                    ZStack {
                        #if os(iOS)
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                        #else
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(nsColor: .windowBackgroundColor))
                        #endif
                        
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.regularMaterial)
                            .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 0)
                    }
                )
        }
        .frame(width: geo.size.width / 2)
        .onAppear {
            commandBarFocus = true
        }
        .onKeyPress(.upArrow) {
            handleUpArrow()
            return .handled
        }
        .onKeyPress(.downArrow) {
            handleDownArrow()
            return .handled
        }
    }
    
    private var textBinding: Binding<String> {
        currentSuggestionIndex == -1 ? $uiViewModel.commandBarText : $previewSuggestionInCommandBar
    }
    
    private var content: some View {
        VStack {
            searchBarContent
            suggestionsContent
        }
    }
    
    private var searchBarContent: some View {
        HStack(spacing: 20) {
            searchTextField
            submitButton
        }
    }
    
    private var searchTextField: some View {
        TextField("Search or enter URL", text: textBinding)
            .padding(20)
            #if os(iOS)
            .textInputAutocapitalization(.never)
            #endif
            .autocorrectionDisabled(true)
            .lineLimit(1)
            .zIndex(2)
            .focused($commandBarFocus)
            .onSubmit {
                handleSubmit()
            }
            .onTapGesture {
                commandBarFocus = true
            }
            .onChange(of: uiViewModel.commandBarText) { _, value in
                Task {
                    await uiViewModel.updateSearchSuggestions()
                }
            }
    }
    
    private var submitButton: some View {
        Button(action: handleSubmit) {
            Image(systemName: "arrow.forward")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
                .padding(20)
        }
        .zIndex(1)
        .frame(width: 80)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(hex: uiViewModel.backgroundGradientColors.first ?? "8041E6"))
                .opacity(uiViewModel.commandBarText.isEmpty ? 0.5 : 1.0)
        )
        .disabled(uiViewModel.commandBarText.isEmpty && previewSuggestionInCommandBar.isEmpty)
    }
    
    private var suggestionsContent: some View {
        ForEach(Array(uiViewModel.searchSuggestions.prefix(5).enumerated()), id: \.element) { index, suggestion in
            suggestionButton(for: suggestion, at: index)
        }
        .animation(.easeInOut(duration: 0.5), value: uiViewModel.searchSuggestions)
    }
    
    private func suggestionButton(for suggestion: String, at index: Int) -> some View {
        Button {
            handleSuggestionTap(suggestion)
        } label: {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                
                Text(suggestion)
                    .lineLimit(1)
                
                Spacer()
            }
            #if os(iOS)
            .foregroundStyle(Color(.label))
            #else
            .foregroundStyle(Color.primary)
            #endif
        }
        .padding(20)
        .frame(width: geo.size.width / 2)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(hex: uiViewModel.backgroundGradientColors.first ?? "8041E6"))
                .opacity(currentSuggestionIndex == index ? 0.5 : 0.0)
        )
    }
    
    // MARK: - Actions
    
    private func handleSubmit() {
        let text = currentSuggestionIndex == -1 ? uiViewModel.commandBarText : previewSuggestionInCommandBar
        
        guard !text.isEmpty else { return }
        
        // Format URL or create search query
        let urlString = formatURLOrSearch(text)
        
        if let url = URL(string: urlString) {
            tabManager.createNewTab(url: url)
        }
        
        resetCommandBar()
    }
    
    private func handleSuggestionTap(_ suggestion: String) {
        let urlString = formatURLOrSearch(suggestion)
        
        if let url = URL(string: urlString) {
            tabManager.createNewTab(url: url)
        }
        
        resetCommandBar()
    }
    
    private func resetCommandBar() {
        uiViewModel.commandBarText = ""
        previewSuggestionInCommandBar = ""
        currentSuggestionIndex = -1
        uiViewModel.showCommandBar = false
        uiViewModel.searchSuggestions = []
    }
    
    private func handleUpArrow() {
        if uiViewModel.searchSuggestions.count >= 5 {
            if currentSuggestionIndex == -1 {
                currentSuggestionIndex = 4
            } else {
                currentSuggestionIndex -= 1
            }
            
            if currentSuggestionIndex != -1 {
                previewSuggestionInCommandBar = uiViewModel.searchSuggestions[currentSuggestionIndex]
            }
        }
    }
    
    private func handleDownArrow() {
        if uiViewModel.searchSuggestions.count >= 5 {
            if currentSuggestionIndex == 4 {
                currentSuggestionIndex = -1
            } else {
                currentSuggestionIndex += 1
            }
            
            if currentSuggestionIndex != -1 {
                previewSuggestionInCommandBar = uiViewModel.searchSuggestions[currentSuggestionIndex]
            }
        }
    }
    
    private func formatURLOrSearch(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if it looks like a URL
        if trimmed.contains(".") && !trimmed.contains(" ") {
            // Add https:// if no scheme
            if !trimmed.hasPrefix("http://") && !trimmed.hasPrefix("https://") {
                return "https://" + trimmed
            }
            return trimmed
        }
        
        // Otherwise, use as search query
        if let searchURL = settings.searchURL(for: trimmed) {
            return searchURL.absoluteString
        }
        
        // Fallback
        return "https://www.google.com/search?q=" + trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
    }
}