//
//  AVAsset.swift
//  PocketWhisper
//
//  Created by li shuai on 2025/12/18.
//
import UIKit
import AVFoundation

extension AVAsset {
    /// 异步生成视频第一帧缩略图
    func generateThumbnail() async throws -> UIImage {
        let imageGenerator = AVAssetImageGenerator(asset: self)
        imageGenerator.appliesPreferredTrackTransform = true // 保持视频方向正确
        imageGenerator.maximumSize = CGSize(width: 300, height: 200) // 限制缩略图尺寸，避免内存占用过大
        
        return try await withCheckedThrowingContinuation { continuation in
            imageGenerator.generateCGImageAsynchronously(for: CMTime(seconds: 1, preferredTimescale: 60)) { cgImage, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let cgImage = cgImage else {
                    continuation.resume(throwing: NSError(domain: "ThumbnailError", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法生成视频缩略图"]))
                    return
                }
                
                continuation.resume(returning: UIImage(cgImage: cgImage))
            }
        }
    }
}
