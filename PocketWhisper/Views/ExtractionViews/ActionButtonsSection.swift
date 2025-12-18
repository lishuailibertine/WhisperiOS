//
//  ActionButtonsSection.swift
//  PocketWhisper
//
//  Created by li shuai on 2025/12/18.
//
import SwiftUI
import PhotosUI
struct ActionButtonsSection: View {
    let selectedFileURL: URL?
    @Binding var isProcessing: Bool
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let onSelectPhoto: (PhotosPickerItem?) -> Void
    let onTranscribe: () -> Void
    
    var body: some View {
        HStack(spacing: 16) { // 调整按钮间距
            // 选择文件按钮
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .any(of: [.videos])
            ) {
                HStack(spacing: 8) {
                    Text("Select from Photos")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(16) // 更大圆角，更现代
                .shadow(color: .blue.opacity(0.2), radius: 4)
            }
            .onChange(of: selectedPhotoItem, perform: onSelectPhoto)
            
            // 转录按钮（仅文件选择后显示）
            if selectedFileURL != nil {
                Button(action: onTranscribe) {
                    HStack(spacing: 8) {
                        Text(isProcessing ? "Processing..." : "Transcribe")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isProcessing ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: (isProcessing ? Color.gray : Color.green).opacity(0.2), radius: 4)
                }
                .disabled(isProcessing)
            }
        }
    }
}
