//
//  FileSelectionSection.swift
//  PocketWhisper
//
//  Created by li shuai on 2025/12/18.
//

import SwiftUI
import AVFoundation
// MARK: - 文件选择区（带视频预览）
struct FileSelectionSection: View {
    @Binding var selectedFileURL: URL?
    // 存储视频缩略图
    @State private var videoThumbnail: UIImage?
    
    var body: some View {
        if let url = selectedFileURL {
            VStack {
                // 核心：根据文件类型显示预览图/图标
                if url.isVideoFile {
                    // 视频文件：显示缩略图
                    if let thumbnail = videoThumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120) // 增大预览图尺寸，更直观
                            .cornerRadius(12)
                            .shadow(radius: 2)
                    } else {
                        // 加载中占位
                        ProgressView()
                            .frame(height: 120)
                    }
                } else {
                    // 音频/其他文件：保留原图标
                    Image(systemName: "doc.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 60)
                        .foregroundColor(.blue)
                }
                
                // 文件名（保持原有逻辑）
                Text(url.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                    .padding(.top, 8)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .onAppear {
                // 仅视频文件生成缩略图
                if url.isVideoFile {
                    generateVideoThumbnail(for: url)
                }
            }
            .onChange(of: url) { newURL in
                // 切换文件时重置缩略图并重新生成
                videoThumbnail = nil
                if newURL.isVideoFile {
                    generateVideoThumbnail(for: newURL)
                }
            }
        } else {
            // 无文件时的占位（保持原有逻辑）
            ContentUnavailableView(
                "No Media Selected",
                systemImage: "waveform.badge.plus",
                description: Text("Select an audio or video file to begin.")
            )
        }
    }
    
    // MARK: - 生成视频缩略图
    private func generateVideoThumbnail(for url: URL) {
        Task {
            do {
                let thumbnail = try await AVAsset(url: url).generateThumbnail()
                await MainActor.run {
                    self.videoThumbnail = thumbnail
                }
            } catch {
                print("生成视频缩略图失败：\(error.localizedDescription)")
                // 失败时显示默认视频图标
                await MainActor.run {
                    self.videoThumbnail = UIImage(systemName: "film")?.withTintColor(.blue)
                }
            }
        }
    }
}
