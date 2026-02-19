import AVFoundation
import Speech
import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            AnalyzerAndRecognizerView()
        } else {
            RecognizerOnlyView()
        }
#else
        RecognizerOnlyView()
#endif
    }
}

#if compiler(>=6.2)
@available(iOS 26.0, *)
private enum ManagerType: String {
    case analyzer = "SpeechAnalyzer"
    case recognizer = "SFSpeechRecognizer"

    var displayName: String {
        switch self {
        case .analyzer:
            return "Speech Analyzer"
        case .recognizer:
            return "Speech Recognizer"
        }
    }
}

@available(iOS 26.0, *)
private struct AnalyzerAndRecognizerView: View {
    @State private var analyzerManager = SpeechAnalyzerManager()
    @State private var recognizerManager = SpeechRecognizerManager()
    @State private var selectedManager: ManagerType = .recognizer
    @State private var hasSelectedManager = false

    private var isRecording: Bool {
        selectedManager == .analyzer ? analyzerManager.isRecording : recognizerManager.isRecording
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("使用中: \(selectedManager.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top)

                if selectedManager == .analyzer {
                    Text(analyzerManager.finalizedText + analyzerManager.volatileText)
                        .padding()
                } else {
                    Text(recognizerManager.recognizedText)
                        .padding()
                }

                Button(action: {
                    if selectedManager == .analyzer {
                        if isRecording {
                            analyzerManager.stopAnalyzer()
                        } else {
                            analyzerManager.startAnalyzer { error in
                                print("[Speech] SpeechAnalyzer failed (\(error)). Falling back to SFSpeechRecognizer.")
                                selectedManager = .recognizer
                                recognizerManager.startRecognition()
                            }
                        }
                    } else {
                        if isRecording {
                            recognizerManager.stopRecognition()
                        } else {
                            recognizerManager.startRecognition()
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 30))
                        Text(isRecording ? "停止" : "音声入力")
                            .font(.headline)
                    }
                    .foregroundColor(isRecording ? .red : .blue)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isRecording ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("音声認識")
            .task {
                guard !hasSelectedManager else { return }
                hasSelectedManager = true

                if await analyzerManager.canUseAnalyzer() {
                    selectedManager = .analyzer
                    print("[Speech] Using SpeechAnalyzer.")
                } else {
                    selectedManager = .recognizer
                    print("[Speech] SpeechAnalyzer unavailable. Using SFSpeechRecognizer.")
                }
            }
        }
    }
}
#endif

private struct RecognizerOnlyView: View {
    @State private var recognizerManager = SpeechRecognizerManager()
    @State private var hasPrintedEngine = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("このiOSバージョンでは Speech Analyzer は利用できません。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Speech Recognizer を使用します")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(recognizerManager.recognizedText)
                    .padding()

                Button(action: {
                    if recognizerManager.isRecording {
                        recognizerManager.stopRecognition()
                    } else {
                        recognizerManager.startRecognition()
                    }
                }) {
                    HStack {
                        Image(systemName: recognizerManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 30))
                        Text(recognizerManager.isRecording ? "停止" : "音声入力")
                            .font(.headline)
                    }
                    .foregroundColor(recognizerManager.isRecording ? .red : .blue)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(recognizerManager.isRecording ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("音声認識")
            .task {
                guard !hasPrintedEngine else { return }
                hasPrintedEngine = true
                print("[Speech] SpeechAnalyzer unavailable on this OS. Using SFSpeechRecognizer.")
            }
        }
    }
}

#Preview {
    ContentView()
}
