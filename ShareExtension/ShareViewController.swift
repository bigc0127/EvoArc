//
//  ShareViewController.swift
//  ShareExtension
//
//  Share Extension for EvoArc Browser
//  Handles incoming URLs/text from other apps via the iOS share sheet
//

import UIKit
import WebKit
import UniformTypeIdentifiers

/// Share Extension view controller with WebView
class ShareViewController: UIViewController, WKNavigationDelegate {
    
    // MARK: - UI Components
    
    private var webView: WKWebView!
    private var backButton: UIButton!
    private var forwardButton: UIButton!
    private var openButton: UIButton!
    private var cancelButton: UIButton!
    private var activityIndicator: UIActivityIndicatorView!
    private var currentURL: URL?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("[ShareExtension] viewDidLoad called")
        
        setupUI()
        
        print("[ShareExtension] UI setup complete")
        
        // Start processing the shared content
        Task {
            print("[ShareExtension] Starting to handle shared content")
            await handleSharedContent()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("[ShareExtension] viewDidAppear called")
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        print("[ShareExtension] setupUI starting")
        view.backgroundColor = .systemBackground
        
        // Create WebView with minimal configuration for Share Extension
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = false
        config.mediaTypesRequiringUserActionForPlayback = .all
        
        // Disable JavaScript to reduce resource usage in extension
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = false
        config.defaultWebpagePreferences = prefs
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.scrollView.isScrollEnabled = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        
        // Create activity indicator
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        
        // Create Back button
        backButton = UIButton(type: .system)
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = .white
        backButton.backgroundColor = .systemGray
        backButton.layer.cornerRadius = 20
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backButton.isEnabled = false
        view.addSubview(backButton)
        
        // Create Forward button
        forwardButton = UIButton(type: .system)
        forwardButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        forwardButton.tintColor = .white
        forwardButton.backgroundColor = .systemGray
        forwardButton.layer.cornerRadius = 20
        forwardButton.translatesAutoresizingMaskIntoConstraints = false
        forwardButton.addTarget(self, action: #selector(forwardTapped), for: .touchUpInside)
        forwardButton.isEnabled = false
        view.addSubview(forwardButton)
        
        // Create Open in App button
        openButton = UIButton(type: .system)
        openButton.setTitle("Open in EvoArc", for: .normal)
        openButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        openButton.backgroundColor = .systemBlue
        openButton.setTitleColor(.white, for: .normal)
        openButton.layer.cornerRadius = 12
        openButton.translatesAutoresizingMaskIntoConstraints = false
        openButton.addTarget(self, action: #selector(openInFullApp), for: .touchUpInside)
        view.addSubview(openButton)
        
        // Create Cancel button
        cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 16)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(cancelButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // WebView - fills top area above buttons
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: backButton.topAnchor, constant: -12),
            
            // Activity Indicator - center
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            // Back Button - bottom left
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.bottomAnchor.constraint(equalTo: cancelButton.topAnchor, constant: -12),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Forward Button - next to back button
            forwardButton.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 8),
            forwardButton.bottomAnchor.constraint(equalTo: cancelButton.topAnchor, constant: -12),
            forwardButton.widthAnchor.constraint(equalToConstant: 44),
            forwardButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Open Button - same line, fills remaining space
            openButton.leadingAnchor.constraint(equalTo: forwardButton.trailingAnchor, constant: 12),
            openButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            openButton.bottomAnchor.constraint(equalTo: cancelButton.topAnchor, constant: -12),
            openButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Cancel Button - very bottom
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            cancelButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        print("[ShareExtension] setupUI complete")
    }
    
    // MARK: - Actions
    
    @objc private func openInFullApp() {
        guard let url = currentURL else { return }
        
        // Create EvoArc custom scheme URL
        let evoarcURL = createEvoArcURL(from: url)
        
        if let evoarcURL = evoarcURL {
            extensionContext?.open(evoarcURL, completionHandler: { [weak self] success in
                if success {
                    // Close the extension after opening
                    self?.completeRequest()
                }
            })
        }
    }
    
    @objc private func cancelTapped() {
        completeRequest()
    }
    
    @objc private func backTapped() {
        webView.goBack()
    }
    
    @objc private func forwardTapped() {
        webView.goForward()
    }
    
    private func updateNavigationButtons() {
        backButton.isEnabled = webView.canGoBack
        backButton.backgroundColor = webView.canGoBack ? .systemBlue : .systemGray
        
        forwardButton.isEnabled = webView.canGoForward
        forwardButton.backgroundColor = webView.canGoForward ? .systemBlue : .systemGray
    }
    
    // MARK: - Content Handling
    
    /// Main entry point for processing shared content
    private func handleSharedContent() async {
        print("[ShareExtension] handleSharedContent started")
        
        guard let extensionContext = extensionContext else {
            print("[ShareExtension] ERROR: No extension context")
            completeRequest()
            return
        }
        
        print("[ShareExtension] Extension context found, extracting URL...")
        
        do {
            // Extract URL from the shared items
            let url = try await extractURL(from: extensionContext)
            print("[ShareExtension] URL extracted: \(url.absoluteString)")
            currentURL = url
            
            // Load URL in WebView
            await MainActor.run {
                print("[ShareExtension] Loading URL in WebView")
                activityIndicator.startAnimating()
                let request = URLRequest(url: url)
                webView.load(request)
            }
            
        } catch {
            print("[ShareExtension] ERROR extracting URL: \(error)")
            // Show error and close
            await showError(message: "Unable to open this content")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.completeRequest()
            }
        }
    }
    
    /// Extracts a URL from the extension context
    /// Supports both direct URLs and text containing URLs
    private func extractURL(from context: NSExtensionContext) async throws -> URL {
        guard let inputItems = context.inputItems as? [NSExtensionItem] else {
            throw ShareError.noInputItems
        }
        
        // Process each input item
        for item in inputItems {
            guard let attachments = item.attachments else { continue }
            
            // Try to find a URL in the attachments
            for attachment in attachments {
                
                // Try as URL type first (most common for web links)
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let url = try? await loadURL(from: attachment) {
                        return url
                    }
                }
                
                // Try as plain text (some apps share URLs as text)
                if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let url = try? await loadURLFromText(from: attachment) {
                        return url
                    }
                }
            }
        }
        
        throw ShareError.noURLFound
    }
    
    /// Loads a URL directly from an attachment
    private func loadURL(from attachment: NSItemProvider) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: ShareError.invalidURL)
                }
            }
        }
    }
    
    /// Loads a URL from text content
    private func loadURLFromText(from attachment: NSItemProvider) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                // Extract text
                var text: String?
                if let string = item as? String {
                    text = string
                } else if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
                    text = string
                }
                
                // Try to find a URL in the text
                if let text = text,
                   let url = self.extractURLFromString(text) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: ShareError.noURLInText)
                }
            }
        }
    }
    
    /// Extracts a URL from a string (looks for http:// or https://)
    private func extractURLFromString(_ string: String) -> URL? {
        // First try to create URL directly
        if let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
           url.scheme == "http" || url.scheme == "https" {
            return url
        }
        
        // Try to find a URL pattern in the text
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: string, range: NSRange(string.startIndex..., in: string))
        
        if let match = matches?.first, let url = match.url {
            return url
        }
        
        return nil
    }
    
    /// Creates an evoarc:// URL from a standard URL
    private func createEvoArcURL(from url: URL) -> URL? {
        var components = URLComponents()
        components.scheme = "evoarc"
        components.host = url.absoluteString
        return components.url
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("[ShareExtension] WebView started loading")
        activityIndicator.startAnimating()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("[ShareExtension] WebView finished loading")
        activityIndicator.stopAnimating()
        updateNavigationButtons()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[ShareExtension] WebView failed: \(error.localizedDescription)")
        activityIndicator.stopAnimating()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("[ShareExtension] WebView provisional navigation failed: \(error.localizedDescription)")
        activityIndicator.stopAnimating()
    }
    
    // MARK: - UI Feedback
    
    /// Shows an error message to the user
    @MainActor
    private func showError(message: String) async {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.completeRequest()
        })
        present(alert, animated: true)
        
        // Auto-dismiss after 2 seconds
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        alert.dismiss(animated: true)
    }
    
    /// Completes the extension request and closes the share sheet
    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}

// MARK: - Error Types

enum ShareError: Error, LocalizedError {
    case noInputItems
    case noURLFound
    case invalidURL
    case noURLInText
    
    var errorDescription: String? {
        switch self {
        case .noInputItems:
            return "No content was shared"
        case .noURLFound:
            return "No URL found in shared content"
        case .invalidURL:
            return "The shared URL is invalid"
        case .noURLInText:
            return "No URL found in the shared text"
        }
    }
}
