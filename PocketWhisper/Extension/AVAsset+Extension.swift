//
//  AVAsset.swift
//  PocketWhisper
//
//  Created by li shuai on 2025/12/18.
//
import UIKit
import AVFoundation

extension AVAsset {
    /// 生成高清视频缩略图（解决模糊问题）
    func generateHighResThumbnail() async throws -> UIImage {
        let imageGenerator = AVAssetImageGenerator(asset: self)
        imageGenerator.appliesPreferredTrackTransform = true // 保持视频方向正确
        // 提升缩略图分辨率（宽度设为屏幕宽度，高度按比例）
        let screenWidth = UIScreen.main.bounds.width - 40 // 减去左右padding
        imageGenerator.maximumSize = CGSize(width: screenWidth, height: CGFloat.greatestFiniteMagnitude)
        
        return try await withCheckedThrowingContinuation { continuation in
            // 取视频10%位置的帧，避免黑屏/片头
            let time = CMTime(seconds: max(1, duration.seconds * 0.1), preferredTimescale: 60)
            imageGenerator.generateCGImageAsynchronously(for: time) { cgImage, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let cgImage = cgImage else {
                    continuation.resume(throwing: NSError(domain: "ThumbnailError", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法生成视频缩略图"]))
                    return
                }
                
                // 转换为高清UIImage
                let highResImage = UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
                continuation.resume(returning: highResImage)
            }
        }
    }
}
