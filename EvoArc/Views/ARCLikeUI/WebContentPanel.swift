//
//  WebContentPanel.swift
//  EvoArc
//
//  ARC Like UI web content panel wrapping existing browser functionality
//

import SwiftUI

struct WebContentPanel: View {
    @ObservedObject var tabManager: TabManager
    @ObservedObject var uiViewModel: UIViewModel
    
    @Binding var urlString: String
    @Binding var shouldNavigate: Bool
    @Binding var urlBarVisible: Bool
    
    var onNavigate: (URL) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: uiViewModel.backgroundGradient,
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
            .overlay {
                if colorScheme == .dark {
                    Color.black.opacity(0.5)
                }
            }
            .ignoresSafeArea()
            
            // Web content with rounded corners
            if !tabManager.tabs.isEmpty && tabManager.isInitialized {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.25))
                    .overlay {
                        TabViewContainer(
                            tabManager: tabManager,
                            urlString: $urlString,
                            shouldNavigate: $shouldNavigate,
                            urlBarVisible: $urlBarVisible,
                            onNavigate: onNavigate,
                            autoHideEnabled: false // Handled by the sidebar UI
                        )
                        .cornerRadius(10)
                        .clipped()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
            } else if !tabManager.isInitialized {
                // Loading state
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                    Text("Restoring tabs...")
                        .font(.headline)
                        .foregroundColor(uiViewModel.textColor)
                    Spacer()
                }
            } else {
                // Empty state
                VStack {
                    Spacer()
                    Image(systemName: "globe")
                        .font(.system(size: 60))
                        .foregroundColor(uiViewModel.textColor.opacity(0.5))
                    Text("No tab selected")
                        .font(.headline)
                        .foregroundColor(uiViewModel.textColor)
                    Spacer()
                }
            }
        }
    }
}