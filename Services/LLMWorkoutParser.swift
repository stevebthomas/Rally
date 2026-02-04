import Foundation

/// Hybrid workout parser that uses LLM preprocessing with regex fallback
class LLMWorkoutParser {

    private let offlineParser = OfflineWorkoutParser()

    // MARK: - JSON Schema for LLM Output

    struct LLMExerciseOutput: Codable {
        let exercises: [LLMExercise]
        let confidence: Double // 0.0 to 1.0
    }

    struct LLMExercise: Codable {
        let name: String
        let sets: Int
        let reps: Int
        let weight: Double?
        let unit: String? // "lbs" or "kg"
        let isBodyweight: Bool
    }

    // MARK: - System Prompt

    private let systemPrompt = """
    You are a fitness workout parser. Extract exercise information from natural language into structured JSON.

    RULES:
    1. Identify: exercise name, sets, reps, weight, and unit (lbs/kg)
    2. Default to 1 set if not specified
    3. Default to 1 rep if not specified (when weight is mentioned without reps, assume it's a max/PR attempt)
    4. For bodyweight exercises, set weight to null and isBodyweight to true
    5. Handle singular "rep" (e.g., "1 rep", "a rep", "single rep" all mean 1 rep)

    GYM SHORTHAND DICTIONARY:

    PLATE MATH (barbell = 45lb bar, plates go on each side):
    - "a plate" or "1 plate" = 135lbs (45 bar + 45×2)
    - "2 plates" = 225lbs (45 bar + 90×2)
    - "3 plates" = 315lbs (45 bar + 135×2)
    - "4 plates" = 405lbs (45 bar + 180×2)

    PLATE COMBINATIONS (add extra plates per side):
    - "a plate and a 25" or "plate and 25" = 185lbs (135 + 25×2)
    - "a plate and a 10" = 155lbs (135 + 10×2)
    - "a plate and a 5" = 145lbs (135 + 5×2)
    - "2 plates and a 25" = 275lbs (225 + 25×2)
    - "2 plates and a 10" = 245lbs (225 + 10×2)
    - "put on a plate and 25" = 185lbs

    SMALL PLATE SLANG:
    - "quarter" = 25lb plate
    - "dime" = 10lb plate
    - "nickel" = 5lb plate
    - "just the bar" or "empty bar" = 45lbs
    - "bis" or "bi's" = Bicep Curls
    - "tris" or "tri's" = Tricep Extensions
    - "delts" = Shoulder Press or Lateral Raises
    - "lats" = Lat Pulldown or Pull Ups
    - "pecs" or "chest" = Bench Press
    - "quads" = Squats or Leg Press
    - "hams" = Leg Curls or Romanian Deadlift
    - "glutes" = Hip Thrusts or Glute Bridge
    - "PR" or "personal record" = note this is a max effort
    - "AMRAP" = As Many Reps As Possible (set reps to estimated count if given)
    - "drop set" = multiple sets with decreasing weight
    - "superset" = two exercises back to back
    - "5x5" format = 5 sets of 5 reps
    - "3x10" format = 3 sets of 10 reps
    - "hitting" or "hittin'" or "worked" = did exercise
    - "banged out" or "knocked out" = completed sets

    EXERCISE NAME NORMALIZATION:
    - Always use proper exercise names (e.g., "Bench Press" not "bench" or "benchin'")
    - Capitalize properly
    - Common normalizations:
      * bench/benchin'/flat bench -> "Bench Press"
      * squat/squatted/squatting -> "Squats"
      * dead/deads/deadlifted -> "Deadlift"
      * pullups/pull-ups/pulling up -> "Pull Ups"
      * curls/curled/curling -> "Bicep Curls"
      * ohp/overhead/military -> "Overhead Press"
      * rows/rowing/rowed -> "Barbell Row"
      * dips/dipped/dipping -> "Dips"

    OUTPUT FORMAT (JSON only, no markdown):
    {
      "exercises": [
        {
          "name": "Exercise Name",
          "sets": 3,
          "reps": 10,
          "weight": 135.0,
          "unit": "lbs",
          "isBodyweight": false
        }
      ],
      "confidence": 0.95
    }

    Set confidence based on:
    - 0.9-1.0: Clear, unambiguous input
    - 0.7-0.9: Some inference required
    - 0.5-0.7: Significant guessing
    - Below 0.5: Very uncertain, recommend fallback

    If input contains no workout information, return:
    {"exercises": [], "confidence": 0.0}
    """

    // MARK: - Parse with LLM

    /// Parse workout using LLM with fallback to regex parser
    func parseWorkout(transcription: String, apiKey: String) async -> [ParsedExercise] {
        // Try LLM parsing first
        if let llmResult = await parsewithLLM(transcription: transcription, apiKey: apiKey) {
            // Check confidence threshold
            if llmResult.confidence >= 0.6 && !llmResult.exercises.isEmpty {
                return convertLLMOutput(llmResult)
            }
        }

        // Fallback to regex-based parser
        return offlineParser.parseWorkout(transcription: transcription)
    }

    /// Parse using LLM only (for testing/debugging)
    func parsewithLLM(transcription: String, apiKey: String) async -> LLMExerciseOutput? {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o-mini", // Fast, cheap, good at structured output
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "Parse this workout: \(transcription)"]
            ],
            "temperature": 0.1, // Low temperature for consistent parsing
            "max_tokens": 500,
            "response_format": ["type": "json_object"] // Enforce JSON output
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("LLM Parser: HTTP error")
                return nil
            }

            // Parse OpenAI response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                print("LLM Parser: Failed to parse OpenAI response")
                return nil
            }

            // Parse the JSON content from the LLM
            guard let contentData = content.data(using: .utf8) else {
                return nil
            }

            let decoder = JSONDecoder()
            let result = try decoder.decode(LLMExerciseOutput.self, from: contentData)
            return result

        } catch {
            print("LLM Parser error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Convert LLM Output to ParsedExercise

    private func convertLLMOutput(_ output: LLMExerciseOutput) -> [ParsedExercise] {
        return output.exercises.map { llmExercise in
            var sets: [ParsedSet] = []

            for i in 1...llmExercise.sets {
                sets.append(ParsedSet(
                    setNumber: i,
                    reps: llmExercise.reps,
                    weight: llmExercise.weight ?? 0,
                    unit: llmExercise.unit == "kg" ? .kg : .lbs
                ))
            }

            return ParsedExercise(
                name: llmExercise.name,
                sets: sets,
                category: llmExercise.isBodyweight ? .bodyweight : .weighted
            )
        }
    }

    // MARK: - Offline-Only Parse (for when no API key)

    func parseOffline(transcription: String) -> [ParsedExercise] {
        return offlineParser.parseWorkout(transcription: transcription)
    }
}

