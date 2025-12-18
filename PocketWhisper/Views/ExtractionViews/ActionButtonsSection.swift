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
        HStack(spacing: 20) {
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .any(of: [.videos])
            ) {
                Label("Select from Photos", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .onChange(of: selectedPhotoItem, perform: onSelectPhoto)
            
            if selectedFileURL != nil {
                Button(action: onTranscribe) {
                    Label(isProcessing ? "Processing..." : "Transcribe", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isProcessing ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(isProcessing)
            }
        }
        .padding(.horizontal)
    }
}
