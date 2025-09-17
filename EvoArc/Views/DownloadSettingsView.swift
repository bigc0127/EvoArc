import SwiftUI

#if os(iOS)
import UIKit
import UniformTypeIdentifiers

struct DocumentPickerView: UIViewControllerRepresentable {
    let downloadManager: DownloadManager
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.delegate = context.coordinator
        picker.directoryURL = downloadManager.downloadDirectory
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let selectedURL = urls.first else { return }
            
            // Grant security-scoped resource access
            let accessGranted = selectedURL.startAccessingSecurityScopedResource()
            defer {
                if accessGranted {
                    selectedURL.stopAccessingSecurityScopedResource()
                }
            }
            
            // Update download directory
            parent.downloadManager.downloadDirectory = selectedURL
        }
    }
}
#endif

struct DownloadSettingsView: View {
    @ObservedObject private var downloadManager = DownloadManager.shared
    @ObservedObject private var settings = BrowserSettings.shared
    @State private var showDocumentPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Download Location
            HStack {
                Text("Downloads Folder:")
                    .font(.caption)
                    .foregroundColor(.secondaryLabel)
                
                Spacer()
                
                Text(downloadManager.downloadDirectory.path)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                #if os(macOS)
                Button("Change...") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    
                    if panel.runModal() == .OK {
                        if let url = panel.url {
                            downloadManager.downloadDirectory = url
                        }
                    }
                }
                .buttonStyle(.bordered)
                #else
                Button("Change...") {
                    showDocumentPicker = true
                }
                .buttonStyle(.bordered)
                .sheet(isPresented: $showDocumentPicker) {
                    DocumentPickerView(downloadManager: downloadManager)
                }
                #endif
            }
            
            // Download Options
            Toggle("Show download notifications", isOn: $settings.showDownloadNotifications)
                .font(.caption)
                .padding(.vertical, 4)
            
            Toggle("Auto-open downloads when complete", isOn: $settings.autoOpenDownloads)
                .font(.caption)
                .padding(.vertical, 4)
            
            // Recent Downloads
            if !downloadManager.recentDownloads.isEmpty {
                Text("Recent Downloads")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.top, 8)
                
                ForEach(downloadManager.recentDownloads, id: \.self) { url in
                    HStack {
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Button {
                            downloadManager.openDownloadedFile(at: url)
                        } label: {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            downloadManager.showInFinder(url: url)
                        } label: {
                            Image(systemName: "folder")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
                
                Button("Clear Recent Downloads") {
                    downloadManager.clearRecentDownloads()
                }
                .font(.caption)
                .foregroundColor(.red)
                .padding(.top, 4)
            }
            
            // Active Downloads
            if !downloadManager.activeDownloads.isEmpty {
                Text("Active Downloads")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.top, 8)
                
                ForEach(downloadManager.activeDownloads) { download in
                    HStack {
                        if !downloadManager.dismissedDownloads.contains(download.id) {
                            Text(download.fileName)
                                .font(.caption)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            switch download.status {
                            case .downloading:
                                ProgressView(value: download.progress)
                                    .progressViewStyle(.linear)
                                    .frame(width: 60)
                                
                                Button {
                                    downloadManager.cancelDownload(id: download.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                                
                            case .completed:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                
                                if let localURL = download.localURL {
                                    Button {
                                        downloadManager.openDownloadedFile(at: localURL)
                                    } label: {
                                        Image(systemName: "doc.text.magnifyingglass")
                                            .foregroundColor(.accentColor)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Button {
                                    downloadManager.dismissDownload(id: download.id)
                                } label: {
                                    Image(systemName: "xmark.circle")
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(.plain)
                                
                            case .failed:
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text(download.error?.localizedDescription ?? "Failed")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                
                                Button {
                                    downloadManager.dismissDownload(id: download.id)
                                } label: {
                                    Image(systemName: "xmark.circle")
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                
                if downloadManager.activeDownloads.contains(where: { $0.status == .completed }) {
                    Button("Clear Completed") {
                        downloadManager.clearCompletedDownloads()
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .padding(.top, 4)
                }
            }
        }
    }
}

#if os(iOS)
extension DownloadSettingsView {
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DownloadSettingsView
        
        init(_ parent: DownloadSettingsView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let selectedURL = urls.first else { return }
            
            // Grant security-scoped resource access
            let accessGranted = selectedURL.startAccessingSecurityScopedResource()
            defer {
                if accessGranted {
                    selectedURL.stopAccessingSecurityScopedResource()
                }
            }
            
            // Update download directory
            parent.downloadManager.downloadDirectory = selectedURL
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}
#endif
