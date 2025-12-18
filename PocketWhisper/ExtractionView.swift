import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

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
    
    // MARK: - 主Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. 文件选择区
                    FileSelectionSection(selectedFileURL: $selectedFileURL)
                    
                    // 2. 模型选择区
                    ModelSelectionSection(
                        availableModels: $availableModels,
                        selectedModel: $selectedModel
                    )
                    
                    // 3. 语言选择区
                    LanguageSelectionSection(selectedLanguage: $selectedLanguage)
                    
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

// MARK: - 子View拆分（无修改，复用之前的）
private struct FileSelectionSection: View {
    @Binding var selectedFileURL: URL?
    
    var body: some View {
        if let url = selectedFileURL {
            VStack {
                Image(systemName: "doc.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 60)
                    .foregroundColor(.blue)
                Text(url.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        } else {
            ContentUnavailableView(
                "No Media Selected",
                systemImage: "waveform.badge.plus",
                description: Text("Select an audio or video file to begin.")
            )
        }
    }
}

private struct ModelSelectionSection: View {
    @Binding var availableModels: [String]
    @Binding var selectedModel: String
    
    var body: some View {
        if availableModels.isEmpty {
            Text("No models found. Please download one in the Models tab.")
                .font(.caption)
                .foregroundColor(.red)
                .padding(.horizontal)
        } else {
            Picker("Model", selection: $selectedModel) {
                ForEach(availableModels, id: \.self) { model in
                    Text(model.capitalized).tag(model)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
        }
    }
}

private struct LanguageSelectionSection: View {
    @Binding var selectedLanguage: String
    
    var body: some View {
        Picker("Language", selection: $selectedLanguage) {
            Text("Auto").tag("auto")
            Text("Chinese (Simplified)").tag("zh")
            Text("English").tag("en")
            Text("Japanese").tag("ja")
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
}

private struct ActionButtonsSection: View {
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

private struct ExportButtonSection: View {
    let isProcessing: Bool
    let transcriptionResult: String
    let onExport: () -> Void
    
    var body: some View {
        if !transcriptionResult.isEmpty && !isProcessing && transcriptionResult != "No transcription yet." {
            Button(action: onExport) {
                Label("Save as .SRT", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
    }
}

private struct TranscriptionOutputSection: View {
    @Binding var result: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Transcription Output")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(result)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.separator), lineWidth: 1)
                )
        }
        .padding()
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
    
    // 处理相册选择的媒体文件
    func handlePhotoItemSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        Task {
            do {
                if let tempURL = try await exportToTemporaryFile(from: item) {
                    await MainActor.run {
                        selectedFileURL = tempURL
                    }
                }
            } catch {
                print("Failed to load media: \(error)")
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
