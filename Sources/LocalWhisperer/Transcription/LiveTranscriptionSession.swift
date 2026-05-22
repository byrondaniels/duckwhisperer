import Foundation
import whisper

final class LiveTranscriptionSession {
    private struct StateSnapshot {
        let chunks: [String]
        let committedEndSample: Int
        let failure: Error?
    }

    private let audioCapture: AudioCapture
    private let transcriber: WhisperTranscriber
    private let queue = DispatchQueue(label: "com.byrondaniels.duckwhisperer.live-transcription", qos: .userInitiated)
    private var generation = UUID()
    private var isRunning = false
    private var nextChunkStartSample = 0
    private var committedEndSample = 0
    private var chunks: [String] = []
    private var failure: Error?

    private let sampleRate = Int(WHISPER_SAMPLE_RATE)
    private var chunkSampleCount: Int { Int(Double(sampleRate) * 12.0) }
    private var minimumChunkSampleCount: Int { Int(Double(sampleRate) * 8.0) }
    private var boundarySearchSampleCount: Int { Int(Double(sampleRate) * 0.7) }
    private var boundaryWindowSampleCount: Int { Int(Double(sampleRate) * 0.16) }
    private var minimumLiveSampleCount: Int { Int(Double(sampleRate) * 12.0) }
    private var minimumTailSampleCount: Int { Int(Double(sampleRate) * 0.35) }

    init(audioCapture: AudioCapture, transcriber: WhisperTranscriber) {
        self.audioCapture = audioCapture
        self.transcriber = transcriber
    }

    func start() {
        let newGeneration = UUID()
        queue.async { [weak self] in
            guard let self else { return }
            generation = newGeneration
            isRunning = true
            nextChunkStartSample = 0
            committedEndSample = 0
            chunks.removeAll(keepingCapacity: true)
            failure = nil
            schedulePoll(for: newGeneration)
        }
    }

    func finish(with finalSamples: [Float]) throws -> String {
        let snapshot = queue.sync { () -> StateSnapshot in
            isRunning = false
            return StateSnapshot(
                chunks: chunks,
                committedEndSample: committedEndSample,
                failure: failure
            )
        }

        guard finalSamples.count >= minimumLiveSampleCount,
              snapshot.failure == nil,
              !snapshot.chunks.isEmpty
        else {
            return try transcriber.transcribe(samples: finalSamples)
        }

        do {
            var parts = snapshot.chunks
            let tailStart = min(snapshot.committedEndSample, finalSamples.count)
            if finalSamples.count - tailStart >= minimumTailSampleCount {
                let tailSamples = Array(finalSamples[tailStart..<finalSamples.count])
                let prompt = recentPrompt(from: parts)
                let tailTranscript = try transcriber.transcribe(
                    samples: tailSamples,
                    initialPrompt: prompt,
                    singleSegment: true
                )
                if !tailTranscript.isEmpty {
                    parts.append(tailTranscript)
                }
            }

            let transcript = normalizedTranscript(parts)
            return transcript.isEmpty ? try transcriber.transcribe(samples: finalSamples) : transcript
        } catch {
            return try transcriber.transcribe(samples: finalSamples)
        }
    }

    private func schedulePoll(for scheduledGeneration: UUID) {
        queue.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            self?.processNextChunk(for: scheduledGeneration)
        }
    }

    private func processNextChunk(for scheduledGeneration: UUID) {
        guard isRunning,
              generation == scheduledGeneration,
              failure == nil
        else {
            return
        }

        let availableSampleCount = audioCapture.sampleCount()
        let minimumReadySampleCount = nextChunkStartSample + chunkSampleCount + boundarySearchSampleCount
        guard availableSampleCount >= minimumReadySampleCount else {
            schedulePoll(for: scheduledGeneration)
            return
        }

        let currentSamples = audioCapture.snapshotSamples()
        let chunkEndSample = quietChunkEnd(in: currentSamples, startSample: nextChunkStartSample)
        guard chunkEndSample > nextChunkStartSample else {
            schedulePoll(for: scheduledGeneration)
            return
        }

        let chunkSamples = Array(currentSamples[nextChunkStartSample..<chunkEndSample])
        let prompt = recentPrompt(from: chunks)

        do {
            let transcript = try transcriber.transcribe(
                samples: chunkSamples,
                initialPrompt: prompt,
                singleSegment: true
            )
            if !transcript.isEmpty {
                chunks.append(transcript)
            }
            committedEndSample = chunkEndSample
            nextChunkStartSample = chunkEndSample
        } catch {
            failure = error
            return
        }

        schedulePoll(for: scheduledGeneration)
    }

    private func quietChunkEnd(in samples: [Float], startSample: Int) -> Int {
        let targetEnd = min(samples.count, startSample + chunkSampleCount)
        let minimumEnd = min(samples.count, startSample + minimumChunkSampleCount)
        let searchStart = max(minimumEnd, targetEnd - boundarySearchSampleCount)
        let searchEnd = min(samples.count - boundaryWindowSampleCount, targetEnd + boundarySearchSampleCount)

        guard searchEnd > searchStart, boundaryWindowSampleCount > 0 else {
            return targetEnd
        }

        var bestEnd = targetEnd
        var bestScore = Float.greatestFiniteMagnitude
        let stride = max(1, boundaryWindowSampleCount / 4)
        var index = searchStart

        while index <= searchEnd {
            let score = averageAbsoluteAmplitude(in: samples, start: index, count: boundaryWindowSampleCount)
            if score < bestScore {
                bestScore = score
                bestEnd = index + boundaryWindowSampleCount / 2
            }
            index += stride
        }

        return max(minimumEnd, min(samples.count, bestEnd))
    }

    private func averageAbsoluteAmplitude(in samples: [Float], start: Int, count: Int) -> Float {
        guard count > 0, start >= 0, start + count <= samples.count else {
            return Float.greatestFiniteMagnitude
        }

        var total: Float = 0
        for index in start..<(start + count) {
            total += abs(samples[index])
        }
        return total / Float(count)
    }

    private func recentPrompt(from parts: [String]) -> String? {
        let text = normalizedTranscript(parts)
        guard !text.isEmpty else {
            return nil
        }

        if text.count <= 700 {
            return text
        }

        return String(text.suffix(700))
    }

    private func normalizedTranscript(_ parts: [String]) -> String {
        parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
