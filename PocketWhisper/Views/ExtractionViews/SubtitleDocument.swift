//
//  SubtitleDocument.swift
//  PocketWhisper
//
//  Created by li shuai on 2025/12/18.
//
import SwiftUI
import UniformTypeIdentifiers

// MARK: - 字幕文件文档（补充完整）
struct SubtitleDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    static var writableContentTypes: [UTType] { [.plainText] }
    
    var text: String
    
    init(text: String) {
        self.text = text
    }
    
    init(configuration: ReadConfiguration) throws {
        text = configuration.file.regularFileContents
            .flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = text.data(using: .utf8) else {
            throw NSError(domain: "SubtitleDocument", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode text to UTF-8"])
        }
        return FileWrapper(regularFileWithContents: data)
    }
}
