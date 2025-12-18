//
//  ModelSelectionSection.swift
//  PocketWhisper
//
//  Created by li shuai on 2025/12/18.
//
import SwiftUI

struct ModelPickerSection: View {
    @Binding var availableModels: [String]
    @Binding var selectedModel: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker("", selection: $selectedModel) {
                ForEach(availableModels, id: \.self) { model in
                    Text(model.capitalized).tag(model)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}
