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
                #if os(macOS)
                // macOS: custom scroll layout that scales naturally
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Name").font(.headline)
                        TextField("Enter group name", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 360)
                        
                        Text("Color").font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 64), spacing: 12)], spacing: 12) {
                            ForEach(TabGroupColor.allCases) { c in
                                Button(action: { withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { color = c } }) {
                                    Circle()
                                        .fill(c.color)
                                        .frame(width: 56, height: 56)
                                        .overlay(Circle().stroke(color == c ? Color.primary : Color.clear, lineWidth: 3))
                                }
                                .buttonStyle(.plain)
                            }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                #else
                // iOS: fully scrollable page with adaptive grid.
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Name").font(.headline)
                        TextField("Group name", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.words)
                        
                        Text("Color").font(.headline)
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
                #endif
            }
            .navigationTitle("New Tab Group")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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