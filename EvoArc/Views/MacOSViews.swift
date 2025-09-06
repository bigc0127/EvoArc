//
//  MacOSViews.swift
//  EvoArc
//
//  Created on 2025-09-05.
//

import SwiftUI
import WebKit

#if os(macOS)
struct MacOSTabDrawerView: View {
    @ObservedObject var tabManager: TabManager
    @StateObject private var settings = BrowserSettings.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Tabs")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    tabManager.createNewTab()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    tabManager.hideTabDrawer()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Tabs list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(tabManager.tabs) { tab in
                        MacOSTabItemView(
                            tab: tab,
                            isSelected: tabManager.selectedTab?.id == tab.id,
                            onSelect: {
                                tabManager.selectTab(tab)
                            },
                            onClose: {
                                tabManager.closeTab(tab)
                            },
                            tabManager: tabManager
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .border(Color(NSColor.separatorColor), width: 1)
    }
}

struct MacOSTabItemView: View {
    let tab: Tab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let tabManager: TabManager
    
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Favicon placeholder
            Image(systemName: "globe")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 16, height: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                if let url = tab.url {
                    Text(url.host ?? url.absoluteString)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Engine indicator badge
            Text(tab.browserEngine == .webkit ? "S" : "C")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 12, height: 12)
                .background(
                    Circle()
                        .fill(tab.browserEngine == .webkit ? Color.blue : Color.orange)
                )
            
            if isHovered {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : (isHovered ? Color(NSColor.controlAccentColor).opacity(0.1) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Text("Browser Engine")
            
            Button(action: {
                tabManager.changeBrowserEngine(for: tab, to: .webkit)
            }) {
                HStack {
                    Text(BrowserEngine.webkit.displayName)
                    Spacer()
                    if tab.browserEngine == .webkit {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Button(action: {
                tabManager.changeBrowserEngine(for: tab, to: .blink)
            }) {
                HStack {
                    Text(BrowserEngine.blink.displayName)
                    Spacer()
                    if tab.browserEngine == .blink {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Divider()
            
            Button("Close Tab", action: onClose)
        }
    }
}

struct MacOSBottomBarView: View {
    @Binding var urlString: String
    @Binding var isURLBarFocused: Bool
    @ObservedObject var tabManager: TabManager
    var selectedTab: Tab?
    @Binding var showingSettings: Bool
    @Binding var shouldNavigate: Bool
    @StateObject private var settings = BrowserSettings.shared
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Back button
                Button(action: {
                    selectedTab?.webView?.goBack()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14))
                        .foregroundColor(selectedTab?.canGoBack == true ? .primary : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!(selectedTab?.canGoBack ?? false))
                
                // Forward button
                Button(action: {
                    selectedTab?.webView?.goForward()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(selectedTab?.canGoForward == true ? .primary : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!(selectedTab?.canGoForward ?? false))
                
                // Reload/Stop button
                Button(action: {
                    if selectedTab?.isLoading ?? false {
                        selectedTab?.webView?.stopLoading()
                    } else {
                        selectedTab?.webView?.reload()
                    }
                }) {
                    Image(systemName: selectedTab?.isLoading ?? false ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
                
                // URL bar
                HStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    TextField("Search or enter address", text: $urlString)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            shouldNavigate = true
                        }
                    
                    if selectedTab?.isLoading ?? false {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                
                // Tab drawer toggle button
                Button(action: {
                    tabManager.toggleTabDrawer()
                }) {
                    Image(systemName: "sidebar.leading")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Settings button
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
}
#endif
