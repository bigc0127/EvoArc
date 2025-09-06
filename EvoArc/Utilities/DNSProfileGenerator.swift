//
//  DNSProfileGenerator.swift
//  EvoArc
//
//  Created on 2025-09-04.
//

import Foundation
import UniformTypeIdentifiers

/// Generates a configuration profile for ControlD DNS
class DNSProfileGenerator {
    
    /// Generates a .mobileconfig profile for ControlD DNS
    static func generateProfile() -> Data? {
        let profileXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>PayloadContent</key>
            <array>
                <dict>
                    <key>DNSSettings</key>
                    <dict>
                        <key>DNSProtocol</key>
                        <string>HTTPS</string>
                        <key>ServerURL</key>
                        <string>https://freedns.controld.com/p2</string>
                        <key>ServerAddresses</key>
                        <array>
                            <string>76.76.2.2</string>
                            <string>76.76.10.2</string>
                            <string>2606:1a40::2</string>
                            <string>2606:1a40:1::2</string>
                        </array>
                    </dict>
                    <key>PayloadDescription</key>
                    <string>Configures DNS over HTTPS using ControlD's p2 endpoint for malware and phishing protection</string>
                    <key>PayloadDisplayName</key>
                    <string>ControlD DNS over HTTPS</string>
                    <key>PayloadIdentifier</key>
                    <string>com.evoarc.dns.controld</string>
                    <key>PayloadType</key>
                    <string>com.apple.dnsSettings.managed</string>
                    <key>PayloadUUID</key>
                    <string>\(UUID().uuidString)</string>
                    <key>PayloadVersion</key>
                    <integer>1</integer>
                </dict>
            </array>
            <key>PayloadDisplayName</key>
            <string>EvoArc Browser - ControlD DNS</string>
            <key>PayloadIdentifier</key>
            <string>com.evoarc.browser.dns</string>
            <key>PayloadRemovalDisallowed</key>
            <false/>
            <key>PayloadType</key>
            <string>Configuration</string>
            <key>PayloadUUID</key>
            <string>\(UUID().uuidString)</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
        </dict>
        </plist>
        """
        
        return profileXML.data(using: .utf8)
    }
    
    /// Saves the profile to a file
    static func saveProfile(to url: URL) -> Bool {
        guard let profileData = generateProfile() else { return false }
        
        do {
            try profileData.write(to: url)
            return true
        } catch {
            print("Failed to save profile: \(error)")
            return false
        }
    }
    
    /// Opens the profile for installation
    static func installProfile(completion: @escaping (Bool) -> Void = { _ in }) {
        #if os(iOS)
        // On iOS, we need to share the profile or open a web link to download it
        // Since we can't directly install, we'll provide instructions
        if let profileData = generateProfile() {
            // Save to Documents directory
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let profileURL = documentsPath.appendingPathComponent("ControlD-DNS.mobileconfig")
            
            do {
                try profileData.write(to: profileURL)
                
                // Share the profile using share sheet
                DispatchQueue.main.async {
                    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                          let window = windowScene.windows.first,
                          let rootViewController = window.rootViewController else {
                        completion(false)
                        return
                    }
                    
                    let activityVC = UIActivityViewController(
                        activityItems: [profileURL],
                        applicationActivities: nil
                    )
                    
                    if let popover = activityVC.popoverPresentationController {
                        popover.sourceView = window
                        popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                        popover.permittedArrowDirections = []
                    }
                    
                    rootViewController.present(activityVC, animated: true) {
                        completion(true)
                    }
                }
            } catch {
                print("Failed to save profile: \(error)")
                completion(false)
            }
        } else {
            completion(false)
        }
        #elseif os(macOS)
        // On macOS, save and open the profile
        DispatchQueue.main.async {
            let savePanel = NSSavePanel()
            savePanel.nameFieldStringValue = "ControlD-DNS.mobileconfig"
            savePanel.allowedContentTypes = [.data]
            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    if self.saveProfile(to: url) {
                        NSWorkspace.shared.open(url)
                        completion(true)
                    } else {
                        completion(false)
                    }
                } else {
                    completion(false)
                }
            }
        }
        #endif
    }
}

#if os(macOS)
import AppKit
#else
import UIKit
#endif
