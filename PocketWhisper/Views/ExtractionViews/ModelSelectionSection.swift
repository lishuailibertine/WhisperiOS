//
//  ModelSelectionSection.swift
//  PocketWhisper
//
//  Created by li shuai on 2025/12/18.
//
import SwiftUI

struct ModelSelectionSection: View {
    @Binding var availableModels: [String]
    @Binding var selectedModel: String
    
    var body: some View {
        if availableModels.isEmpty {
            Text("No models found. Please download one in the Models tab.")
                .font(.caption)
                .foregroundColor(.red)
                .padding(.horizontal)
        } else {
            Picker("Model", selection: $selectedModel) {
                ForEach(availableModels, id: \.self) { model in
                    Text(model.capitalized).tag(model)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
        }
    }
}
