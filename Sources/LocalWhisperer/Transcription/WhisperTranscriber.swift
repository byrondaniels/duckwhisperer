import Foundation
import whisper

final class WhisperTranscriber {
    private var modelURL: URL
    private var languageCode = "en"
    private var context: OpaquePointer?
    private let lock = NSLock()

    init(modelURL: URL) {
        self.modelURL = modelURL
    }

    deinit {
        if let context {
            whisper_free(context)
        }
    }

    func setModelURL(_ newModelURL: URL) {
        lock.lock()
        defer { lock.unlock() }

        guard modelURL != newModelURL else {
            return
        }

        if let context {
            whisper_free(context)
            self.context = nil
        }
        modelURL = newModelURL
    }

    func setLanguageCode(_ newLanguageCode: String) {
        lock.lock()
        defer { lock.unlock() }

        languageCode = newLanguageCode
    }

    func transcribe(samples: [Float], initialPrompt: String? = nil, singleSegment: Bool = false) throws -> String {
        lock.lock()
        defer { lock.unlock() }

        let context = try loadedContext()
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.n_threads = Int32(max(4, min(ProcessInfo.processInfo.processorCount - 2, 10)))
        params.translate = false
        params.no_context = true
        params.no_timestamps = true
        params.single_segment = singleSegment
        params.print_special = false
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false
        params.suppress_blank = true
        params.suppress_nst = false
        params.temperature = 0
        params.temperature_inc = 0.2
        params.entropy_thold = 2.4
        params.logprob_thold = -1.0
        params.no_speech_thold = 0.6
        params.greedy.best_of = 1

        let runTranscription: (UnsafePointer<CChar>?) -> Int32 = { promptPointer in
            params.initial_prompt = promptPointer

            let language = self.languageCode
            return language.withCString { languagePointer in
                params.language = languagePointer
                params.detect_language = false
                return samples.withUnsafeBufferPointer { sampleBuffer in
                    guard let baseAddress = sampleBuffer.baseAddress else {
                        return 1
                    }
                    return whisper_full(context, params, baseAddress, Int32(samples.count))
                }
            }
        }

        let result: Int32
        if let initialPrompt, !initialPrompt.isEmpty {
            result = initialPrompt.withCString { promptPointer in
                runTranscription(promptPointer)
            }
        } else {
            result = runTranscription(nil)
        }

        guard result == 0 else {
            throw LocalWhispererError.transcriptionFailed("whisper_full returned \(result).")
        }

        var transcript = ""
        let segmentCount = whisper_full_n_segments(context)
        for index in 0..<segmentCount {
            if let segment = whisper_full_get_segment_text(context, index) {
                transcript += String(cString: segment)
            }
        }

        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func preload() throws {
        lock.lock()
        defer { lock.unlock() }
        _ = try loadedContext()
    }

    private func loadedContext() throws -> OpaquePointer {
        if let context {
            return context
        }

        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw LocalWhispererError.modelMissing(modelURL.path)
        }

        setenv("GGML_METAL_NO_RESIDENCY", "1", 0)

        func loadContext(useGPU: Bool) -> OpaquePointer? {
            var contextParams = whisper_context_default_params()
            contextParams.use_gpu = useGPU
            contextParams.flash_attn = false

            return modelURL.path.withCString { path in
                whisper_init_from_file_with_params(path, contextParams)
            }
        }

        let enableMetal = ProcessInfo.processInfo.environment["LOCAL_WHISPERER_ENABLE_METAL"] == "1"
        let loaded = enableMetal
            ? (loadContext(useGPU: true) ?? loadContext(useGPU: false))
            : loadContext(useGPU: false)
        guard let loaded else {
            throw LocalWhispererError.modelLoadFailed(modelURL.path)
        }

        context = loaded
        return loaded
    }
}
