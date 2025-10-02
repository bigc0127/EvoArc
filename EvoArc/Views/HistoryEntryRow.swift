import SwiftUI

/// A reusable row component for displaying history entries consistently across iOS and macOS
struct HistoryEntryRow: View {
    let entry: HistoryEntry
    let onRemove: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon or favicon
                Image(systemName: "globe")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                
                // Title and URL
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(entry.url.host ?? entry.url.absoluteString)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Visit count and time
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(entry.visitCount) visits")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Text(entry.lastVisited.formatted(.relative(presentation: .named)))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                // Delete button
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let previewEntry = HistoryEntry(
        url: URL(string: "https://example.com")!,
        title: "Example Website",
        favicon: nil
    )
    
    return HistoryEntryRow(
        entry: previewEntry,
        onRemove: {},
        onTap: {}
    )
    .padding()
}