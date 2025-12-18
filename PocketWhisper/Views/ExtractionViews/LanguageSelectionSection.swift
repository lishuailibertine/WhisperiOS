//
//  LanguageSelectionSection.swift
//  PocketWhisper
//
//  Created by li shuai on 2025/12/18.
//
import SwiftUI

struct LanguageSelectionSection: View {
    @Binding var selectedLanguage: String
    
    var body: some View {
        Picker("Language", selection: $selectedLanguage) {
            Text("Auto").tag("auto")
            Text("Chinese (Simplified)").tag("zh")
            Text("English").tag("en")
            Text("Japanese").tag("ja")
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
}
