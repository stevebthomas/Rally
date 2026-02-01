import Foundation

/// Service for parsing workout descriptions using OpenAI GPT API
final class GPTParserService {
    private let baseURL = "https://api.openai.com/v1/chat/completions"

    enum GPTError: LocalizedError {
        case noAPIKey
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case apiError(String)
        case parsingFailed

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "OpenAI API key not configured."
            case .invalidURL:
                return "Invalid API URL."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse:
                return "Invalid response from server."
            case .apiError(let message):
                return "API error: \(message)"
            case .parsingFailed:
                return "Failed to parse workout data."
            }
        }
    }

    /// Parse workout transcription text using GPT
    func parseWorkout(transcription: String, apiKey: String) async throws -> [ParsedExercise] {
        guard !apiKey.isEmpty else {
            throw GPTError.noAPIKey
        }

        guard let url = URL(string: baseURL) else {
            throw GPTError.invalidURL
        }

        let systemPrompt = """
        You are a workout parser. Extract structured exercise data from the user's workout description.

        IMPORTANT: Group all sets of the same exercise together into ONE exercise entry, even if each set has different reps or weights. This is called "progressive overload" or "pyramid sets" and is very common.

        For example, if someone says "I did 4 sets of bench press - first set 12 reps at 120, second set 10 reps at 145, third set 8 reps at 185, fourth set 1 rep at 220", this should be ONE exercise with 4 sets, NOT four separate exercises.

        Return ONLY valid JSON in this exact format, no other text:
        {
            "exercises": [
                {
                    "name": "Bench Press",
                    "exerciseType": "weighted",
                    "sets": [
                        {"reps": 12, "weight": 120, "unit": "lbs"},
                        {"reps": 10, "weight": 145, "unit": "lbs"},
                        {"reps": 8, "weight": 185, "unit": "lbs"},
                        {"reps": 1, "weight": 220, "unit": "lbs"}
                    ]
                }
            ]
        }

        Rules:
        - exerciseType: "weighted" for exercises with weights, "bodyweight" for exercises without weights
        - Common bodyweight exercises: pull-ups, chin-ups, push-ups, dips, planks, sit-ups, crunches, burpees
        - For bodyweight exercises, set weight to 0
        - Default unit to "lbs" if not specified
        - If all sets have the same reps/weight (e.g., "3 sets of 10 at 135"), create 3 identical set entries
        - ALWAYS consolidate sets of the same exercise - never create duplicate exercise entries
        """

        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": transcription]
        ]

        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messages,
            "temperature": 0.1,
            "max_tokens": 2000
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GPTError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(GPTErrorResponse.self, from: data) {
                throw GPTError.apiError(errorResponse.error.message)
            }
            throw GPTError.apiError("HTTP \(httpResponse.statusCode)")
        }

        let gptResponse = try JSONDecoder().decode(GPTResponse.self, from: data)

        guard let content = gptResponse.choices.first?.message.content else {
            throw GPTError.parsingFailed
        }

        // Parse the JSON response
        return try parseGPTResponse(content)
    }

    private func parseGPTResponse(_ content: String) throws -> [ParsedExercise] {
        // Clean up the response - remove markdown code blocks if present
        var jsonString = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        }
        if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw GPTError.parsingFailed
        }

        let parsed = try JSONDecoder().decode(GPTExerciseResponse.self, from: jsonData)

        return parsed.exercises.map { exercise in
            let isBodyweight = exercise.exerciseType == "bodyweight"
            var sets: [ParsedSet] = []

            for (index, setData) in exercise.sets.enumerated() {
                sets.append(ParsedSet(
                    setNumber: index + 1,
                    reps: setData.reps,
                    weight: isBodyweight ? 0 : setData.weight,
                    unit: setData.unit == "kg" ? .kg : .lbs
                ))
            }

            return ParsedExercise(
                name: exercise.name,
                sets: sets,
                category: isBodyweight ? .bodyweight : .weighted
            )
        }
    }
}

// MARK: - Response Models

private struct GPTResponse: Codable {
    let choices: [GPTChoice]
}

private struct GPTChoice: Codable {
    let message: GPTMessage
}

private struct GPTMessage: Codable {
    let content: String
}

private struct GPTErrorResponse: Codable {
    let error: GPTErrorDetail
}

private struct GPTErrorDetail: Codable {
    let message: String
}

private struct GPTExerciseResponse: Codable {
    let exercises: [GPTExerciseData]
}

private struct GPTExerciseData: Codable {
    let name: String
    let exerciseType: String
    let sets: [GPTSetData]
}

private struct GPTSetData: Codable {
    let reps: Int
    let weight: Double
    let unit: String
}
