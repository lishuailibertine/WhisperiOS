
import SwiftUI
import UniformTypeIdentifiers

struct ExtractionView: View {
    @State private var selectedFileURL: URL?
    @State private var isImporting: Bool = false
    @State private var transcriptionResult: String = "No transcription yet."
    @State private var isProcessing: Bool = false
    @State private var selectedModel: String = "tiny"
    @State private var selectedLanguage: String = "auto"
    @State private var availableModels: [String] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // ... Header and File selection UI ...
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
                        ContentUnavailableView("No Media Selected", systemImage: "waveform.badge.plus", description: Text("Select an audio or video file to begin."))
                    }
                    
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
                    
                    // Language Selection
                    Picker("Language", selection: $selectedLanguage) {
                        Text("Auto").tag("auto")
                        Text("Chinese (Simplified)").tag("zh")
                        Text("English").tag("en")
                        Text("Japanese").tag("ja")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // Actions
                    HStack(spacing: 20) {
                        Button(action: { isImporting = true }) {
                            Label("Select File", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        if selectedFileURL != nil {
                            Button(action: startTranscription) {
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
                    
                    if isProcessing {
                        ProgressView("Transcribing with Whisper...")
                            .padding()
                    }
                    
                    if !transcriptionResult.isEmpty && !isProcessing && transcriptionResult != "No transcription yet." {
                        Button(action: exportSubtitle) {
                            Label("Save as .SRT", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
    
                    Divider()
                    
                    // Output Area
                    VStack(alignment: .leading) {
                        Text("Transcription Output")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // NOTE: Nested ScrollViews can be tricky.
                        // Since the outer view is now a ScrollView, we should let the text expand naturally
                        // instead of constraining it in a small internal ScrollView.
                        Text(transcriptionResult)
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
            .navigationTitle("Extraction")
            .onAppear(perform: refreshModels)
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [UTType.audio, UTType.movie],
                allowsMultipleSelection: false
            ) { result in
                do {
                    // Security-scoped resources must be accessed properly
                    let url = try result.get().first!
                    if url.startAccessingSecurityScopedResource() {
                        selectedFileURL = url
                        // Do not stop accessing immediately if we want to read it later,
                        // but usually better to copy to tmp if we need prolonged access.
                        // For this demo, we keep the handle open or re-open in manager.
                    }
                } catch {
                    print("Error selecting file: \(error.localizedDescription)")
                }
            }
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: .plainText,
                defaultFilename: "subtitle.srt"
            ) { result in
                if case .success(let url) = result {
                    print("Saved to \(url)")
                } else {
                    print("Save cancelled or failed")
                }
            }
        }
    }

    
    func refreshModels() {
        let fileManager = FileManager.default
        guard let docDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        do {
            let files = try fileManager.contentsOfDirectory(at: docDir, includingPropertiesForKeys: nil)
            let models = files.filter { $0.lastPathComponent.hasPrefix("ggml-") && $0.lastPathComponent.hasSuffix(".bin") }
                              .map { $0.lastPathComponent.replacingOccurrences(of: "ggml-", with: "").replacingOccurrences(of: ".bin", with: "") }
            
            // Define standard order for sorting
            let order = ["tiny", "base", "small", "medium", "large"]
            
            self.availableModels = models.sorted { (a, b) -> Bool in
                let indexA = order.firstIndex(of: a) ?? Int.max
                let indexB = order.firstIndex(of: b) ?? Int.max
                return indexA < indexB
            }
            
            // Auto-select first available if current selection is invalid
            if !availableModels.contains(selectedModel) {
                if let first = availableModels.first {
                    selectedModel = first
                }
            }
        } catch {
            print("Error listing models: \(error)")
            self.availableModels = []
        }
    }
    
    func startTranscription() {
        guard let url = selectedFileURL else { return }
        isProcessing = true
        transcriptionResult = "Initializing..."
        
        Task {
            do {
                let lang = selectedLanguage == "auto" ? nil : selectedLanguage
                let text = try await WhisperManager.shared.transcribe(audioURL: url, modelName: selectedModel, language: lang)
                
                DispatchQueue.main.async {
                    self.transcriptionResult = text
                    self.isProcessing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.transcriptionResult = "Error: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }

    @State private var isExporting: Bool = false
    @State private var exportDocument: SubtitleDocument?

    func exportSubtitle() {
        exportDocument = SubtitleDocument(text: transcriptionResult)
        isExporting = true
    }
}

struct SubtitleDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    
    var text: String
    
    init(text: String) {
        self.text = text
    }
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let string = String(data: data, encoding: .utf8) {
            text = string
        } else {
            text = ""
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8)!
        return FileWrapper(regularFileWithContents: data)
    }
}

// Add modifier to the end of NavigationView/VStack
extension ExtractionView {
    // This is a workaround to attach the modifier cleanly in the SwiftUI body structure
    // Since we can't easily append to body in replace, we assume user pastes this logic
    // or we inject the .fileExporter into the main body view hierarchy.
}
