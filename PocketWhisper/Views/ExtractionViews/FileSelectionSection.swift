//
//  FileSelectionSection.swift
//  PocketWhisper
//
//  Created by li shuai on 2025/12/18.
//
import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct FileSelectionSection: View {
    // MARK: - 状态管理
    @Binding var selectedFileURL: URL?
    @Binding var isLoadingMedia: Bool // 外部传入的加载状态
    @State private var videoThumbnail: UIImage?
    
    // MARK: - 常量定义（统一样式）
    private let previewMinHeight: CGFloat = 120
    private let previewMaxHeight: CGFloat = 220
    private let cornerRadius: CGFloat = 16
    private let shadowRadius: CGFloat = 4
    private let shadowOpacity: Double = 0.08
    
    var body: some View {
        Group {
            if let url = selectedFileURL {
                filePreviewView(for: url)
            } else {
                if isLoadingMedia {
                    loadingStateView
                } else {
                    emptyStateView
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedFileURL) // 平滑过渡动画
        .animation(.easeInOut(duration: 0.2), value: videoThumbnail)
        .animation(.easeInOut(duration: 0.2), value: isLoadingMedia)
    }
}

// MARK: - 子视图封装
private extension FileSelectionSection {
    /// 文件预览主视图
    @ViewBuilder
    func filePreviewView(for url: URL) -> some View {
        VStack(alignment: .center, spacing: 12) {
            // 预览区域 + 删除按钮
            ZStack(alignment: .topTrailing) {
                // 视频/音频预览区分
                mediaPreviewView(for: url)
                
                // 删除按钮（加载中禁用）
                deleteButton
            }
            
            // 文件名展示
            fileNameView(for: url)
        }
        .onAppear {
            if url.isVideoFile {
                generateHighResThumbnail(for: url)
            }
        }
        .onChange(of: url) { newURL in
            resetThumbnail(for: newURL)
        }
    }
    
    /// 媒体预览（视频/音频区分）
    @ViewBuilder
    func mediaPreviewView(for url: URL) -> some View {
        if url.isVideoFile {
            videoPreviewView
        } else {
            audioPreviewView
        }
    }
    
    /// 视频预览视图（带加载状态）
    var videoPreviewView: some View {
        Group {
            if let thumbnail = videoThumbnail {
                // 已加载的缩略图
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .aspectRatio(16/9, contentMode: .fit)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: previewMinHeight,
                        maxHeight: previewMaxHeight
                    )
                    .cornerRadius(cornerRadius)
                    .clipped()
                    .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius)
                
            } else {
                // 加载中占位
                ProgressView {
                    Text("Loading thumbnail...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .progressViewStyle(.circular)
                .frame(
                    maxWidth: .infinity,
                    minHeight: previewMinHeight,
                    maxHeight: previewMaxHeight
                )
                .background(Color(.secondarySystemBackground))
                .cornerRadius(cornerRadius)
            }
        }
    }
    
    /// 音频预览视图
    var audioPreviewView: some View {
        Image(systemName: "waveform.circle.fill")
            .resizable()
            .scaledToFit()
            .frame(height: 80)
            .foregroundColor(.purple)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(cornerRadius)
    }
    
    /// 加载中状态视图（替换空状态）
    var loadingStateView: some View {
        VStack(spacing: 16) {
            ProgressView {
                Text("Loading media...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .progressViewStyle(.circular)
            Text("Please wait while we process your file")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }
    
    /// 删除按钮
    var deleteButton: some View {
        Button(action: {
            selectedFileURL = nil
            videoThumbnail = nil
            // 同步停止外部加载状态
            Task { @MainActor in
                isLoadingMedia = false
            }
        }) {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(.white)
                .shadow(radius: 2)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
        }
        .padding(8)
        .disabled(isLoadingMedia) // 加载中禁用删除
        .opacity(isLoadingMedia ? 0.7 : 1.0) // 加载中半透明
    }
    
    /// 文件名展示视图
    func fileNameView(for url: URL) -> some View {
        Text(url.lastPathComponent)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .center) // 居中显示
    }
    
    /// 空状态视图
    var emptyStateView: some View {
        ContentUnavailableView(
            "No Media Selected",
            systemImage: "waveform.badge.plus",
            description: Text("Select an audio or video file to begin.")
        )
        .frame(maxWidth: .infinity, minHeight: 180)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(cornerRadius)
    }
}

// MARK: - 业务逻辑
private extension FileSelectionSection {
    /// 重置缩略图并重新生成
    func resetThumbnail(for url: URL) {
        videoThumbnail = nil
        if url.isVideoFile {
            generateHighResThumbnail(for: url)
        }
    }
    
    /// 生成高清视频缩略图
    func generateHighResThumbnail(for url: URL) {
        // 标记加载状态
        Task { @MainActor in
            isLoadingMedia = true
        }
        
        Task {
            do {
                let thumbnail = try await AVAsset(url: url).generateHighResThumbnail()
                await MainActor.run {
                    videoThumbnail = thumbnail
                    isLoadingMedia = false // 加载完成
                }
            } catch {
                print("⚠️ 生成缩略图失败：\(error.localizedDescription)")
                await MainActor.run {
                    // 失败时显示默认视频图标
                    videoThumbnail = UIImage(systemName: "film")?
                        .withTintColor(.blue)
                        .withRenderingMode(.alwaysOriginal)
                    isLoadingMedia = false // 加载失败也停止状态
                }
            }
        }
    }
}
