import SwiftUI

struct DownloadProgressOverlay: View {
    @StateObject private var downloadManager = DownloadManager.shared
    @Binding var isPresented: Bool
    
    private var backgroundColor: Color {
        #if os(iOS)
        Color(uiColor: .systemBackground)
        #else
        Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    var body: some View {
        VStack {
            if !downloadManager.activeDownloads.isEmpty {
                downloadsContent
            }
            Spacer()
        }
        .animation(.spring(), value: downloadManager.activeDownloads.isEmpty)
    }
    
    private var downloadsContent: some View {
        VStack(spacing: 8) {
            headerView
            downloadsList
        }
        .padding()
        .background(backgroundColor.opacity(0.95))
        .cornerRadius(12)
        .shadow(radius: 10)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .padding()
    }
    
    private var headerView: some View {
        HStack {
            Text("Downloads")
                .font(.headline)
            Spacer()
            HStack(spacing: 8) {
                Button {
                    downloadManager.clearCompletedDownloads()
                } label: {
                    Text("Clear Completed")
                        .font(.caption)
                }
                .disabled(!downloadManager.activeDownloads.contains(where: { $0.status == .completed }))
                
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var downloadsList: some View {
        ForEach(downloadManager.activeDownloads) { download in
            downloadRow(for: download)
        }
    }
    
    private func downloadRow(for download: DownloadProgress) -> some View {
        HStack {
            downloadInfo(for: download)
            Spacer()
            downloadActions(for: download)
        }
        .padding(8)
        .background(backgroundColor.opacity(0.8))
        .cornerRadius(8)
    }
    
    private func downloadInfo(for download: DownloadProgress) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(download.fileName)
                .font(.subheadline)
                .lineLimit(1)
            
            downloadStatus(for: download)
        }
    }
    
    @ViewBuilder
    private func downloadStatus(for download: DownloadProgress) -> some View {
        switch download.status {
        case .downloading:
            ProgressView(value: download.progress, total: 1.0)
                .progressViewStyle(.linear)
        case .completed:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .failed:
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text(download.error?.localizedDescription ?? "Failed")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    @ViewBuilder
    private func downloadActions(for download: DownloadProgress) -> some View {
        HStack(spacing: 8) {
            switch download.status {
            case .downloading:
                Button {
                    downloadManager.cancelDownload(id: download.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                
            case .completed:
                if let localURL = download.localURL {
                    Button {
                        downloadManager.openDownloadedFile(at: localURL)
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        downloadManager.showInFinder(url: localURL)
                    } label: {
                        Image(systemName: "folder")
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                
            case .failed:
                Button {
                    // Could retry the download here
                    downloadManager.downloadFile(from: download.url)
                } label: {
                    Image(systemName: "arrow.clockwise.circle")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct DownloadProgressOverlay_Previews: PreviewProvider {
    static var previews: some View {
        DownloadProgressOverlay(isPresented: .constant(true))
    }
}
