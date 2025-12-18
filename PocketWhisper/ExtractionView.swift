import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers
// MARK: - 主视图
struct ExtractionView: View {
    // MARK: - 状态管理
    @State private var selectedFileURL: URL?
    @State private var transcriptionResult: String = "No transcription yet."
    @State private var isProcessing: Bool = false
    @State private var selectedModel: String = "tiny"
    @State private var selectedLanguage: String = "auto"
    @State private var availableModels: [String] = []
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    // 导出相关 - 关键修改：拆分导出状态，避免可选类型直接传入fileExporter
    @State private var isExporting: Bool = false
    @State private var exportText: String = "" // 存储要导出的文本，而非可选的Document
    
    // 新增：标记是否正在加载相册文件/生成缩略图
    @State private var isLoadingMedia: Bool = false
    // MARK: - 主Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. 文件选择区
                    FileSelectionSection(selectedFileURL: $selectedFileURL, isLoadingMedia: $isLoadingMedia)
                    
                    // 2. 模型选择区
                    ModelPickerSection(
                        availableModels: $availableModels,
                        selectedModel: $selectedModel
                    )
                    
                    // 3. 语言选择区
                    LanguagePickerSection(selectedLanguage: $selectedLanguage)
                    
                    // 4. 操作按钮区
                    ActionButtonsSection(
                        selectedFileURL: selectedFileURL,
                        isProcessing: $isProcessing,
                        selectedPhotoItem: $selectedPhotoItem,
                        onSelectPhoto: { item in
                            handlePhotoItemSelection(item)
                        },
                        onTranscribe: startTranscription
                    )
                    
                    // 5. 处理中进度条
                    if isProcessing {
                        ProgressView("Transcribing with Whisper...")
                            .padding()
                    }
                    
                    // 6. 导出按钮
                    ExportButtonSection(
                        isProcessing: isProcessing,
                        transcriptionResult: transcriptionResult,
                        onExport: prepareForExport // 关键修改：先准备导出文本，再触发弹窗
                    )
                    
                    Divider()
                    
                    // 7. 转录结果输出区
                    TranscriptionOutputSection(result: $transcriptionResult)
                }
                .padding()
            }
            .navigationTitle("Extraction")
            .onAppear(perform: refreshModels)
            // 关键修改：fileExporter使用非可选的Document，通过exportText初始化
            .fileExporter(
                isPresented: $isExporting,
                document: SubtitleDocument(text: exportText), // 非可选类型
                contentType: .plainText,
                defaultFilename: "subtitle.srt"
            ) { result in
                handleExportResult(result)
            }
        }
    }
}

// MARK: - 业务逻辑扩展（关键修改导出相关逻辑）
extension ExtractionView {
    // 刷新模型列表
    func refreshModels() {
        let fileManager = FileManager.default
        guard let docDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            availableModels = []
            return
        }
        
        Task { @MainActor in
            do {
                let files = try fileManager.contentsOfDirectory(at: docDir, includingPropertiesForKeys: nil)
                let models = files.filter {
                    $0.lastPathComponent.hasPrefix("ggml-") && $0.lastPathComponent.hasSuffix(".bin")
                }
                .map {
                    $0.lastPathComponent
                        .replacingOccurrences(of: "ggml-", with: "")
                        .replacingOccurrences(of: ".bin", with: "")
                }
                
                // 排序模型
                let order = ["tiny", "base", "small", "medium", "large"]
                availableModels = models.sorted { a, b in
                    let indexA = order.firstIndex(of: a) ?? Int.max
                    let indexB = order.firstIndex(of: b) ?? Int.max
                    return indexA < indexB
                }
                
                // 自动选择第一个可用模型
                if !availableModels.contains(selectedModel), let first = availableModels.first {
                    selectedModel = first
                }
            } catch {
                print("Error listing models: \(error)")
                availableModels = []
            }
        }
    }
    
    // 处理相册选择（新增加载状态）
    func handlePhotoItemSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        // 立即标记为加载中，显示指示器
        Task { @MainActor in
            isLoadingMedia = true
            selectedFileURL = nil // 清空旧文件，避免显示旧缩略图
        }
        // 异步处理文件导出，不阻塞主线程
        Task {
            do {
                if let tempURL = try await exportToTemporaryFile(from: item) {
                    await MainActor.run {
                        selectedFileURL = tempURL
                        // 缩略图生成由FileSelectionSection的onAppear触发，此处仅标记加载中
                    }
                }
            } catch {
                print("Failed to load media: \(error)")
                await MainActor.run {
                    isLoadingMedia = false // 加载失败，停止指示器
                }
            }
        }
    }
    
    // 导出到临时文件
    func exportToTemporaryFile(from item: PhotosPickerItem) async throws -> URL? {
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
    
    // 开始转录
    func startTranscription() {
        guard let url = selectedFileURL else { return }
        isProcessing = true
        transcriptionResult = "Initializing..."
        
        Task {
            do {
                let lang = selectedLanguage == "auto" ? nil : selectedLanguage
                // 替换为你的WhisperManager实际调用逻辑
                let text = try await WhisperManager.shared.transcribe(
                    audioURL: url,
                    modelName: selectedModel,
                    language: lang
                )
                
                await MainActor.run {
                    transcriptionResult = text
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    transcriptionResult = "Error: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
    
    // 关键修改：准备导出文本，触发导出弹窗
    func prepareForExport() {
        exportText = transcriptionResult // 先赋值要导出的文本
        isExporting = true // 再触发导出弹窗
    }
    
    // 处理导出结果
    func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("Saved to \(url)")
        case .failure(let error):
            print("Save failed: \(error.localizedDescription)")
        }
    }
}
