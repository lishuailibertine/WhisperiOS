//
//  URL+Extension.swift
//  PocketWhisper
//
//  Created by li shuai on 2025/12/18.
//
import Foundation
import UniformTypeIdentifiers

// MARK: - 扩展：URL文件类型判断 + AVAsset生成缩略图
extension URL {
    /// 判断是否为视频文件
    var fileUTType: UTType? {
        UTType(filenameExtension: pathExtension)
    }
    
    /// 终极视频判断（修复可选类型问题）
    var isVideoFile: Bool {
        // 1. 优先判断UTType（处理可选类型）
        if let utType = fileUTType {
            // 直接判断UTType标识符，避开conforms(to:)的坑
            let videoUTTypeIdentifiers: [String] = [
                "public.video",          // 抽象视频类型
                "public.mpeg-4",         // 你的MP4专属UTType
                "public.mpeg4-movie",    // MP4别名
                "com.apple.quicktime-movie", // MOV类型
                "public.avi",            // AVI类型
                "public.mpeg"            // MPEG类型
            ]
            if videoUTTypeIdentifiers.contains(utType.identifier) {
                return true
            }
            
            // 兼容判断：是否属于视频子类型
            if utType.conforms(to: .video) {
                return true
            }
        }
        
        // 2. 兜底：扩展名判断（100%覆盖）
        let videoExtensions = ["mp4", "mov", "m4v", "avi", "mkv", "flv", "wmv", "mpeg", "mpg"]
        return videoExtensions.contains(pathExtension.lowercased())
    }
}
