//
//  WebView+DoH.swift
//  EvoArc
//
//  Created on 2025-09-04.
//

import WebKit
import Foundation

// DNS Configuration Info for display in settings
// This extension works for both iOS and macOS implementations of WebView
extension WebView {
    static var dnsInfo: DNSInfo {
        return DNSInfo(
            provider: "ControlD",
            endpoint: "freedns.controld.com/p2",
            description: "Malware & Phishing Protection",
            servers: [
                "76.76.2.2",
                "76.76.10.2",
                "2606:1a40::2",
                "2606:1a40:1::2"
            ]
        )
    }
}

struct DNSInfo {
    let provider: String
    let endpoint: String
    let description: String
    let servers: [String]
}
