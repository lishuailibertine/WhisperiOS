//
//  TranscriptionOutputSection.swift
//  PocketWhisper
//
//  Created by li shuai on 2025/12/18.
//
import SwiftUI
struct TranscriptionOutputSection: View {
    @Binding var result: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcription Output")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(result)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 2)
                .lineSpacing(6) // 增大行间距，提升可读性
        }
    }
}
