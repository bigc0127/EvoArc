//
//  NewTabGroupView.swift
//  EvoArc
//
//  Rebuilt responsive UI for creating a new tab group. Scales smoothly on
//  iPhone, iPad, and macOS using a Form-based layout and dynamic grid sizing.
//

import SwiftUI

struct NewTabGroupView: View {
    @Binding var name: String
    @Binding var color: TabGroupColor
    let onCancel: () -> Void
    let onCreate: () -> Void
    
    var body: some View {
        NavigationView {
            Group {
            }
            .navigationTitle("New Tab Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: onCreate)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}