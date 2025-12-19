
import Foundation
import AVFoundation
import whisper // The C-API bridge

class WhisperManager: ObservableObject {
    static let shared = WhisperManager()
    
    // We hold a pointer to the C context
    private var ctx: OpaquePointer?
    private var currentModelPath: String?
    
    // Default params needed for inference
    private var params: whisper_full_params
    
    private init() {
        // Initialize with default standard params for Greedy sampling
        self.params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        self.params.print_realtime = false
        self.params.print_progress = false
        self.params.print_timestamps = true
        self.params.translate = false
        // 动态线程数：留1核给系统，避免卡顿
        let processorCount = ProcessInfo.processInfo.activeProcessorCount
        self.params.n_threads = Int32(max(2, min(processorCount - 1, 8)))
        
        // Auto-detect language
        // In C-API, usually nullptr means auto-detect.
        self.params.language = nil
        
        // Improve sensitivity
        self.params.no_speech_thold = 0.6 // Less aggressive silence filtering
    }
    
    deinit {
        if let ctx = ctx {
            whisper_free(ctx)
        }
    }
    
    /// Checks if model file exists
    func isModelAvailable(model: String) -> Bool {
        return getModelURL(for: model) != nil
    }
    
    func getModelURL(for modelName: String) -> URL? {
        let fileManager = FileManager.default
        guard let docDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let modelFileName = "ggml-\(modelName).bin"
        let modelPath = docDir.appendingPathComponent(modelFileName)
        if fileManager.fileExists(atPath: modelPath.path) {
            return modelPath
        }
        return nil
    }
    
    /// Loads the C-Model from file
    func loadModel(modelName: String) throws {
        guard let modelURL = getModelURL(for: modelName) else {
            throw WhisperError.modelNotFound(modelName)
        }
        
        if currentModelPath == modelURL.path && ctx != nil {
            return
        }
        
        if let oldCtx = ctx {
            whisper_free(oldCtx)
        }
        
        print("Loading model from \(modelURL.path)...")
        
        // 1. Context Params
        var cparams = whisper_context_default_params()
        // cparams.use_gpu = true // If newer version supports CoreML/Metal flags here
        // 2. Init Context
        // Using C-String bridge
        self.ctx = whisper_init_from_file_with_params(modelURL.path, cparams)
        
        if self.ctx == nil {
            throw WhisperError.contextInitializationFailed
        }
        
        // Optimize: Ensure we don't hold unnecessary references if possible
        // But for C-interop we just need the pointer.
        
        self.currentModelPath = modelURL.path
        print("Model loaded.")
    }

    /// Free memory manually
    func releaseContext() {
        if let c = ctx {
            whisper_free(c)
            ctx = nil
            currentModelPath = nil
        }
    }
    
    /// Main inference function
    func transcribe(audioURL: URL, modelName: String, language: String? = nil) async throws -> String {
        // Ensure model is loaded
        try loadModel(modelName: modelName)
        
        guard let context = ctx else {
            throw WhisperError.contextInitializationFailed
        }
        
        // Decode to 16kHz Float Array
        let floats = try await decodeAudio(url: audioURL)
        if floats.isEmpty { return "Error: No audio data derived." }
        
        print("Running inference on \(floats.count) samples...")
        
        // Setup Params with Language
        var runParams = self.params
        // C-String Safety: The pointer must be valid during whisper_full
        // We use a temporary helper to keep the string alive if needed,
        // but since this is async, we need to be careful.
        // Actually, let's just use the NSString bridge which is standard.
        var langPtr: UnsafePointer<CChar>? = nil
        let langStr: String? = language
        
        // If language is set, use it. Otherwise nil (Auto-detect)
        if let l = langStr {
            langPtr = (l as NSString).utf8String
        }
        runParams.language = langPtr
        
        // Run Whisper (Blocking C call)
        // We wrap it in a Task detatchment or similar if we want to avoid freezing main thread,
        // but 'async' function here runs on background already usually.
        let ret = whisper_full(context, runParams, floats, Int32(floats.count))
        
        if ret != 0 {
            throw WhisperError.inferenceFailed(Int(ret))
        }
        
        // Extract segments
        let n_segments = whisper_full_n_segments(context)
        var fullText = ""
        
        for i in 0..<n_segments {
            if let textPtr = whisper_full_get_segment_text(context, i) {
                let segmentText = String(cString: textPtr).trimmingCharacters(in: .whitespacesAndNewlines)
                let t0 = whisper_full_get_segment_t0(context, i)
                let t1 = whisper_full_get_segment_t1(context, i)
                
                // SRT Format:
                // 1
                // 00:00:00,000 --> 00:00:05,000
                // Text line
                
                // Calculate time components (t is in 10ms units)
                let h0 = t0 / 360000
                let m0 = (t0 / 6000) % 60
                let s0 = (t0 / 100) % 60
                let ms0 = (t0 % 100) * 10
                
                let h1 = t1 / 360000
                let m1 = (t1 / 6000) % 60
                let s1 = (t1 / 100) % 60
                let ms1 = (t1 % 100) * 10
                
                let timeStr = String(format: "%02d:%02d:%02d,%03d --> %02d:%02d:%02d,%03d",
                                     h0, m0, s0, ms0,
                                     h1, m1, s1, ms1)
                
                fullText += "\(i + 1)\n\(timeStr)\n\(segmentText)\n\n"
            }
        }
        
        return fullText
    }
    
    // MARK: - Audio Processing
    private func decodeAudio(url: URL) async throws -> [Float] {
        let asset = AVAsset(url: url)
        
        guard let reader = try? AVAssetReader(asset: asset) else {
            throw WhisperError.audioReadingFailed
        }
        
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let track = tracks.first else {
            throw WhisperError.noAudioTrack
        }
        
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 16000
        ]
        
        let trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        reader.add(trackOutput)
        reader.startReading()
        
        var allSamples = [Float]()
        
        while reader.status == .reading {
            if let sampleBuffer = trackOutput.copyNextSampleBuffer(),
               let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                
                let length = CMBlockBufferGetDataLength(blockBuffer)
                var dataPointer: UnsafeMutablePointer<Int8>? = nil
                
                CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: nil, dataPointerOut: &dataPointer)
                
                if let dataPointer = dataPointer {
                    let sampleCount = length / 2
                    let int16Pointer = dataPointer.withMemoryRebound(to: Int16.self, capacity: sampleCount) { $0 }
                    
                    for i in 0..<sampleCount {
                        let floatSample = Float(int16Pointer[i]) / 32768.0
                        allSamples.append(floatSample)
                    }
                }
            }
        }
        
        return allSamples
    }
}

enum WhisperError: Error, LocalizedError {
    case modelNotFound(String)
    case contextInitializationFailed
    case audioReadingFailed
    case noAudioTrack
    case inferenceFailed(Int)
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound(let name): return "Model '\(name)' not found in Documents."
        case .contextInitializationFailed: return "Failed to initialize Whisper Context (C++)."
        case .audioReadingFailed: return "Could not decode audio file."
        case .noAudioTrack: return "No audio track found."
        case .inferenceFailed(let code): return "Whisper inference failed with code \(code)."
        }
    }
}
