//
//  DownloadManager.swift
//  EvoArc
//
//  Manages file downloads in the browser.
//
//  Key responsibilities:
//  1. Download files from URLs
//  2. Track download progress (0-100%)
//  3. Save files to Documents directory
//  4. Manage recent downloads history
//  5. Handle cancellation and errors
//  6. Show system share sheet for downloaded files
//
//  Architecture:
//  - Singleton pattern (one shared instance)
//  - Uses URLSession with delegate for progress tracking
//  - @MainActor for thread safety
//  - ObservableObject for SwiftUI reactivity
//  - Persists recent downloads to UserDefaults
//
//  For Swift beginners:
//  - URLSession is Apple's HTTP/download framework
//  - Delegates receive callbacks as downloads progress
//  - @MainActor ensures all operations run on the main thread
//

import Foundation  // Core Swift - FileManager, URLSession, UserDefaults
import SwiftUI    // Apple's UI framework - ObservableObject
import Combine    // Reactive framework - @Published
import UniformTypeIdentifiers  // File type identification (UTType)
import Observation  // Swift's observation framework
import UIKit      // iOS framework - UIActivityViewController

// MARK: - Download Progress Model

/// Represents the state of a single download task.
///
/// **Value type**: struct (copied when assigned)
///
/// **Identifiable**: Required for SwiftUI ForEach loops.
/// Each download has a unique ID for tracking.
///
/// **Use case**: Displayed in download progress UI to show
/// which files are downloading and their status.
struct DownloadProgress: Identifiable {
    /// Unique identifier for this download.
    let id = UUID()
    
    /// The source URL being downloaded from.
    let url: URL
    
    /// The filename (e.g., "document.pdf").
    let fileName: String
    
    /// Download progress from 0.0 (0%) to 1.0 (100%).
    var progress: Double
    
    /// Current status of the download.
    var status: DownloadStatus
    
    /// Local file URL after successful download (nil while downloading).
    var localURL: URL?
    
    /// Error if download failed (nil for success/in-progress).
    var error: Error?
    
    /// The possible states a download can be in.
    ///
    /// **State transitions**:
    /// downloading → completed (success)
    /// downloading → failed (network error, disk full, etc.)
    enum DownloadStatus {
        case downloading  // In progress
        case completed    // Successfully saved to disk
        case failed       // Error occurred
    }
}

// MARK: - Download Delegate Helper

/// Helper class that receives URLSession download callbacks.
///
/// **Why a separate class?**: URLSession delegates must be NSObject subclasses.
/// This helper bridges between URLSession (Objective-C APIs) and DownloadManager
/// (modern Swift).
///
/// **@MainActor**: All methods run on the main thread for thread safety.
///
/// **private**: Only DownloadManager should create this.
///
/// **URLSessionDownloadDelegate**: Protocol for receiving download events:
/// - Progress updates (every few KB downloaded)
/// - Completion (file finished downloading)
/// - Errors (network failure, disk full, etc.)
///
/// **For Swift beginners**:
/// - Delegate pattern: "Call me when something happens"
/// - URLSession calls these methods automatically during downloads
/// - We don't call these methods ourselves
@MainActor
private class DownloadDelegateHelper: NSObject, URLSessionDownloadDelegate {
    /// Reference to the parent DownloadManager.
    ///
    /// **unowned**: Doesn't increase retain count. Prevents retain cycle:
    /// - DownloadManager owns URLSession
    /// - URLSession owns DownloadDelegateHelper
    /// - DownloadDelegateHelper needs reference to DownloadManager
    /// Without 'unowned', they'd keep each other alive forever (memory leak).
    ///
    /// **Why unowned vs weak?**: Helper and manager have same lifetime.
    /// If manager is deallocated, helper is too. No need for optional.
    unowned let manager: DownloadManager
    
    /// Initializes the helper with a reference to its manager.
    init(manager: DownloadManager) {
        self.manager = manager
        super.init()  // Required for NSObject subclasses
    }
    
    /// Called when a download completes successfully.
    ///
    /// **When called**: File has been downloaded to a temporary location.
    /// We must move it to a permanent location or it will be deleted.
    ///
    /// **nonisolated**: This method is called on URLSession's delegate queue
    /// (background thread), not the main actor. We use Task { @MainActor }
    /// to switch to main thread when needed.
    ///
    /// **Parameters**:
    /// - session: The URLSession that handled the download
    /// - downloadTask: The specific download task that completed
    /// - location: Temporary file URL (will be deleted soon!)
    ///
    /// **Important**: Must move file from temporary location immediately.
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        /// Extract the original URL we were downloading from.
        /// Guard ensures we have it - if not, can't track this download.
        guard let url = downloadTask.originalRequest?.url else { return }
        
        /// Switch to main actor for UI updates and file operations.
        Task { @MainActor in
            /// Get filename from server's suggestion or URL's last component.
            /// Example: "document.pdf" from "https://example.com/files/document.pdf"
            let fileName = downloadTask.response?.suggestedFilename ?? url.lastPathComponent
            
            /// Build full destination path in Documents directory.
            let destinationURL = manager.downloadDirectory.appendingPathComponent(fileName)
        
        do {
            /// Ensure the destination directory exists.
            /// withIntermediateDirectories: true = create parent folders if needed
            let destDir = destinationURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            
            /// If file already exists, delete it first.
            /// This handles re-downloading the same file.
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            /// Move file from temporary location to permanent location.
            /// This is atomic - file appears all at once, not partially.
            try FileManager.default.moveItem(at: location, to: destinationURL)
            
            /// Success! Update download status on main thread.
            Task { @MainActor in
                /// Find this download in the active downloads array.
                if let index = manager.activeDownloads.firstIndex(where: { $0.url == url }) {
                    /// Mark as completed and store final file location.
                    manager.activeDownloads[index].status = .completed
                    manager.activeDownloads[index].localURL = destinationURL
                    
                    /// Add to recent downloads list (FIFO queue, max 10).
                    manager.recentDownloads.insert(destinationURL, at: 0)  // Add to front
                    if manager.recentDownloads.count > 10 {
                        manager.recentDownloads.removeLast()  // Remove oldest
                    }
                    
                    /// Persist recent downloads to UserDefaults.
                    /// map(\.absoluteString) converts [URL] to [String] for storage.
                    UserDefaults.standard.set(manager.recentDownloads.map(\.absoluteString), forKey: "recentDownloads")
                }
                
                /// Broadcast completion to other app components.
                /// Other parts of the app can observe this notification.
                NotificationCenter.default.post(name: .downloadCompleted, object: nil, userInfo: ["url": destinationURL])
            }
        } catch {
            /// File operation failed (disk full, permissions, etc.)
            Task { @MainActor in
                manager.handleDownloadError(url: url, error: error)
            }
        }
    }
    
    /// Called periodically as download progresses.
    ///
    /// **Frequency**: Every few KB downloaded (varies by connection speed).
    ///
    /// **Use case**: Update progress bars in the UI.
    ///
    /// **Parameters**:
    /// - bytesWritten: Bytes downloaded in this callback
    /// - totalBytesWritten: Total bytes downloaded so far
    /// - totalBytesExpectedToWrite: Total file size (may be -1 if unknown)
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let url = downloadTask.originalRequest?.url else { return }
        
        /// Calculate progress as a percentage (0.0 to 1.0).
        /// Example: 5MB / 10MB = 0.5 (50%)
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        /// Update UI on main thread.
        Task { @MainActor in
            if let index = manager.activeDownloads.firstIndex(where: { $0.url == url }) {
                manager.activeDownloads[index].progress = progress
            }
        }
    }
    
    /// Called when a download task completes with an error.
    ///
    /// **When called**: Network error, timeout, cancelled, etc.
    ///
    /// **Note**: Also called on successful completion with error=nil,
    /// but we only care about actual errors here.
    ///
    /// **Parameters**:
    /// - task: The task that completed
    /// - error: The error that occurred (nil if successful)
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        /// Only handle actual errors (error != nil).
        guard let error = error,
              let url = task.originalRequest?.url else { return }
        
        /// Report error to manager on main thread.
        Task { @MainActor in
            manager.handleDownloadError(url: url, error: error)
        }
        }
    }
}

// MARK: - DownloadManager Class

/// Manages all file downloads in the browser.
///
/// **@MainActor**: All operations run on the main thread for thread safety.
///
/// **final**: Cannot be subclassed.
///
/// **NSObject**: Required for URLSession delegate compatibility.
///
/// **ObservableObject**: SwiftUI views can observe @Published properties.
///
/// **Singleton**: Access via `DownloadManager.shared`.
///
/// **Features**:
/// - Track multiple downloads simultaneously
/// - Show progress for each download
/// - Cancel downloads
/// - Open downloaded files with share sheet
/// - Remember recent downloads
@MainActor
final class DownloadManager: NSObject, ObservableObject {
    // MARK: - Singleton
    
    /// The shared singleton instance.
    static let shared = DownloadManager()
    
    // MARK: - Published Properties
    // These properties notify SwiftUI views when they change.
    
    /// Array of currently downloading or completed downloads.
    ///
    /// **@Published**: SwiftUI views automatically update when this changes.
    ///
    /// **Use case**: Display download progress overlay in browser UI.
    @Published var activeDownloads: [DownloadProgress] = []
    
    /// List of recently downloaded files (max 10, FIFO).
    ///
    /// **Persistence**: Saved to UserDefaults between app launches.
    ///
    /// **Use case**: Show "Recent Downloads" list in settings.
    @Published var recentDownloads: [URL] = []
    
    /// Set of download IDs that user has dismissed from UI.
    ///
    /// **Purpose**: User can hide completed downloads without deleting them.
    @Published var dismissedDownloads: Set<UUID> = []
    
    // MARK: - Private Properties
    
    /// Maps download IDs to their URLSession tasks.
    ///
    /// **Purpose**: Allows cancelling downloads by ID.
    ///
    /// **Why dictionary?**: Fast O(1) lookup by UUID.
    private var downloadTasks: [UUID: URLSessionDownloadTask] = [:]
    
    /// The delegate helper that receives URLSession callbacks.
    ///
    /// **lazy**: Created when first accessed, not in init().
    /// Avoids circular initialization issues.
    private lazy var downloadDelegate = DownloadDelegateHelper(manager: self)
    
    /// The URLSession that handles all downloads.
    ///
    /// **lazy**: Created when first accessed.
    ///
    /// **Closure syntax**: The () at the end immediately executes the closure.
    /// This is a common pattern for complex initialization.
    ///
    /// **Configuration**: Uses default configuration (standard networking).
    ///
    /// **Delegate**: Set to downloadDelegate to receive callbacks.
    ///
    /// **delegateQueue nil**: Callbacks happen on a background queue.
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: downloadDelegate, delegateQueue: nil)
    }()
    
    // MARK: - Download Directory
    
    /// The directory where downloaded files are saved.
    ///
    /// **Computed property**: Has custom getter and setter.
    ///
    /// **Default**: iOS Documents directory (user-accessible in Files app).
    ///
    /// **Customizable**: User can change download location in settings.
    ///
    /// **Persistence**: Saved to UserDefaults.
    ///
    /// **Path example**: 
    /// `/Users/.../Documents/` (iOS)
    var downloadDirectory: URL {
        get {
            /// Try to load custom directory from UserDefaults.
            if let storedPath = UserDefaults.standard.string(forKey: "downloadDirectory"),
               let url = URL(string: storedPath) {
                return url
            }
            
            /// Default to iOS Documents directory.
            /// .first! is safe - every iOS app has a Documents directory.
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        }
        set {
            /// Save new directory to UserDefaults.
            UserDefaults.standard.set(newValue.absoluteString, forKey: "downloadDirectory")
            
            /// Notify other components that settings changed.
            NotificationCenter.default.post(name: .downloadSettingsChanged, object: nil)
        }
    }
    
    // MARK: - Initialization
    
    /// Private initializer (singleton pattern).
    ///
    /// **private**: Prevents external code from creating multiple instances.
    ///
    /// **override**: Required because NSObject has its own init().
    ///
    /// **Initialization**:
    /// 1. Load recent downloads from UserDefaults
    /// 2. URLSession and delegate are created lazily when first needed
    private override init() {
        /// Load previously downloaded files from persistent storage.
        /// Stored as [String] (URL strings), converted back to [URL].
        /// compactMap removes any invalid URLs.
        if let stored = UserDefaults.standard.array(forKey: "recentDownloads") as? [String] {
            self.recentDownloads = stored.compactMap { URL(string: $0) }
        }
    }
    
    // MARK: - Public Methods
    
    // MARK: - Download Permission & Confirmation
    
    /// Shows an alert when downloads are disabled, directing user to settings.
    private func showDownloadsDisabledAlert() {
        Task { @MainActor in
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootVC = window.rootViewController else {
                return
            }
            
            let alert = UIAlertController(
                title: "Downloads Disabled",
                message: "Downloads are currently disabled. Enable downloads in Settings to save files from websites.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                // Post notification that settings should be opened to Downloads section
                NotificationCenter.default.post(name: NSNotification.Name("OpenDownloadSettings"), object: nil)
            })
            rootVC.present(alert, animated: true)
        }
    }
    
    /// Shows Brave-style download confirmation alert before starting download.
    ///
    /// **Brave Approach**: User must explicitly confirm each download with details:
    /// - Filename (truncated to 33 chars, like Brave)
    /// - Domain/host
    /// - File size (if known)
    ///
    /// **Returns**: `true` if user tapped Download, `false` if cancelled
    private func showDownloadConfirmation(for url: URL, filename: String, fileSize: Int64?) async -> Bool {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first,
                      let rootVC = window.rootViewController else {
                    continuation.resume(returning: false)
                    return
                }
                
                // Extract host from URL
                let host = url.host ?? url.absoluteString
                
                // Truncate filename to 33 chars (Brave's approach)
                let truncatedFilename: String
                if filename.count > 33 {
                    let start = filename.prefix(15)
                    let end = filename.suffix(15)
                    truncatedFilename = "\(start)...\(end)"
                } else {
                    truncatedFilename = filename
                }
                
                // Format file size if available
                let fileSizeText: String?
                if let fileSize = fileSize, fileSize > 0 {
                    fileSizeText = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
                } else {
                    fileSizeText = nil
                }
                
                // Build title: "filename - host"
                let title = "\(truncatedFilename) - \(host)"
                
                // Build download button text
                var downloadButtonText = "Download"
                if let fileSizeText = fileSizeText {
                    downloadButtonText += " (\(fileSizeText))"
                }
                
                let alert = UIAlertController(
                    title: title,
                    message: nil,
                    preferredStyle: .actionSheet
                )
                
                alert.addAction(UIAlertAction(title: downloadButtonText, style: .default) { _ in
                    continuation.resume(returning: true)
                })
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    continuation.resume(returning: false)
                })
                
                // Configure popover for iPad
                if let popover = alert.popoverPresentationController {
                    popover.sourceView = window
                    popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.maxY - 16, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                
                rootVC.present(alert, animated: true)
            }
        }
    }
    
    /// Starts downloading a file from the given URL.
    ///
    /// **Process**:
    /// 1. Check if downloads are enabled (App Store compliance)
    /// 2. Show Brave-style confirmation alert
    /// 3. Create URLSession download task
    /// 4. Create DownloadProgress to track it
    /// 5. Add to activeDownloads array
    /// 6. Start the download
    ///
    /// **Permission Check**: Downloads disabled by default for App Store compliance.
    /// User must enable in settings, then confirm each individual download.
    ///
    /// **Progress tracking**: Delegate callbacks update the progress.
    ///
    /// **Parameters**:
    /// - url: The URL to download from
    /// - suggestedFilename: Optional filename override (uses URL's filename if nil)
    ///
    /// **Example**:
    /// ```swift
    /// let url = URL(string: "https://example.com/document.pdf")!
    /// DownloadManager.shared.downloadFile(from: url)
    /// ```
    func downloadFile(from url: URL, suggestedFilename: String? = nil) {
        // Check if downloads are enabled
        guard BrowserSettings.shared.downloadsEnabled else {
            showDownloadsDisabledAlert()
            return
        }
        
        // Get filename and prepare for confirmation
        let filename = suggestedFilename ?? url.lastPathComponent
        
        // Show Brave-style confirmation alert
        Task {
            let confirmed = await showDownloadConfirmation(for: url, filename: filename, fileSize: nil)
            
            guard confirmed else {
                // User cancelled
                return
            }
            
            // User confirmed - proceed with download
            await MainActor.run {
                self.startDownload(from: url, filename: filename)
            }
        }
    }
    
    /// Internal method to actually start the download after confirmation.
    private func startDownload(from url: URL, filename: String) {
        /// Create URLSession download task.
        /// This doesn't start the download yet - just creates the task object.
        let task = session.downloadTask(with: url)
        
        /// Create progress tracker for this download.
        let progress = DownloadProgress(
            url: url,
            fileName: filename,  // Use the confirmed filename
            progress: 0,      // Start at 0%
            status: .downloading
        )
        
        /// Add to tracking arrays.
        activeDownloads.append(progress)           // For UI display
        downloadTasks[progress.id] = task          // For cancellation
        
        /// Start the download.
        /// From this point, delegate callbacks will fire with progress updates.
        task.resume()
    }
    
    // MARK: - Error Handling
    
    /// Handles download errors (called by delegate).
    ///
    /// **fileprivate**: Only accessible within this file (by delegate helper).
    ///
    /// **Actions**:
    /// 1. Mark download as failed
    /// 2. Store error for display
    /// 3. Broadcast failure notification
    fileprivate func handleDownloadError(url: URL, error: Error) {
        /// Find the download in our tracking array.
        if let index = activeDownloads.firstIndex(where: { $0.url == url }) {
            activeDownloads[index].status = .failed
            activeDownloads[index].error = error
        }
        
        /// Notify other app components about the failure.
        NotificationCenter.default.post(name: .downloadFailed, object: nil, userInfo: ["error": error])
    }
    
    // MARK: - Download Control
    
    /// Cancels an active download.
    ///
    /// **Effects**:
    /// 1. Cancel the URLSession task
    /// 2. Remove from tracking
    /// 3. Mark as dismissed so UI hides it
    ///
    /// **Parameter**:
    /// - id: The download's unique identifier
    func cancelDownload(id: UUID) {
        /// Cancel the underlying network task.
        downloadTasks[id]?.cancel()
        downloadTasks.removeValue(forKey: id)
        
        /// Remove from active downloads list.
        if let index = activeDownloads.firstIndex(where: { $0.id == id }) {
            activeDownloads.remove(at: index)
        }
        
        /// Mark as dismissed so it doesn't reappear.
        dismissedDownloads.insert(id)
    }
    
    /// Dismisses a download from the UI without cancelling it.
    ///
    /// **Use case**: User closes the download notification but file keeps downloading.
    ///
    /// **Parameter**:
    /// - id: The download's unique identifier
    func dismissDownload(id: UUID) {
        dismissedDownloads.insert(id)
    }
    
    /// Removes completed and dismissed downloads from the active list.
    ///
    /// **Use case**: "Clear All" button in downloads UI.
    ///
    /// **Note**: Only clears from activeDownloads - files remain on disk.
    func clearCompletedDownloads() {
        activeDownloads.removeAll { $0.status == .completed || dismissedDownloads.contains($0.id) }
    }
    
    // MARK: - Directory Access
    
    /// Returns the default iOS Documents directory.
    ///
    /// **Convenience property**: Shortcut to the standard download location.
    ///
    /// **Path**: `/Users/.../Documents/`
    var defaultDocumentsDirectory: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    // MARK: - Recent Downloads Management
    
    /// Clears the recent downloads history.
    ///
    /// **Note**: Only clears the list - doesn't delete files from disk.
    func clearRecentDownloads() {
        recentDownloads.removeAll()
        UserDefaults.standard.set([], forKey: "recentDownloads")
    }
    
    // MARK: - File Interaction
    
    /// Opens the downloaded file with iOS's share sheet.
    ///
    /// **Share sheet features**:
    /// - Quick Look preview
    /// - Open in other apps
    /// - Share via AirDrop, Messages, Mail
    /// - Save to Files app
    ///
    /// **Parameter**:
    /// - url: Local file URL of the downloaded file
    ///
    /// **Example**: User taps a completed download to open it.
    func openDownloadedFile(at url: URL) {
        /// Create iOS share sheet with the file.
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        /// Present from the root view controller.
        /// This navigation ensures the sheet appears on top of everything.
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    /// Shows the file in Files app or share options.
    ///
    /// **iOS note**: iOS doesn't have a true "Show in Finder" like macOS.
    /// We use the share sheet to provide similar functionality.
    ///
    /// **Parameter**:
    /// - url: Local file URL of the downloaded file
    func showInFinder(url: URL) {
        /// On iOS, use share sheet (same as openDownloadedFile).
        /// On macOS, this would use NSWorkspace.shared.activateFileViewerSelecting()
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}


// MARK: - Notification Names

/// Notification names for download-related events.
///
/// **Usage**: Other parts of the app can observe these notifications.
///
/// **Example**:
/// ```swift
/// NotificationCenter.default.addObserver(
///     forName: .downloadCompleted,
///     object: nil,
///     queue: .main
/// ) { notification in
///     if let url = notification.userInfo?["url"] as? URL {
///         print("Download completed: \(url.lastPathComponent)")
///     }
/// }
/// ```
extension Notification.Name {
    /// Posted when download directory setting changes.
    static let downloadSettingsChanged = Notification.Name("downloadSettingsChanged")
    
    /// Posted when a download completes successfully.
    /// userInfo contains ["url": URL] with the local file URL.
    static let downloadCompleted = Notification.Name("downloadCompleted")
    
    /// Posted when a download fails.
    /// userInfo contains ["error": Error] with the failure reason.
    static let downloadFailed = Notification.Name("downloadFailed")
}

// MARK: - Architecture Summary
//
// DownloadManager orchestrates file downloads using URLSession.
//
// ┌─────────────────────────────────────────────────────────┐
// │  DownloadManager Architecture  │
// └─────────────────────────────────────────────────────────┘
//
// Component Flow:
// ===============
//
//  User taps download link
//         ↓
//  downloadFile(from:) called
//         ↓
//  URLSession creates download task
//         ↓
//  Task starts downloading (background thread)
//         ↓
//  Delegate receives progress callbacks
//         ↓
//  Update activeDownloads[].progress
//         ↓
//  SwiftUI views automatically update progress bars
//         ↓
//  Download completes
//         ↓
//  Move file to Documents directory
//         ↓
//  Mark as completed, add to recent downloads
//         ↓
//  Post .downloadCompleted notification
//         ↓
//  User can open file with share sheet
//
// Thread Safety:
// =============
//
// @MainActor on class:
// - All properties accessed on main thread
// - All SwiftUI updates happen on main thread
//
// Delegate callbacks:
// - nonisolated methods called on URLSession's queue
// - Use Task { @MainActor } to switch to main thread for updates
//
// This prevents:
// - Race conditions
// - UI updates on background threads (crashes)
// - Data corruption from concurrent access
//
// State Machine:
// =============
//
// Download lifecycle:
//
//  Created (downloadFile called)
//       ↓
//  .downloading (progress 0-100%)
//       ↓
//   ┌───┴───┐
//   ↓       ↓
// .completed  .failed
//
// Possible transitions:
// - .downloading → .completed (success)
// - .downloading → .failed (error, cancelled)
//
// No other transitions are possible.
//
// Data Persistence:
// =================
//
// Recent downloads (UserDefaults):
// - Array of URL strings
// - Max 10 items (FIFO)
// - Survives app restarts
//
// Downloaded files (FileSystem):
// - Stored in Documents directory
// - Visible in Files app
// - Backed up to iCloud (if enabled)
//
// Active downloads (Memory only):
// - Lost on app termination
// - Could be improved with background URLSession for persistence
//
// UI Integration:
// ==============
//
// SwiftUI observes activeDownloads:
//
// struct DownloadOverlay: View {
//     @ObservedObject var manager = DownloadManager.shared
//     
//     var body: some View {
//         ForEach(manager.activeDownloads) { download in
//             HStack {
//                 Text(download.fileName)
//                 ProgressView(value: download.progress)
//                 Button("Cancel") {
//                     manager.cancelDownload(id: download.id)
//                 }
//             }
//         }
//     }
// }
//
// Performance Characteristics:
// ==========================
//
// Memory usage:
// - ~1KB per active download
// - Minimal overhead (mostly just tracking structs)
//
// Download speed:
// - Limited by network and URLSession
// - Multiple concurrent downloads supported
// - No artificial throttling
//
// UI responsiveness:
// - Progress updates ~every 64KB (URLSession default)
// - Main thread updates minimal (just property changes)
// - No UI freezing during downloads
//
// Limitations:
// ===========
//
// Current implementation:
// ✓ Foreground downloads only
// ✓ Lost if app terminates
// ✓ No resume support for interrupted downloads
// ✓ No bandwidth limit controls
//
// Could be improved with:
// - Background URLSession (downloads continue when app closed)
// - Resumable downloads (restart from where it left off)
// - Bandwidth throttling (respect cellular data limits)
// - Download queue management (prioritize important files)
//
// Best Practices:
// ==============
//
// ✅ DO use DownloadManager.shared (singleton)
// ✅ DO observe activeDownloads with @ObservedObject
// ✅ DO check NetworkMonitor before starting downloads
// ✅ DO handle .failed status gracefully
// ✅ DO clean up with clearCompletedDownloads()
//
// ❌ DON'T create multiple DownloadManager instances
// ❌ DON'T modify activeDownloads directly (read-only from outside)
// ❌ DON'T assume downloads survive app termination
// ❌ DON'T download large files on cellular without warning user
//
// Integration with EvoArc:
// =======================
//
// EvoArc uses DownloadManager to:
// - Download files from web pages
// - Show download progress overlay
// - Save files to iOS Documents
// - Let users share/preview downloaded files
// - Track recent downloads in settings
//
// This is production-quality download management for iOS browsers.
