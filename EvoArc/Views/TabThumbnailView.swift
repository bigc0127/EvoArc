import SwiftUI

struct TabThumbnailView: View {
    let tab: Tab
    @StateObject private var thumbnailManager = ThumbnailManager.shared
    @State private var shouldUpdate = false
    
    var body: some View {
GeometryReader { geo in
            ZStack {
                // Browser indicator in top right
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "safari")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(.secondary)
                            .padding(8)
                    }
                    Spacer()
                }
                .zIndex(1)
                
                if let thumbnail = thumbnailManager.getThumbnail(for: tab.id) {
                    #if os(iOS)
                    GeometryReader { geometry in
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                    .frame(width: geo.size.width, height: geo.size.width * (9/16))
                    .cornerRadius(UIScaleMetrics.scaledPadding(8))
                    .overlay(RoundedRectangle(cornerRadius: UIScaleMetrics.scaledPadding(8))
                        .stroke(Color.gray.opacity(0.2), lineWidth: 0.5))
                    #else
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.width * (9/16))
                        .clipped()
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                        )
                    #endif
                } else {
                    // Safari-style placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                            .frame(width: geo.size.width - 16, height: (geo.size.width - 16) * 1.33)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                            )
                        
                        VStack(spacing: 8) {
                            Text(tab.title.isEmpty ? "New Tab" : String(tab.title.prefix(20)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
        }
        .id(shouldUpdate) // Force view refresh when shouldUpdate changes
        .onReceive(NotificationCenter.default.publisher(for: .thumbnailDidUpdate)) { notification in
            if let tabID = notification.userInfo?["tabID"] as? String,
               tabID == tab.id {
                shouldUpdate.toggle()
            }
        }
    }
}
