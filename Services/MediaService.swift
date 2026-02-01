import Foundation
import UIKit
import AVFoundation

/// Service for handling workout media (photos/videos)
class MediaService {
    static let shared = MediaService()

    private let mediaDirectory: URL

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        mediaDirectory = documentsPath.appendingPathComponent("WorkoutMedia")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
    }

    /// Save an image and return the filename
    func saveImage(_ image: UIImage, quality: CGFloat = 0.8) -> String? {
        let filename = "\(UUID().uuidString).jpg"
        let fileURL = mediaDirectory.appendingPathComponent(filename)

        guard let data = image.jpegData(compressionQuality: quality) else {
            return nil
        }

        do {
            try data.write(to: fileURL)
            return filename
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }

    /// Save video from URL and return the filename
    func saveVideo(from sourceURL: URL) -> String? {
        let filename = "\(UUID().uuidString).mp4"
        let destinationURL = mediaDirectory.appendingPathComponent(filename)

        do {
            // Copy the video file
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return filename
        } catch {
            print("Error saving video: \(error)")
            return nil
        }
    }

    /// Load an image by filename
    func loadImage(filename: String) -> UIImage? {
        let fileURL = mediaDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        return UIImage(data: data)
    }

    /// Get the URL for a media file
    func getMediaURL(filename: String) -> URL {
        return mediaDirectory.appendingPathComponent(filename)
    }

    /// Delete a media file
    func deleteMedia(filename: String) {
        let fileURL = mediaDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Generate a thumbnail for a video
    func generateVideoThumbnail(filename: String) -> UIImage? {
        let fileURL = mediaDirectory.appendingPathComponent(filename)
        let asset = AVAsset(url: fileURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try imageGenerator.copyCGImage(at: CMTime(seconds: 0, preferredTimescale: 1), actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print("Error generating thumbnail: \(error)")
            return nil
        }
    }
}
