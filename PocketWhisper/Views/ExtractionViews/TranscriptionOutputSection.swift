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
       VStack(alignment: .leading) {
           Text("Transcription Output")
               .font(.caption)
               .foregroundColor(.secondary)
           
           Text(result)
               .padding()
               .frame(maxWidth: .infinity, alignment: .leading)
               .textSelection(.enabled)
               .background(Color(.systemBackground))
               .cornerRadius(8)
               .overlay(
                   RoundedRectangle(cornerRadius: 8)
                       .stroke(Color(.separator), lineWidth: 1)
               )
       }
       .padding()
   }
}

