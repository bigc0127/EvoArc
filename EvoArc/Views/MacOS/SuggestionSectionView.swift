//
//  SuggestionSectionView.swift
//  EvoArc
//
//  Created on 2025-09-28.
//

import SwiftUI

#if os(macOS)

struct SuggestionSectionView: View {
    let title: String
    let suggestions: [SuggestionRowData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<suggestions.count, id: \.self) { index in
                    let suggestion = suggestions[index]
                    Button(action: suggestion.action) {
                        HStack(spacing: 12) {
                            Image(systemName: suggestion.icon)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .frame(width: 18, height: 18)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(suggestion.text)
                                    .font(.system(size: 13))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                if let subtitle = suggestion.subtitle {
                                    Text(subtitle)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.clear)
                    .contentShape(Rectangle())
                    
                    if index < suggestions.count - 1 {
                        Divider()
                            .padding(.leading, 46)
                    }
                }
            }
        }
    }
}

#endif