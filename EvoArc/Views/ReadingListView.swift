//
//  ReadingListView.swift
//  EvoArc
//
//  Displays the user's saved Reading List and lets them open or remove items.
//

import SwiftUI

struct ReadingListView: View {
    @ObservedObject private var readingList = ReadingListManager.shared
    @ObservedObject var tabManager: TabManager
    @Environment(\.dismiss) private var dismiss

    @State private var showClearConfirmation = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationView {
            Group {
                if readingList.savedItems.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(readingList.savedItems) { item in
                            Button {
                                open(item)
                            } label: {
                                row(for: item)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                readingList.removeItem(id: readingList.savedItems[index].id)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Reading List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !readingList.savedItems.isEmpty {
                        Button("Clear All", role: .destructive) {
                            showClearConfirmation = true
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Clear the entire Reading List?",
                                isPresented: $showClearConfirmation,
                                titleVisibility: .visible) {
                Button("Clear All", role: .destructive) { readingList.clearAll() }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    private func row(for item: ReadingItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .foregroundColor(.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body)
                    .lineLimit(1)
                Text(item.url.host ?? item.url.absoluteString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text(Self.dateFormatter.string(from: item.dateAdded))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("No saved pages yet")
                .font(.headline)
            Text("Tap the menu on any page and choose \u{201C}Add to Reading List\u{201D} to save it for later.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func open(_ item: ReadingItem) {
        tabManager.createNewTab(url: item.url)
        dismiss()
    }
}
