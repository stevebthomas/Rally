import Foundation
import Speech
import AVFoundation

/// On-device speech recognition using Apple's Speech framework
class SpeechRecognitionService {

    enum SpeechError: LocalizedError {
        case notAuthorized
        case notAvailable
        case recognitionFailed
        case audioFileError

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Speech recognition not authorized. Please enable it in Settings."
            case .notAvailable:
                return "Speech recognition is not available on this device."
            case .recognitionFailed:
                return "Failed to recognize speech. Please try again."
            case .audioFileError:
                return "Could not read the audio file."
            }
        }
    }

    /// Check and request speech recognition authorization
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Check if on-device recognition is available
    var isOnDeviceAvailable: Bool {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
            return false
        }
        return recognizer.supportsOnDeviceRecognition
    }

    /// Transcribe audio file using on-device speech recognition
    func transcribe(audioURL: URL) async throws -> String {
        // Check authorization
        let authorized = await requestAuthorization()
        guard authorized else {
            throw SpeechError.notAuthorized
        }

        // Create recognizer
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            throw SpeechError.notAvailable
        }

        // Create recognition request
        let request = SFSpeechURLRecognitionRequest(url: audioURL)

        // Enable on-device recognition for offline use
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        // Configure for best results
        request.shouldReportPartialResults = false
        request.taskHint = .dictation

        // Perform recognition
        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let result = result else {
                    continuation.resume(throwing: SpeechError.recognitionFailed)
                    return
                }

                if result.isFinal {
                    let transcription = result.bestTranscription.formattedString
                    continuation.resume(returning: transcription)
                }
            }
        }
    }
}
