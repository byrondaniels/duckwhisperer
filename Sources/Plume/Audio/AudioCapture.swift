import AVFoundation
import Foundation
import whisper

final class AudioCapture {
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: Double(WHISPER_SAMPLE_RATE),
        channels: 1,
        interleaved: false
    )!
    private let lock = NSLock()
    private let conversionLock = NSLock()
    private var engine: AVAudioEngine?
    private var converter: AVAudioConverter?
    private var samples: [Float] = []
    private var recentLevel: Float = 0
    private var isRecording = false

    func start() throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.channelCount > 0, inputFormat.sampleRate > 0 else {
            throw PlumeError.audioReadFailed("No microphone input format was available.")
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw PlumeError.audioReadFailed("Could not create the microphone sample-rate converter.")
        }

        lock.lock()
        samples.removeAll(keepingCapacity: true)
        recentLevel = 0
        isRecording = true
        lock.unlock()

        self.engine = engine
        self.converter = converter

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.appendConvertedSamples(from: buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            lock.lock()
            isRecording = false
            lock.unlock()
            self.engine = nil
            self.converter = nil
            throw error
        }
    }

    func stop() throws -> [Float] {
        lock.lock()
        let wasRecording = isRecording
        lock.unlock()

        guard wasRecording, let engine else {
            throw PlumeError.noRecording
        }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        flushConvertedSamples()

        lock.lock()
        isRecording = false
        lock.unlock()

        self.engine = nil
        self.converter = nil

        return snapshotSamples()
    }

    func snapshotSamples() -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        return samples
    }

    func sampleCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return samples.count
    }

    func currentLevel() -> Float {
        lock.lock()
        defer { lock.unlock() }
        return isRecording ? recentLevel : 0
    }

    private func appendConvertedSamples(from buffer: AVAudioPCMBuffer) {
        guard let converter else {
            return
        }

        let inputRate = buffer.format.sampleRate
        let outputRate = targetFormat.sampleRate
        let outputCapacity = AVAudioFrameCount(
            max(1, ceil(Double(buffer.frameLength) * outputRate / inputRate) + 32)
        )

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputCapacity
        ) else {
            return
        }

        conversionLock.lock()
        var didProvideInput = false
        var conversionError: NSError?
        let status = converter.convert(to: convertedBuffer, error: &conversionError) { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .noDataNow
                return nil
            }

            didProvideInput = true
            outStatus.pointee = .haveData
            return buffer
        }
        conversionLock.unlock()

        guard status != .error else {
            return
        }

        appendSamples(from: convertedBuffer)
    }

    private func flushConvertedSamples() {
        guard let converter,
              let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: AVAudioFrameCount(Int(WHISPER_SAMPLE_RATE) / 2)
              )
        else {
            return
        }

        conversionLock.lock()
        defer { conversionLock.unlock() }

        for _ in 0..<8 {
            var conversionError: NSError?
            let status: AVAudioConverterOutputStatus = converter.convert(to: convertedBuffer, error: &conversionError) { _, outStatus in
                outStatus.pointee = .endOfStream
                return nil
            }

            guard status != .error else {
                return
            }

            appendSamples(from: convertedBuffer)

            if status == .endOfStream || convertedBuffer.frameLength == 0 {
                return
            }
        }
    }

    private func appendSamples(from buffer: AVAudioPCMBuffer) {
        guard buffer.frameLength > 0,
              let channel = buffer.floatChannelData?[0]
        else {
            return
        }

        let newSamples = Array(UnsafeBufferPointer(
            start: channel,
            count: Int(buffer.frameLength)
        ))

        lock.lock()
        if isRecording {
            samples.append(contentsOf: newSamples)
            recentLevel = smoothedLevel(from: newSamples, previousLevel: recentLevel)
        }
        lock.unlock()
    }

    private func smoothedLevel(from samples: [Float], previousLevel: Float) -> Float {
        guard !samples.isEmpty else {
            return previousLevel * 0.85
        }

        var squareTotal: Float = 0
        var peak: Float = 0
        for sample in samples {
            let magnitude = abs(sample)
            squareTotal += sample * sample
            peak = max(peak, magnitude)
        }

        let rms = sqrt(squareTotal / Float(samples.count))
        let weightedLevel = max(rms * 18, peak * 3.2)
        let normalizedLevel = min(1, max(0, weightedLevel))
        let attack: Float = normalizedLevel > previousLevel ? 0.42 : 0.16
        return previousLevel + (normalizedLevel - previousLevel) * attack
    }

    static func samples(from url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let frameCount = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else {
            throw PlumeError.audioReadFailed("Could not allocate audio buffer.")
        }

        try file.read(into: buffer)

        guard buffer.frameLength > 0,
              file.processingFormat.commonFormat == .pcmFormatFloat32,
              file.processingFormat.channelCount == 1,
              abs(file.processingFormat.sampleRate - Double(WHISPER_SAMPLE_RATE)) < 1,
              let channel = buffer.floatChannelData?[0]
        else {
            throw PlumeError.audioReadFailed(
                "Recording was not 16 kHz mono float PCM. Format: \(file.processingFormat)"
            )
        }

        return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }
}
