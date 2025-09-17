import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Get the shared items
        let extensionItems = extensionContext?.inputItems as? [NSExtensionItem]
        
        // Look for URLs in the shared content
        if let firstItem = extensionItems?.first,
           let attachments = firstItem.attachments {
            
            // Check for URLs
            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
                        if let url = item as? URL {
                            self.openURL(url)
                        }
                        // Complete and close the extension
                        self.extensionContext?.completeRequest(returningItems: nil)
                    }
                    return
                }
            }
        }
        
        // If no URL was found, just close the extension
        extensionContext?.completeRequest(returningItems: nil)
    }
    
    private func openURL(_ url: URL) {
        // Create a URL with our custom scheme
        var components = URLComponents()
        components.scheme = "evoarc"
        components.host = url.absoluteString
        
        if let appURL = components.url {
            // Open the URL in EvoArc
            var responder = self as UIResponder?
            let selector = sel_registerName("openURL:")
            
            while responder != nil {
                if responder?.responds(to: selector) == true {
                    responder?.perform(selector, with: appURL)
                    break
                }
                responder = responder?.next
            }
        }
    }
}