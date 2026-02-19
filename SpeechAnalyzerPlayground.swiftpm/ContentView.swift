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
enum ManagerType: String, CaseIterable {
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
    @State private var selectedManager: ManagerType = .analyzer

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
                            analyzerManager.startAnalyzer()
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(ManagerType.allCases, id: \.self) { managerType in
                            Button(action: {
                                if selectedManager == .analyzer && analyzerManager.isRecording {
                                    analyzerManager.stopAnalyzer()
                                } else if selectedManager == .recognizer && recognizerManager.isRecording {
                                    recognizerManager.stopRecognition()
                                }

                                selectedManager = managerType
                            }) {
                                HStack {
                                    Text(managerType.displayName)
                                    if selectedManager == managerType {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}
#endif

private struct RecognizerOnlyView: View {
    @State private var recognizerManager = SpeechRecognizerManager()

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
        }
    }
}

#Preview {
    ContentView()
}
