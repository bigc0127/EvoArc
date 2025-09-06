//
//  SimpleWebViewTest.swift
//  EvoArc
//
//  Test file to verify basic WKWebView functionality
//

import SwiftUI
import WebKit

#if os(macOS)
struct SimpleWebViewTest: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> WKWebView {
        // Most basic configuration possible
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // No updates needed for test
    }
}
#else
struct SimpleWebViewTest: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        // Most basic configuration possible
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No updates needed for test
    }
}
#endif

struct TestWebView: View {
    var body: some View {
        VStack {
            Text("WKWebView Test")
                .font(.title)
                .padding()
            
            if let url = URL(string: "https://www.apple.com") {
                SimpleWebViewTest(url: url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Failed to create URL")
            }
        }
    }
}

#Preview {
    TestWebView()
}
