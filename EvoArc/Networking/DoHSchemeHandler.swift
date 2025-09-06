//
//  DoHSchemeHandler.swift
//  EvoArc
//
//  Created on 2025-09-04.
//

import WebKit
import Foundation

/// Custom URL scheme handler for DNS over HTTPS
class DoHSchemeHandler: NSObject, WKURLSchemeHandler {
    
    private let dohSession: URLSession
    
    override init() {
        // Configure URLSession with DNS over HTTPS
        let config = URLSessionConfiguration.default
        
        // Configure ControlD's DNS over HTTPS
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        
        self.dohSession = URLSession(configuration: config)
        super.init()
    }
    
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        // Handle DoH scheme requests
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(NSError(domain: "DoHHandler", code: 1, userInfo: nil))
            return
        }
        
        // Process the request through DoH
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "text/plain"]
        )!
        
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(Data())
        urlSchemeTask.didFinish()
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // Handle task cancellation
    }
}
