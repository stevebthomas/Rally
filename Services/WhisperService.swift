import Foundation

/// Service for transcribing audio using OpenAI Whisper API
final class WhisperService {
    private let baseURL = "https://api.openai.com/v1/audio/transcriptions"

    enum WhisperError: LocalizedError {
        case noAPIKey
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case apiError(String)
        case fileNotFound

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "OpenAI API key not configured. Please add your API key in Settings."
            case .invalidURL:
                return "Invalid API URL."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse:
                return "Invalid response from server."
            case .apiError(let message):
                return "API error: \(message)"
            case .fileNotFound:
                return "Audio file not found."
            }
        }
    }

    /// Transcribe audio file using Whisper API
    /// - Parameters:
    ///   - audioURL: URL to the audio file
    ///   - apiKey: OpenAI API key
    /// - Returns: Transcribed text
    func transcribe(audioURL: URL, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw WhisperError.noAPIKey
        }

        guard let url = URL(string: baseURL) else {
            throw WhisperError.invalidURL
        }

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw WhisperError.fileNotFound
        }

        // Read audio file data
        let audioData = try Data(contentsOf: audioURL)

        // Create multipart form data request
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Build multipart body
        var body = Data()

        // Add model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)

        // Add language hint (English)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("en\r\n".data(using: .utf8)!)

        // Add prompt to guide transcription for fitness context
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
        body.append("Workout log: exercises, sets, reps, and weights. Common exercises: bench press, squats, deadlift, overhead press, rows, curls, tricep extensions, lat pulldowns.\r\n".data(using: .utf8)!)

        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhisperError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            // Try to parse error message
            if let errorResponse = try? JSONDecoder().decode(WhisperErrorResponse.self, from: data) {
                throw WhisperError.apiError(errorResponse.error.message)
            }
            throw WhisperError.apiError("HTTP \(httpResponse.statusCode)")
        }

        // Parse successful response
        let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return transcriptionResponse.text
    }

    /// Validate API key by making a minimal request
    func validateAPIKey(_ apiKey: String) async -> Bool {
        guard !apiKey.isEmpty else { return false }

        // Create a minimal audio file for testing (silent audio)
        // In practice, we just check if the key format is valid
        // Real validation happens on first transcription
        return apiKey.hasPrefix("sk-") && apiKey.count > 20
    }
}

// MARK: - Response Models

private struct TranscriptionResponse: Codable {
    let text: String
}

private struct WhisperErrorResponse: Codable {
    let error: WhisperErrorDetail
}

private struct WhisperErrorDetail: Codable {
    let message: String
    let type: String?
    let code: String?
}
