import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers
import Observation
#if os(iOS)
import UIKit
#endif

/// Progress status of a download task
struct DownloadProgress: Identifiable {
    let id = UUID()
    let url: URL
    let fileName: String
    var progress: Double
    var status: DownloadStatus
    var localURL: URL?
    var error: Error?
    
    enum DownloadStatus {
        case downloading
        case completed
        case failed
    }
}

/// Manages download operations and settings
/// Helper class to handle URLSession delegate callbacks
@MainActor
private class DownloadDelegateHelper: NSObject, URLSessionDownloadDelegate {
    unowned let manager: DownloadManager
    
    init(manager: DownloadManager) {
        self.manager = manager
        super.init()
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let url = downloadTask.originalRequest?.url else { return }
        
        Task { @MainActor in
            let fileName = downloadTask.response?.suggestedFilename ?? url.lastPathComponent
            let destinationURL = manager.downloadDirectory.appendingPathComponent(fileName)
        
        do {
            // Ensure destination directory exists
            let destDir = destinationURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)
            
            Task { @MainActor in
                // Update the download status
                if let index = manager.activeDownloads.firstIndex(where: { $0.url == url }) {
                    manager.activeDownloads[index].status = .completed
                    manager.activeDownloads[index].localURL = destinationURL
                    
                    // Add to recent downloads
                    manager.recentDownloads.insert(destinationURL, at: 0)
                    if manager.recentDownloads.count > 10 {
                        manager.recentDownloads.removeLast()
                    }
                    UserDefaults.standard.set(manager.recentDownloads.map(\.absoluteString), forKey: "recentDownloads")
                }
                
                // Post notification for other parts of the app
                NotificationCenter.default.post(name: .downloadCompleted, object: nil, userInfo: ["url": destinationURL])
            }
        } catch {
            Task { @MainActor in
                manager.handleDownloadError(url: url, error: error)
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let url = downloadTask.originalRequest?.url else { return }
        
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        Task { @MainActor in
            if let index = manager.activeDownloads.firstIndex(where: { $0.url == url }) {
                manager.activeDownloads[index].progress = progress
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error,
              let url = task.originalRequest?.url else { return }
        
        Task { @MainActor in
            manager.handleDownloadError(url: url, error: error)
        }
        }
    }
}

@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()
    
@Published var activeDownloads: [DownloadProgress] = []
@Published var recentDownloads: [URL] = []
@Published var dismissedDownloads: Set<UUID> = []
    
    private var downloadTasks: [UUID: URLSessionDownloadTask] = [:]
    private lazy var downloadDelegate = DownloadDelegateHelper(manager: self)
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: downloadDelegate, delegateQueue: nil)
    }()
    
// The directory where downloads are saved
var downloadDirectory: URL {
        get {
            if let storedPath = UserDefaults.standard.string(forKey: "downloadDirectory"),
               let url = URL(string: storedPath) {
                return url
            }
            
            #if os(iOS)
            // On iOS, default to the Documents directory
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            #else
            // On macOS, default to Downloads folder
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            #endif
        }
        set {
            UserDefaults.standard.set(newValue.absoluteString, forKey: "downloadDirectory")
            NotificationCenter.default.post(name: .downloadSettingsChanged, object: nil)
        }
    }
    
    private override init() {
        // Load recent downloads
        if let stored = UserDefaults.standard.array(forKey: "recentDownloads") as? [String] {
            self.recentDownloads = stored.compactMap { URL(string: $0) }
        }
    }
    
    /// Start downloading a file from the given URL
    func downloadFile(from url: URL, suggestedFilename: String? = nil) {
        let task = session.downloadTask(with: url)
        
        // Create and store the download progress
        let progress = DownloadProgress(
            url: url,
            fileName: suggestedFilename ?? url.lastPathComponent,
            progress: 0,
            status: .downloading
        )
        activeDownloads.append(progress)
        downloadTasks[progress.id] = task
        
        task.resume()
    }
    
    fileprivate func handleDownloadError(url: URL, error: Error) {
        if let index = activeDownloads.firstIndex(where: { $0.url == url }) {
            activeDownloads[index].status = .failed
            activeDownloads[index].error = error
        }
        NotificationCenter.default.post(name: .downloadFailed, object: nil, userInfo: ["error": error])
    }
    
    /// Cancel an active download
    func cancelDownload(id: UUID) {
        downloadTasks[id]?.cancel()
        downloadTasks.removeValue(forKey: id)
        if let index = activeDownloads.firstIndex(where: { $0.id == id }) {
            activeDownloads.remove(at: index)
        }
        dismissedDownloads.insert(id)
    }
    
    /// Dismiss a download notification
    func dismissDownload(id: UUID) {
        dismissedDownloads.insert(id)
    }
    
    /// Clear completed downloads from the list
    func clearCompletedDownloads() {
        activeDownloads.removeAll { $0.status == .completed || dismissedDownloads.contains($0.id) }
    }
    
    /// Convenience to point to app Documents directory on iOS
    var defaultDocumentsDirectory: URL {
        #if os(iOS)
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        #else
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        #endif
    }
    
    /// Clear the recent downloads list
    func clearRecentDownloads() {
        recentDownloads.removeAll()
        UserDefaults.standard.set([], forKey: "recentDownloads")
    }
    
    /// Opens or shares the downloaded file
    func openDownloadedFile(at url: URL) {
        #if os(iOS)
        // Present a share sheet to preview/open the file
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        #else
        // Use NSWorkspace on macOS
        NSWorkspace.shared.open(url)
        #endif
    }
    
    /// Shows the downloaded file using the platform's file viewer
    func showInFinder(url: URL) {
        #if os(iOS)
        // Present a share sheet to reveal the file location or share it
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        #else
        // Use NSWorkspace on macOS
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
        #endif
    }
}


extension Notification.Name {
    static let downloadSettingsChanged = Notification.Name("downloadSettingsChanged")
    static let downloadCompleted = Notification.Name("downloadCompleted")
    static let downloadFailed = Notification.Name("downloadFailed")
}