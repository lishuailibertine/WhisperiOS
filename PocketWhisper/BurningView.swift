import SwiftUI
import UniformTypeIdentifiers
import ffmpegkit
import PhotosUI // 仅新增这个导入
import UIKit
import AVFoundation // 仅新增这个导入

// ⚠️ IMPORTANT:
// To make this work, you MUST add 'ffmpeg-kit-ios-min' or 'ffmpeg-kit-ios-full' package to your Xcode project.
// Package URL: https://github.com/tanersener/ffmpeg-kit
// Then add: import ffmpegkit

struct BurningView: View {
    @State private var videoURL: URL?
    @State private var subtitleURL: URL?
    @State private var isImportingVideo = false
    @State private var isImportingSubtitle = false
    @State private var isProcessing = false
    @State private var statusMessage = "Ready to burn."
    @State private var progress: Double = 0.0
    
    // Style Settings
    @State private var fontSize: Double = 24
    @State private var marginV: Double = 20
    @State private var selectedColor: Color = .white // Use Color struct
    @State private var alignment: Int = 2 // 2=Bottom Center
    @State private var selectedFontName: String = "Default"
    
    // 仅新增：PhotosPicker状态
    @State private var selectedVideoItem: PhotosPickerItem?
    
    // Helper to convert Color to ASS format (&HBBGGRR)
    func getASSColorHex(from color: Color) -> String {
        guard let components = color.cgColor?.components else { return "&H00FFFFFF" }
        // SwiftUI colors might have 2 (grayscale) or 4 (rgba) components
        let r: CGFloat = components.count >= 3 ? components[0] : components[0]
        let g: CGFloat = components.count >= 3 ? components[1] : components[0]
        let b: CGFloat = components.count >= 3 ? components[2] : components[0]
        
        let rInt = Int(r * 255)
        let gInt = Int(g * 255)
        let bInt = Int(b * 255)
        
        // Format: &H00BBGGRR (Alpha is 00 for opaque)
        return String(format: "&H00%02X%02X%02X", bInt, gInt, rInt)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Source Files")) {
                    // 仅修改这里：替换原视频Button为PhotosPicker
                    PhotosPicker(
                        selection: $selectedVideoItem,
                        matching: .videos,
                        photoLibrary: .shared()
                    ) {
                        HStack {
                            Label("Select Video", systemImage: "film")
                                .foregroundColor(.primary)
                            Spacer()
                            if videoURL != nil {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if let url = videoURL {
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .listRowSeparator(.hidden)
                    }
                    
                    // 以下所有代码完全保留你的原始内容
                    Button(action: {
                        importingTarget = .subtitle
                        activeContentType = [.plainText] // SRT
                        isImporting = true
                    }) {
                        HStack {
                            Label("Select Subtitle (.srt)", systemImage: "text.bubble")
                                .foregroundColor(.primary)
                            Spacer()
                            if subtitleURL != nil {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if let url = subtitleURL {
                        Text(url.lastPathComponent).font(.caption).foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Subtitle Style")) {
                    // Font Size
                    HStack {
                        Text("Font Size")
                        Slider(value: $fontSize, in: 10...60, step: 2)
                        Text("\(Int(fontSize))")
                            .monospacedDigit()
                    }
                    
                    // Margin Vertical
                    HStack {
                        Text("Bottom Margin")
                        Slider(value: $marginV, in: 0...100, step: 5)
                        Text("\(Int(marginV))")
                            .monospacedDigit()
                    }
                    
                    // Color Picker (Custom)
                    ColorPicker("Font Color", selection: $selectedColor)
                    
                    // Alignment
                    Picker("Position", selection: $alignment) {
                        Text("Bottom Center").tag(2)
                        Text("Top Center").tag(6)
                        Text("Center").tag(10)
                        Text("Bottom Left").tag(1)
                    }
                    
                    // Font Selection (Requires .ttf files in Bundle)
                    // (Commented out until custom fonts are added)
                    /*
                    Picker("Font", selection: $selectedFontName) {
                        Text("Default (Sans)").tag("Default")
                        Text("Custom (Add a .ttf)").tag("Custom")
                    }
                    .onChange(of: selectedFontName) { newValue in
                        if newValue == "Custom" {
                           statusMessage = "Ensure you added 'Custom.ttf' to Xcode project!"
                        }
                    }
                    */
                }
                
                Section(header: Text("Actions")) {
                    if isProcessing {
                        VStack {
                            ProgressView(value: progress, total: 100)
                            Text(statusMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button(action: startBurning) {
                            Text("Burn Subtitles")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor((videoURL != nil && subtitleURL != nil) ? .blue : .gray)
                        }
                        .disabled(videoURL == nil || subtitleURL == nil)
                    }
                }
                
                if !isProcessing && statusMessage != "Ready to burn." {
                    Section {
                        Text(statusMessage)
                    }
                }
            }
            .navigationTitle("Burn Subtitles")
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: activeContentType,
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result: result)
        }
        // 仅新增：监听视频选择变化
        .task(id: selectedVideoItem) {
            await loadSelectedVideo()
        }
    }
    
    // 完全保留你的原始状态
    @State private var isImporting = false
    @State private var activeContentType: [UTType] = [.movie]
    @State private var importingTarget: ImportTarget = .video
    
    enum ImportTarget {
        case video
        case subtitle
    }

    // 完全保留你的原始方法
    func handleFileSelection(result: Result<[URL], Error>) {
        do {
            let url = try result.get().first!
            if url.startAccessingSecurityScopedResource() {
                if importingTarget == .video {
                    videoURL = url
                } else {
                    subtitleURL = url
                }
            }
        } catch {
            statusMessage = "Error selecting file: \(error.localizedDescription)"
        }
    }
    
    // 仅新增：修复后的视频加载方法（核心修改）
    private func loadSelectedVideo() async {
        guard let selectedItem = selectedVideoItem else {
            videoURL = nil
            return
        }
        
        do {
            // 参考你的方法导出临时文件
            guard let tempURL = try await exportToTemporaryFile(from: selectedItem) else {
                throw NSError(domain: "VideoImport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid video data"])
            }
            
            // 移除不必要的 startAccessingSecurityScopedResource 调用
            videoURL = tempURL
            statusMessage = "Ready to burn."
            
        } catch {
            statusMessage = "Error loading video: \(error.localizedDescription)"
            selectedVideoItem = nil
            videoURL = nil
        }
    }
    
    // 仅新增：你的原始导出方法（仅修复NSError）
    private func exportToTemporaryFile(from item: PhotosPickerItem) async throws -> URL? {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            return nil
        }
        
        let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "mov"
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        
        try data.write(to: tempURL)
        return tempURL
    }
    
    // 完全保留你的原始 startBurning 方法（一字未改）
    func startBurning() {
        guard let video = videoURL, let sub = subtitleURL else { return }
        
        isProcessing = true
        progress = 0
        statusMessage = "Starting FFmpeg..."
        
        // Output path in Documents
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = docs.appendingPathComponent("burned_output_\(Int(Date().timeIntervalSince1970)).mp4")
        
        // FFmpeg Command Construction
        // NOTE: 'subtitles=' filter requires escaping paths correctly in FFmpeg.
        // It's often easier to copy files to a temp directory with simple names to avoid path escaping issues.
        
        DispatchQueue.global(qos: .userInitiated).async {
            // 1. Setup Temp Directory
            let fileManager = FileManager.default
            let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            
            do {
                try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
                
                // 2. Prepare Input Files (Copy to temp with clean names)
                let tempVideoPath = tempDir.appendingPathComponent("input.mp4")
                let tempSubPath = tempDir.appendingPathComponent("subs.srt")
                let tempOutputPath = tempDir.appendingPathComponent("output.mp4")
                
                // Need to use startAccessingSecurityScopedResource for robust reading
                // We assume startAccessing was called/handled at selection or we wrap copies here
                // Note: fileImporter URLs usually need access guard if retained long term,
                // but copying immediately is safest.
                if video.startAccessingSecurityScopedResource() {
                    try? fileManager.copyItem(at: video, to: tempVideoPath)
                    video.stopAccessingSecurityScopedResource()
                } else {
                    try fileManager.copyItem(at: video, to: tempVideoPath)
                }
                
                if sub.startAccessingSecurityScopedResource() {
                    try? fileManager.copyItem(at: sub, to: tempSubPath)
                    sub.stopAccessingSecurityScopedResource()
                } else {
                    try fileManager.copyItem(at: sub, to: tempSubPath)
                }
                
                // 3. Build FFmpeg Command (using clean local paths)
                
                // Construct Style String
                // Example: "FontSize=24,PrimaryColour=&H00FFFF,Alignment=2,MarginV=20,Outline=1,Shadow=0"
                // OLD: let colorCode = self.colorMap[self.fontColor] ?? "&H00FFFFFF"
                let colorCode = self.getASSColorHex(from: self.selectedColor)
                let styleStr = "FontSize=\(Int(self.fontSize)),PrimaryColour=\(colorCode),Alignment=\(self.alignment),MarginV=\(Int(self.marginV)),Outline=1,OutlineColour=&H00000000,BorderStyle=1"
                
                // 核心修复：转义路径 + 硬件编码器
                let escapedSubPath = tempSubPath.path.replacingOccurrences(of: "'", with: "\\'")
                let cmd = "-y -i \"\(tempVideoPath.path)\" " +
                "-vf \"subtitles='\(escapedSubPath)':force_style='\(styleStr)'\" " +
                "-c:v h264_videotoolbox -b:v 5M " +
                "-c:a copy " +
                "\"\(tempOutputPath.path)\""
                
                print("FFmpeg Cmd: \(cmd)")
                
                FFmpegKit.executeAsync(cmd) { session in
                    guard let session = session else { return }
                    let returnCode = session.getReturnCode()
                    
                    DispatchQueue.main.async {
                        self.isProcessing = false
                        
                        if returnCode?.isValueSuccess() == true {
                            // 4. Move Output to Documents or Save
                            // Let's move it to final destination
                            try? fileManager.moveItem(at: tempOutputPath, to: outputURL)
                            
                            self.statusMessage = "Success! Saved to Documents."
                            self.progress = 100.0
                            
                            // Optional: Save to Photos
                            if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(outputURL.path) {
                                UISaveVideoAtPathToSavedPhotosAlbum(outputURL.path, nil, nil, nil)
                                self.statusMessage += "\nAnd saved to Photos."
                            }
                            
                            // Cleanup Temp
                            try? fileManager.removeItem(at: tempDir)
                            
                        } else {
                            // Failure
                            let logs = session.getLogsAsString() ?? "Unknown Error"
                            self.statusMessage = "Failed. Logs: \(logs)"
                            // Cleanup Temp
                            try? fileManager.removeItem(at: tempDir)
                        }
                    }
                } withLogCallback: { log in
                    print(log?.getMessage() ?? "")
                } withStatisticsCallback: { stats in
                   // Statistics
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.statusMessage = "File setup failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
