//
//  ShareViewController.swift
//  ShareExtension
//
//  Share Extension for EvoArc Browser
//  Based on Brave's implementation pattern
//

import UIKit
import UniformTypeIdentifiers

extension String {
    /// The first URL found within this String, or nil if no URL is found
    var firstURL: URL? {
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
           let match = detector.firstMatch(in: self, options: [], range: NSRange(location: 0, length: self.count)),
           let range = Range(match.range, in: self) {
            return URL(string: String(self[range]))
        }
        return nil
    }
}

class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("[ShareExtension] viewDidLoad called")
        
        // Hide the view immediately
        view.alpha = 0
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        print("[ShareExtension] viewDidAppear called")
        
        // Process when the view is in the responder chain
        processSharedContent()
    }
    
    private func processSharedContent() {
        print("[ShareExtension] processSharedContent called")
        
        guard let inputItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            print("[ShareExtension] No input items")
            cancel()
            return
        }
        
        // Reduce all input items down to a single list of item providers
        let attachments: [NSItemProvider] =
            inputItems
            .compactMap { $0.attachments }
            .flatMap { $0 }
        
        // Look for the first URL the host application is sharing.
        // If there isn't a URL grab the first text item
        guard let provider = attachments.first(where: { $0.isUrl }) ?? attachments.first(where: { $0.isText }) else {
            print("[ShareExtension] No URL or text found, cancelling")
            cancel()
            return
        }
        
        print("[ShareExtension] Found provider, loading item...")
        
        provider.loadItem(forTypeIdentifier: provider.isUrl ? UTType.url.identifier : UTType.text.identifier) { item, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("[ShareExtension] Error loading item: \(error)")
                    self.cancel()
                    return
                }
                
                guard let item = item, let schemeUrl = Scheme(item: item)?.schemeUrl else {
                    print("[ShareExtension] Failed to create scheme URL")
                    self.cancel()
                    return
                }
                
                print("[ShareExtension] Created scheme URL: \(schemeUrl.absoluteString)")
                self.handleUrl(schemeUrl)
            }
        }
    }
    
    private func cancel() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    private struct Scheme {
        private enum SchemeType {
            case url, query
        }
        
        private let type: SchemeType
        private let urlOrQuery: String
        
        init?(item: NSSecureCoding) {
            if let text = item as? String {
                urlOrQuery = text
                type = .query
            } else if let url = (item as? URL)?.absoluteString.firstURL?.absoluteString {
                urlOrQuery = url
                type = .url
            } else {
                return nil
            }
        }
        
        var schemeUrl: URL? {
            var components = URLComponents()
            let queryItem: URLQueryItem
            
            components.scheme = "evoarc"
            
            switch type {
            case .url:
                components.host = "open-url"
                queryItem = URLQueryItem(name: "url", value: urlOrQuery)
            case .query:
                components.host = "search"
                queryItem = URLQueryItem(name: "q", value: urlOrQuery)
            }
            
            components.queryItems = [queryItem]
            return components.url
        }
    }
    
    
    private func handleUrl(_ url: URL) {
        print("[ShareExtension] Opening URL: \(url.absoluteString)")
        
        // Use the official API to open the host app
        extensionContext?.open(url, completionHandler: { success in
            print("[ShareExtension] Open URL completed: success=\(success)")
            
            // Close the extension
            self.cancel()
        })
    }
    
}

// MARK: - Extensions

extension NSItemProvider {
    var isText: Bool {
        return hasItemConformingToTypeIdentifier(UTType.text.identifier)
    }
    
    var isUrl: Bool {
        return hasItemConformingToTypeIdentifier(UTType.url.identifier)
    }
}

