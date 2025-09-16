//
//  BookmarksView.swift
//  EvoArc
//
//  Created on 2025-09-16.
//

import SwiftUI
import WebKit
#if os(iOS)
import UIKit
#else
import AppKit
#endif

#if os(iOS)
struct BookmarksView: View {
    @StateObject private var bookmarkManager = BookmarkManager.shared
    @ObservedObject var tabManager: TabManager
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var showingAddFolder = false
    @State private var showingFolderRename = false
    @State private var newFolderName = ""
    @State private var renamingFolder: BookmarkFolder?
    @State private var showingDeleteConfirmation = false
    @State private var folderToDelete: BookmarkFolder?
    @State private var selectedFolder: BookmarkFolder?
    @State private var showingFolders = false

    private var filteredBookmarks: [Bookmark] {
        let baseBookmarks = searchText.isEmpty ? bookmarkManager.bookmarks : bookmarkManager.searchBookmarks(query: searchText)
        if let selectedFolder = selectedFolder {
            return baseBookmarks.filter { $0.folderID == selectedFolder.id }
        }
        return baseBookmarks
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Folder selection header
                if !bookmarkManager.folders.isEmpty {
                    VStack(spacing: 0) {
                        Button(action: {
                            showingFolders = true
                        }) {
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundColor(.accentColor)
                                Text(selectedFolder?.name ?? "All Bookmarks")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .background(Color(UIColor.secondarySystemBackground))
                        Divider()
                    }
                }
                
                // Bookmarks list
                List {
                    ForEach(filteredBookmarks) { bookmark in
                        BookmarkRow(
                            bookmark: bookmark,
                            onTap: {
                                if let currentTab = tabManager.selectedTab {
                                    currentTab.webView?.load(URLRequest(url: bookmark.url))
                                } else {
                                    tabManager.createNewTab(url: bookmark.url)
                                }
                                dismiss()
                            },
                            onEdit: { newTitle in bookmarkManager.updateBookmark(bookmark, title: newTitle) },
                            onDelete: { bookmarkManager.removeBookmark(bookmark) }
                        )
                    }
                    
                    if filteredBookmarks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bookmark")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary.opacity(0.6))
                            Text(selectedFolder != nil ? "No bookmarks in this folder" : searchText.isEmpty ? "No bookmarks yet" : "No matching bookmarks")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(action: { showingAddFolder = true }) {
                            Label("New Folder", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search bookmarks")
        .sheet(isPresented: $showingAddFolder) { addFolderSheet }
        .sheet(isPresented: $showingFolderRename) { renameFolderSheet }
        .sheet(isPresented: $showingFolders) { folderSelectionSheet }
        .confirmationDialog("Delete Folder", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Move Bookmarks to 'Favorites'") {
                if let folder = folderToDelete { let favoritesID = bookmarkManager.favoritesFolder?.id; bookmarkManager.removeFolder(folder, moveBookmarksToFolder: favoritesID) }
            }
            Button("Delete", role: .destructive) { if let folder = folderToDelete { bookmarkManager.removeFolder(folder) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let folder = folderToDelete { Text("What would you like to do with the bookmarks in '\(folder.name)'?") }
        }
    }

    @ViewBuilder private var addFolderSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Folder Name").font(.headline)
                    TextField("Enter folder name", text: $newFolderName).textFieldStyle(.roundedBorder)
                }.padding()
                Spacer()
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { showingAddFolder = false; newFolderName = "" } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        if !newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            _ = bookmarkManager.createFolder(name: newFolderName.trimmingCharacters(in: .whitespacesAndNewlines))
                            showingAddFolder = false; newFolderName = ""
                        }
                    }.disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder private var renameFolderSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Folder Name").font(.headline)
                    TextField("Enter folder name", text: $newFolderName).textFieldStyle(.roundedBorder)
                }.padding()
                Spacer()
            }
            .navigationTitle("Rename Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { showingFolderRename = false; renamingFolder = nil; newFolderName = "" } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let folder = renamingFolder, !newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            bookmarkManager.renameFolder(folder, newName: newFolderName.trimmingCharacters(in: .whitespacesAndNewlines))
                            showingFolderRename = false; renamingFolder = nil; newFolderName = ""
                        }
                    }.disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    @ViewBuilder private var folderSelectionSheet: some View {
        NavigationView {
            List {
                // All Bookmarks option
                Button(action: {
                    selectedFolder = nil
                    showingFolders = false
                }) {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.accentColor)
                        Text("All Bookmarks")
                            .font(.body)
                            .fontWeight(.medium)
                        Spacer()
                        if selectedFolder == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                        Text("(\(bookmarkManager.bookmarks.count))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                // Individual folders
                ForEach(bookmarkManager.folders) { folder in
                    Button(action: {
                        selectedFolder = folder
                        showingFolders = false
                    }) {
                        HStack {
                            Image(systemName: "folder")
                                .foregroundColor(.accentColor)
                            Text(folder.name)
                                .font(.body)
                                .fontWeight(.medium)
                            Spacer()
                            if selectedFolder?.id == folder.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                            Text("(\(bookmarkManager.getBookmarks(in: folder).count))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if folder.name != "Favorites" {
                            Button("Delete", role: .destructive) {
                                folderToDelete = folder
                                showingDeleteConfirmation = true
                                showingFolders = false
                            }
                        }
                        Button("Rename") {
                            renamingFolder = folder
                            newFolderName = folder.name
                            showingFolderRename = true
                            showingFolders = false
                        }
                        .tint(.orange)
                    }
                }
            }
            .navigationTitle("Folders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Add Folder") {
                        showingAddFolder = true
                        showingFolders = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingFolders = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
#else
struct BookmarksView: View {
    @StateObject private var bookmarkManager = BookmarkManager.shared
    @ObservedObject var tabManager: TabManager
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var showingAddFolder = false
    @State private var showingFolderRename = false
    @State private var newFolderName = ""
    @State private var renamingFolder: BookmarkFolder?
    @State private var selectedFolder: BookmarkFolder?
    @State private var showingDeleteConfirmation = false
    @State private var folderToDelete: BookmarkFolder?

    private var filteredBookmarks: [Bookmark] {
        let baseBookmarks = searchText.isEmpty ? bookmarkManager.bookmarks : bookmarkManager.searchBookmarks(query: searchText)
        if let selectedFolder = selectedFolder {
            return baseBookmarks.filter { $0.folderID == selectedFolder.id }
        }
        return baseBookmarks
    }

    var body: some View {
        NavigationView {
            HStack(alignment: .top, spacing: 1) {
                // Sidebar with folders
                VStack(alignment: .leading, spacing: 0) {
                    // Sidebar header
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(bookmarkManager.bookmarks.count)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Text("bookmarks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: { showingAddFolder = true }) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.borderless)
                        .help("New Folder")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    // Folders list
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            // All bookmarks option
                            Button(action: { 
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedFolder = nil 
                                }
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: selectedFolder == nil ? "folder.fill" : "folder")
                                        .font(.system(size: 14))
                                        .foregroundColor(selectedFolder == nil ? .accentColor : .secondary)
                                        .frame(width: 16)
                                    Text("All Bookmarks")
                                        .font(.system(size: 13, weight: selectedFolder == nil ? .medium : .regular))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(bookmarkManager.bookmarks.count)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(selectedFolder == nil ? Color.accentColor.opacity(0.1) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                            
                            // Individual folders
                            ForEach(bookmarkManager.folders) { folder in
                                Button(action: { 
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedFolder = folder
                                    }
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: selectedFolder?.id == folder.id ? "folder.fill" : "folder")
                                            .font(.system(size: 14))
                                            .foregroundColor(selectedFolder?.id == folder.id ? .accentColor : .secondary)
                                            .frame(width: 16)
                                        Text(folder.name)
                                            .font(.system(size: 13, weight: selectedFolder?.id == folder.id ? .medium : .regular))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Spacer()
                                        Text("\(bookmarkManager.getBookmarks(in: folder).count)")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(selectedFolder?.id == folder.id ? Color.accentColor.opacity(0.1) : Color.clear)
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Rename") {
                                        renamingFolder = folder
                                        newFolderName = folder.name
                                        showingFolderRename = true
                                    }
                                    if folder.name != "Favorites" {
                                        Button("Delete", role: .destructive) {
                                            folderToDelete = folder
                                            showingDeleteConfirmation = true
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Spacer()
                }
                .frame(width: 200)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()

                // Main content area
                VStack(spacing: 0) {
                    if filteredBookmarks.isEmpty {
                        // Empty state
                        VStack(spacing: 20) {
                            Image(systemName: "bookmark")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary.opacity(0.6))
                            
                            Text(selectedFolder != nil ? "No bookmarks in this folder" : searchText.isEmpty ? "No bookmarks yet" : "No matching bookmarks")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(filteredBookmarks) { bookmark in
                                BookmarkRow(
                                    bookmark: bookmark,
                                    onTap: {
                                        if let currentTab = tabManager.selectedTab {
                                            currentTab.webView?.load(URLRequest(url: bookmark.url))
                                        } else {
                                            tabManager.createNewTab(url: bookmark.url)
                                        }
                                        dismiss()
                                    },
                                    onEdit: { newTitle in 
                                        bookmarkManager.updateBookmark(bookmark, title: newTitle) 
                                    },
                                    onDelete: { 
                                        bookmarkManager.removeBookmark(bookmark) 
                                    }
                                )
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .frame(width: 800, height: 600)
        .searchable(text: $searchText, prompt: "Search bookmarks")
        .sheet(isPresented: $showingAddFolder) { addFolderSheet }
        .sheet(isPresented: $showingFolderRename) { renameFolderSheet }
        .confirmationDialog("Delete Folder", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Move Bookmarks to 'Favorites'") {
                if let folder = folderToDelete {
                    let favoritesID = bookmarkManager.favoritesFolder?.id
                    bookmarkManager.removeFolder(folder, moveBookmarksToFolder: favoritesID)
                }
            }
            Button("Delete", role: .destructive) {
                if let folder = folderToDelete {
                    bookmarkManager.removeFolder(folder)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let folder = folderToDelete {
                Text("What would you like to do with the bookmarks in '\(folder.name)'?")
            }
        }
    }

    @ViewBuilder private var addFolderSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Folder Name").font(.headline)
                    TextField("Enter folder name", text: $newFolderName).textFieldStyle(.roundedBorder)
                }.padding()
                Spacer()
            }
            .navigationTitle("New Folder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingAddFolder = false; newFolderName = "" } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        if !newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            _ = bookmarkManager.createFolder(name: newFolderName.trimmingCharacters(in: .whitespacesAndNewlines))
                            showingAddFolder = false; newFolderName = ""
                        }
                    }.disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    @ViewBuilder private var renameFolderSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Folder Name").font(.headline)
                    TextField("Enter folder name", text: $newFolderName).textFieldStyle(.roundedBorder)
                }.padding()
                Spacer()
            }
            .navigationTitle("Rename Folder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingFolderRename = false; renamingFolder = nil; newFolderName = "" } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let folder = renamingFolder, !newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            bookmarkManager.renameFolder(folder, newName: newFolderName.trimmingCharacters(in: .whitespacesAndNewlines))
                            showingFolderRename = false; renamingFolder = nil; newFolderName = ""
                        }
                    }.disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
#endif

struct BookmarkRow: View {
    let bookmark: Bookmark
    let onTap: () -> Void
    let onEdit: (String) -> Void
    let onDelete: () -> Void
    
    @State private var showingEditTitle = false
    @State private var editingTitle = ""
    @ObservedObject private var bookmarkManager = BookmarkManager.shared
    
    private var secondarySystemBackgroundColor: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemBackground)
        #else
        Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(secondarySystemBackgroundColor)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "globe")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(bookmark.title)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                Text(bookmark.url.host ?? bookmark.url.absoluteString)
                    .font(.system(size: 14))
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let folderID = bookmark.folderID,
               let folder = bookmarkManager.folders.first(where: { $0.id == folderID }) {
                Text(folder.name)
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.2))
                    .foregroundColor(.accentColor)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .contextMenu {
            Button("Edit Title") { editingTitle = bookmark.title; showingEditTitle = true }
            Button("Copy URL") {
                #if os(iOS)
                UIPasteboard.general.string = bookmark.url.absoluteString
                #else
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(bookmark.url.absoluteString, forType: .string)
                #endif
            }
            Button("Delete", role: .destructive) { onDelete() }
        }
        .alert("Edit Bookmark Title", isPresented: $showingEditTitle) {
            TextField("Title", text: $editingTitle)
            Button("Save") { if !editingTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { onEdit(editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)) } }
            Button("Cancel", role: .cancel) {}
        }
    }
}

#Preview {
    BookmarksView(tabManager: TabManager())
}

#Preview {
    BookmarksView(tabManager: TabManager())
}