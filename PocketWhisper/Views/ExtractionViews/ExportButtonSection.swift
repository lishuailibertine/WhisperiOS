//
//  ExportButtonSection.swift
//  PocketWhisper
//
//  Created by li shuai on 2025/12/18.
//
import SwiftUI

struct ExportButtonSection: View {
    let isProcessing: Bool
    let transcriptionResult: String
    let onExport: () -> Void
    
    var body: some View {
        if !transcriptionResult.isEmpty && !isProcessing && transcriptionResult != "No transcription yet." {
            Button(action: onExport) {
                Label("Save as .SRT", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
    }
}
