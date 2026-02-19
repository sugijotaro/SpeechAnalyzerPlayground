//
//  SpeechRecognizerManager.swift
//  SpeechAnalyzerPlayground
//
//  Created by Jotaro Sugiyama on 2026/02/19.
//


import AVFoundation
import Foundation
import Speech

@Observable
final class SpeechRecognizerManager {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.ja)
    private let audioSession = AVAudioSession.sharedInstance()
    private let audioEngine = AVAudioEngine()

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioBufferContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation?
    private var recognitionTaskWrapper: Task<(), Error>?
    private var hasInputTap = false

    var recognizedText = ""
    var isRecording = false

    func startRecognition() {
        Task {
            do {
                guard recognitionTask == nil else {
                    print("recognition is still in progress")
                    return
                }

                guard await requestSpeechRecognizerPermission() else {
                    print("Speech recognition permission denied")
                    return
                }

                try await setupAudioSession()

                recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

                guard let request = recognitionRequest else { return }
                request.shouldReportPartialResults = true

                await MainActor.run {
                    isRecording = true
                    recognizedText = ""
                }

                recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
                    guard let self else { return }

                    if let result = result, !result.bestTranscription.formattedString.isEmpty {
                        Task { @MainActor in
                            self.recognizedText = result.bestTranscription.formattedString
                        }

                        if result.isFinal {
                            Task {
                                await self.completeRecognitionSession()
                            }
                        }
                    }

                    if let error = error {
                        if !self.isCancellationError(error) {
                            print("recognition error: \(error.localizedDescription)")
                        }

                        Task {
                            await self.completeRecognitionSession()
                        }
                        return
                    }
                }

                recognitionTaskWrapper = Task { [weak self] in
                    guard let self else { return }

                    do {
                        for try await buffer in try await self.audioBufferStream() {
                            self.recognitionRequest?.append(buffer)
                        }
                    } catch is CancellationError {
                        // stopping recording cancels this task intentionally.
                    } catch {
                        print("audio stream failure: \(error)")
                        await self.cleanupAfterStartFailure()
                    }
                }
            } catch {
                print("recognition start failure: \(error)")
                await cleanupAfterStartFailure()
            }
        }
    }
    
    func stopRecognition() {
        Task {
            recognitionRequest?.endAudio()
            recognitionRequest = nil
            recognitionTaskWrapper?.cancel()
            recognitionTaskWrapper = nil
            
            stopAudioEngine()
            
            do {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("Failed to deactivate audio session: \(error)")
            }
            
            await MainActor.run {
                isRecording = false
            }
        }
    }
}

// MARK: - AudioEngine
private extension SpeechRecognizerManager {
    func setupAudioSession() async throws {
        try audioSession.setCategory(.record, mode: .measurement)
        try audioSession.setActive(true)
    }

    func requestSpeechRecognizerPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                switch status {
                case .authorized:
                    AVAudioApplication.requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                case .denied, .restricted, .notDetermined:
                    continuation.resume(returning: false)
                @unknown default:
                    continuation.resume(returning: false)
                }
            }
        }
    }

    func audioBufferStream() async throws -> AsyncStream<AVAudioPCMBuffer> {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.inputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 2048, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.audioBufferContinuation?.yield(buffer)
        }
        hasInputTap = true

        audioEngine.prepare()
        try audioEngine.start()

        return AsyncStream(AVAudioPCMBuffer.self, bufferingPolicy: .unbounded) { continuation in
            self.audioBufferContinuation = continuation
        }
    }
    
    func stopAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        if hasInputTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInputTap = false
        }

        audioBufferContinuation?.finish()
        audioBufferContinuation = nil
    }

    func completeRecognitionSession() async {
        recognitionTask = nil
        recognitionTaskWrapper?.cancel()
        recognitionTaskWrapper = nil
        recognitionRequest = nil

        stopAudioEngine()

        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)

        await MainActor.run {
            isRecording = false
        }
    }

    func isCancellationError(_ error: Error) -> Bool {
        let nsError = error as NSError
        let message = nsError.localizedDescription.lowercased()
        return (nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled)
            || message.contains("canceled")
            || message.contains("cancelled")
    }

    func cleanupAfterStartFailure() async {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionTaskWrapper?.cancel()
        recognitionTaskWrapper = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        stopAudioEngine()

        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session after start failure: \(error)")
        }

        await MainActor.run {
            isRecording = false
        }
    }
}
