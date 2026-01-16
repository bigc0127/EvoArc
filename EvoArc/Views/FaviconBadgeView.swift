import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct FaviconBadgeView: View {
    let url: URL?
    let fallbackLetter: String
    let size: CGFloat

    @State private var image: PlatformImage?

    var body: some View {
        Group {
            // Check if this is the custom new tab page URL
            if url?.absoluteString == "evoarc://newtab" {
                // Show Safari icon for new tab page
                Image(systemName: "safari")
                    .font(.system(size: size * 0.8, weight: .regular))
                    .foregroundColor(.accentColor)
            } else if let image {
                #if os(iOS)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                #else
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                #endif
            } else {
                Text(fallbackLetter)
                    .font(.system(size: size * 0.7, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            // Don't try to fetch favicon for new tab page
            if url?.absoluteString != "evoarc://newtab" {
                FaviconManager.shared.image(for: url) { self.image = $0 }
            }
        }
        .onChange(of: url?.host ?? "") { oldValue, newValue in
            // Don't try to fetch favicon for new tab page
            if url?.absoluteString != "evoarc://newtab" {
                FaviconManager.shared.image(for: url) { self.image = $0 }
            }
        }
    }
}