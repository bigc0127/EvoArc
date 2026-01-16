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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("name".localized).font(.headline)
                    TextField("group_name".localized, text: $name)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                    
                    Text("color".localized).font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 56, maximum: 72), spacing: 12)], spacing: 12) {
                        ForEach(TabGroupColor.allCases) { c in
                            Button(action: { withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { color = c } }) {
                                Circle()
                                    .fill(c.color)
                                    .frame(width: 60, height: 60)
                                    .overlay(Circle().stroke(color == c ? Color.primary : Color.clear, lineWidth: 3))
                                    .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("new_tab_group".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized, action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("create".localized, action: onCreate)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}