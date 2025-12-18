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
    @State private var videoThumbnail: UIImage?
    
    var body: some View {
        if let url = selectedFileURL {
            VStack(alignment: .center, spacing: 12) {
                // 视频预览+删除按钮
                ZStack(alignment: .topTrailing) {
                    if url.isVideoFile {
                        // 视频预览图（自适应高清版）
                        Group {
                            if let thumbnail = videoThumbnail {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .scaledToFit() // 改为Fit，避免拉伸模糊
                                    .aspectRatio(16/9, contentMode: .fit) // 固定16:9比例，符合视频视觉
                                    .frame(
                                        maxWidth: .infinity, // 宽度自适应父容器
                                        minHeight: 120,      // 最小高度保证显示
                                        maxHeight: 220       // 最大高度限制，避免占满屏幕
                                    )
                                    .cornerRadius(16)
                                    .clipped()
                                    .shadow(color: .black.opacity(0.08), radius: 4) // 轻微阴影提升质感
                            } else {
                                ProgressView()
                                    .frame(
                                        maxWidth: .infinity,
                                        minHeight: 120,
                                        maxHeight: 220
                                    )
                            }
                        }
                    } else {
                        // 音频图标（保持原有样式）
                        Image(systemName: "waveform.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 80)
                            .foregroundColor(.purple)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(16)
                    }
                    
                    // 替换/删除按钮
                    Button(action: { selectedFileURL = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle()) // 按钮加半透明背景，更易点击
                    }
                    .padding(8)
                }
                
                // 文件名（折叠长名称）
                Text(url.lastPathComponent)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .onAppear { if url.isVideoFile { generateHighResThumbnail(for: url) } }
            .onChange(of: url) { newURL in
                videoThumbnail = nil
                if newURL.isVideoFile { generateHighResThumbnail(for: newURL) }
            }
        } else {
            // 无文件时的占位（优化样式）
            ContentUnavailableView(
                "No Media Selected",
                systemImage: "waveform.badge.plus",
                description: Text("Select an audio or video file to begin.")
            )
            .frame(maxWidth: .infinity, minHeight: 180)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
        }
    }
    
    // 生成高清缩略图（提升分辨率，避免模糊）
    private func generateHighResThumbnail(for url: URL) {
        Task {
            do {
                let thumbnail = try await AVAsset(url: url).generateHighResThumbnail()
                await MainActor.run { self.videoThumbnail = thumbnail }
            } catch {
                await MainActor.run {
                    self.videoThumbnail = UIImage(systemName: "film")?
                        .withTintColor(.blue)
                        .withRenderingMode(.alwaysOriginal)
                }
            }
        }
    }
}
