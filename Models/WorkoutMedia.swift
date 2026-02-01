import Foundation
import SwiftData

/// Represents a media item (photo or video) associated with a workout
@Model
final class WorkoutMedia {
    var id: UUID
    var filename: String
    var mediaType: MediaType
    var createdAt: Date
    var caption: String?

    @Relationship
    var workout: Workout?

    enum MediaType: String, Codable {
        case photo
        case video
    }

    init(
        id: UUID = UUID(),
        filename: String,
        mediaType: MediaType,
        createdAt: Date = Date(),
        caption: String? = nil,
        workout: Workout? = nil
    ) {
        self.id = id
        self.filename = filename
        self.mediaType = mediaType
        self.createdAt = createdAt
        self.caption = caption
        self.workout = workout
    }

    /// Get the full URL for the media file
    var fileURL: URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsPath?.appendingPathComponent("WorkoutMedia").appendingPathComponent(filename)
    }

    /// Check if the media file exists
    var fileExists: Bool {
        guard let url = fileURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
}
