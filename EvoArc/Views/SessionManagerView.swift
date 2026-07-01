//
//  SessionManagerView.swift
//  EvoArc
//
//  UI for saving the current tabs as a named session and restoring/managing
//  previously saved sessions.
//

import SwiftUI

struct SessionManagerView: View {
    @ObservedObject private var sessionManager = SessionManager.shared
    @ObservedObject var tabManager: TabManager
    @Environment(\.dismiss) private var dismiss

    @State private var showSavePrompt = false
    @State private var newSessionName = ""
    @State private var renameTarget: BrowserSession?
    @State private var renameText = ""
    @State private var showClearConfirmation = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationView {
            List {
                Section {
                    Button {
                        newSessionName = ""
                        showSavePrompt = true
                    } label: {
                        Label("Save Current Tabs as Session", systemImage: "square.and.arrow.down")
                    }
                }

                if sessionManager.sessions.isEmpty {
                    Section {
                        Text("No saved sessions yet. Save your current tabs to quickly restore them later.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Section("Saved Sessions") {
                        ForEach(sessionManager.sessions) { session in
                            sessionRow(session)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                sessionManager.deleteSession(id: sessionManager.sessions[index].id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !sessionManager.sessions.isEmpty {
                        Button("Clear All", role: .destructive) { showClearConfirmation = true }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Save Session", isPresented: $showSavePrompt) {
                TextField("Session name", text: $newSessionName)
                Button("Save") {
                    sessionManager.saveSession(name: newSessionName, tabManager: tabManager)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Give this set of tabs a name so you can restore it later.")
            }
            .alert("Rename Session", isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )) {
                TextField("Session name", text: $renameText)
                Button("Rename") {
                    if let target = renameTarget {
                        sessionManager.renameSession(id: target.id, to: renameText)
                    }
                    renameTarget = nil
                }
                Button("Cancel", role: .cancel) { renameTarget = nil }
            }
            .confirmationDialog("Delete all saved sessions?",
                                isPresented: $showClearConfirmation,
                                titleVisibility: .visible) {
                Button("Clear All", role: .destructive) { sessionManager.clearAll() }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    private func sessionRow(_ session: BrowserSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.name)
                .font(.body)
                .lineLimit(1)
            Text("\(session.tabCount) tab\(session.tabCount == 1 ? "" : "s") · \(Self.dateFormatter.string(from: session.dateModified))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            sessionManager.restoreSession(session, into: tabManager)
            dismiss()
        }
        .contextMenu {
            Button {
                sessionManager.restoreSession(session, into: tabManager)
                dismiss()
            } label: { Label("Restore", systemImage: "arrow.uturn.backward") }
            Button {
                renameText = session.name
                renameTarget = session
            } label: { Label("Rename", systemImage: "pencil") }
            Button(role: .destructive) {
                sessionManager.deleteSession(id: session.id)
            } label: { Label("Delete", systemImage: "trash") }
        }
    }
}
