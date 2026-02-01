import SwiftUI
import PhotosUI
import AVKit

/// A view for picking and displaying workout media
struct MediaPickerButton: View {
    @Binding var selectedItems: [PhotosPickerItem]
    @Binding var mediaData: [MediaItem]
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 12) {
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 10,
                matching: .any(of: [.images, .videos])
            ) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text(mediaData.isEmpty ? "Add Photos/Videos" : "Add More")
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.rallyOrange.opacity(0.1))
                .foregroundColor(.rallyOrange)
                .cornerRadius(8)
            }
            .onChange(of: selectedItems) { oldValue, newValue in
                Task {
                    await processSelectedItems(newValue)
                }
            }

            if isProcessing {
                ProgressView("Processing media...")
                    .font(.caption)
            }
        }
    }

    private func processSelectedItems(_ items: [PhotosPickerItem]) async {
        await MainActor.run { isProcessing = true }

        for item in items {
            // Skip if already processed
            if mediaData.contains(where: { $0.pickerItem?.itemIdentifier == item.itemIdentifier }) {
                continue
            }

            // Try to load as image first
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    mediaData.append(MediaItem(image: uiImage, type: .photo, pickerItem: item))
                }
            }
            // Try to load as video
            else if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
                await MainActor.run {
                    mediaData.append(MediaItem(videoURL: movie.url, type: .video, pickerItem: item))
                }
            }
        }

        await MainActor.run { isProcessing = false }
    }
}

/// Represents a media item before saving
struct MediaItem: Identifiable {
    let id = UUID()
    var image: UIImage?
    var videoURL: URL?
    var type: MediaType
    var pickerItem: PhotosPickerItem?

    enum MediaType {
        case photo
        case video
    }

    var thumbnail: UIImage? {
        switch type {
        case .photo:
            return image
        case .video:
            guard let url = videoURL else { return nil }
            return generateVideoThumbnail(from: url)
        }
    }

    private func generateVideoThumbnail(from url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try imageGenerator.copyCGImage(at: CMTime(seconds: 0, preferredTimescale: 1), actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
}

/// Transferable for videos
struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}

/// Grid display of selected media
struct MediaPreviewGrid: View {
    @Binding var mediaItems: [MediaItem]
    let columns = [GridItem(.adaptive(minimum: 80))]

    var body: some View {
        if !mediaItems.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Media (\(mediaItems.count))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Clear All") {
                        mediaItems.removeAll()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(mediaItems) { item in
                        MediaThumbnailView(item: item) {
                            mediaItems.removeAll { $0.id == item.id }
                        }
                    }
                }
            }
        }
    }
}

/// Individual thumbnail view
struct MediaThumbnailView: View {
    let item: MediaItem
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let thumbnail = item.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: item.type == .video ? "video" : "photo")
                            .foregroundColor(.secondary)
                    )
            }

            // Video indicator
            if item.type == .video {
                Image(systemName: "play.circle.fill")
                    .foregroundColor(.white)
                    .shadow(radius: 2)
                    .padding(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .padding(4)
        }
        .frame(width: 80, height: 80)
    }
}

/// View for displaying saved workout media (read-only)
struct WorkoutMediaGallery: View {
    let media: [WorkoutMedia]
    @State private var selectedMedia: WorkoutMedia?
    @State private var showingFullScreen = false

    let columns = [GridItem(.adaptive(minimum: 100))]

    var body: some View {
        if !media.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Photos & Videos")
                    .font(.headline)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(media) { item in
                        SavedMediaThumbnail(media: item)
                            .onTapGesture {
                                selectedMedia = item
                                showingFullScreen = true
                            }
                    }
                }
            }
            .sheet(isPresented: $showingFullScreen) {
                if let media = selectedMedia {
                    FullScreenMediaView(media: media)
                }
            }
        }
    }
}

/// Editable gallery that allows viewing and deleting media
struct WorkoutMediaGalleryEditable: View {
    let media: [WorkoutMedia]
    let onDelete: (WorkoutMedia) -> Void

    @State private var selectedMedia: WorkoutMedia?
    @State private var showingFullScreen = false
    @State private var mediaToDelete: WorkoutMedia?
    @State private var showingDeleteConfirmation = false

    let columns = [GridItem(.adaptive(minimum: 100))]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(media) { item in
                EditableSavedMediaThumbnail(media: item) {
                    mediaToDelete = item
                    showingDeleteConfirmation = true
                }
                .onTapGesture {
                    selectedMedia = item
                    showingFullScreen = true
                }
            }
        }
        .sheet(isPresented: $showingFullScreen) {
            if let media = selectedMedia {
                FullScreenMediaView(media: media)
            }
        }
        .alert("Delete Media", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let media = mediaToDelete {
                    onDelete(media)
                }
            }
        } message: {
            Text("Are you sure you want to delete this photo/video?")
        }
    }
}

/// Editable thumbnail with delete button
struct EditableSavedMediaThumbnail: View {
    let media: WorkoutMedia
    let onDelete: () -> Void
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 100, height: 100)
                        .overlay(
                            ProgressView()
                        )
                }

                if media.mediaType == .video {
                    Image(systemName: "play.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                }
            }

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white, .red)
                    .shadow(radius: 2)
            }
            .padding(4)
        }
        .frame(width: 100, height: 100)
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        Task {
            let image: UIImage?
            if media.mediaType == .photo {
                image = MediaService.shared.loadImage(filename: media.filename)
            } else {
                image = MediaService.shared.generateVideoThumbnail(filename: media.filename)
            }
            await MainActor.run {
                thumbnail = image
            }
        }
    }
}

/// Thumbnail for saved media
struct SavedMediaThumbnail: View {
    let media: WorkoutMedia
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 100, height: 100)
                    .overlay(
                        ProgressView()
                    )
            }

            if media.mediaType == .video {
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .shadow(radius: 2)
            }
        }
        .frame(width: 100, height: 100)
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        Task {
            let image: UIImage?
            if media.mediaType == .photo {
                image = MediaService.shared.loadImage(filename: media.filename)
            } else {
                image = MediaService.shared.generateVideoThumbnail(filename: media.filename)
            }
            await MainActor.run {
                thumbnail = image
            }
        }
    }
}

/// Full screen media viewer
struct FullScreenMediaView: View {
    let media: WorkoutMedia
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    var body: some View {
        NavigationStack {
            Group {
                if media.mediaType == .photo {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        ProgressView()
                    }
                } else {
                    VideoPlayer(player: AVPlayer(url: MediaService.shared.getMediaURL(filename: media.filename)))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if media.mediaType == .photo {
                image = MediaService.shared.loadImage(filename: media.filename)
            }
        }
    }
}

#Preview {
    VStack {
        MediaPreviewGrid(mediaItems: .constant([]))
    }
    .padding()
}
