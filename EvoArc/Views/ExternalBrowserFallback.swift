//
//  ExternalBrowserFallback.swift
//  EvoArc
//
//  Fallback solution for WebKit crashes - opens URLs in default browser
//

import SwiftUI

struct ExternalBrowserFallback: View {
    @ObservedObject var tab: Tab
    @State private var showingAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("WebView Loading Issue")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Due to a compatibility issue with macOS Beta and WebKit, the internal browser cannot load web pages.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            if let url = tab.url {
                VStack(spacing: 12) {
                    Text("URL: \(url.absoluteString)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal)
                    
                    Button(action: {
                        openInExternalBrowser(url: url)
                    }) {
                        Label("Open in Default Browser", systemImage: "arrow.up.forward.app")
                            .frame(maxWidth: 200)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            Text("This is a temporary issue with the beta version of macOS. The internal browser will work properly in the stable release.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.top)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.95, opacity: 0.1))
        .alert("Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func openInExternalBrowser(url: URL) {
    }
}

// Alternative: Simple WebView wrapper with error handling
struct SafeWebView: View {
    @ObservedObject var tab: Tab
    @Binding var urlString: String
    @Binding var shouldNavigate: Bool
    let onNavigate: (URL) -> Void
    @State private var showFallback = false
    
    var body: some View {
        Group {
            if showFallback {
                ExternalBrowserFallback(tab: tab)
            } else {
                // Try to use WebView, but fall back if it fails
                WebView(tab: tab, 
                       urlString: $urlString,
                       shouldNavigate: $shouldNavigate,
                       onNavigate: onNavigate)
                    .onAppear {
                        // Monitor for crashes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            if tab.webView == nil || !tab.isLoading {
                                showFallback = true
                            }
                        }
                    }
            }
        }
    }
}
