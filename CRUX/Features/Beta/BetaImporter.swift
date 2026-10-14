import PhotosUI
import SwiftData
import SwiftUI

/// Turns picked or captured media into stored `BetaMedia` on a climb.
enum BetaImporter {
    static func importItems(_ items: [PhotosPickerItem], into climb: Climb, attempt: Attempt? = nil, context: ModelContext) async {
        for item in items {
            let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
            do {
                if isVideo, let video = try await item.loadTransferable(type: PickedVideo.self) {
                    let name = try MediaStore.saveVideo(from: video.url)
                    try? FileManager.default.removeItem(at: video.url)
                    attach(.video, fileName: name, to: climb, attempt: attempt, context: context)
                } else if let data = try await item.loadTransferable(type: Data.self) {
                    let name = try MediaStore.savePhoto(data)
                    attach(.photo, fileName: name, to: climb, attempt: attempt, context: context)
                }
            } catch {
                continue
            }
        }
        try? context.save()
    }

    static func importCaptured(_ capture: CameraCapture, into climb: Climb, attempt: Attempt? = nil, context: ModelContext) {
        do {
            switch capture {
            case .photo(let image):
                guard let data = image.jpegData(compressionQuality: 0.85) else { return }
                attach(.photo, fileName: try MediaStore.savePhoto(data), to: climb, attempt: attempt, context: context)
            case .video(let url):
                attach(.video, fileName: try MediaStore.saveVideo(from: url), to: climb, attempt: attempt, context: context)
            }
            try? context.save()
        } catch {
            return
        }
    }

    static func delete(_ media: BetaMedia, context: ModelContext) {
        MediaStore.delete(media.fileName)
        context.delete(media)
        try? context.save()
    }

    private static func attach(_ kind: MediaKind, fileName: String, to climb: Climb, attempt: Attempt?, context: ModelContext) {
        let media = BetaMedia(kind: kind, fileName: fileName)
        context.insert(media)
        media.climb = climb
        media.attempt = attempt ?? climb.chronologicalAttempts.last
    }
}
