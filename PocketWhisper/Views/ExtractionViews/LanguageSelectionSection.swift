//
//  LanguageSelectionSection.swift
//  PocketWhisper
//
//  Created by li shuai on 2025/12/18.
//
import SwiftUI

struct LanguagePickerSection: View {
    @Binding var selectedLanguage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Language")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker("", selection: $selectedLanguage) {
                Text("Auto").tag("auto")
                Text("Chinese (Simplified)").tag("zh")
                Text("English").tag("en")
                Text("Japanese").tag("ja")
            }
            .pickerStyle(SegmentedPickerStyle())
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}
