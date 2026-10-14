import AVFoundation
import CoreTransferable
import Foundation
import UIKit
import UniformTypeIdentifiers

/// Stores beta photos and videos as files in Application Support, keeping the SwiftData store small.
enum MediaStore {
    static var directory: URL {
        let base = URL.applicationSupportDirectory.appending(path: "BetaMedia", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static func url(for fileName: String) -> URL {
        directory.appending(path: fileName)
    }

    /// Writes image data and returns the stored file name.
    static func savePhoto(_ data: Data) throws -> String {
        let name = "\(UUID().uuidString).jpg"
        let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.85) ?? data
        try jpeg.write(to: url(for: name), options: .atomic)
        return name
    }

    /// Moves or copies a video file into the store and returns the stored file name.
    static func saveVideo(from source: URL) throws -> String {
        let ext = source.pathExtension.isEmpty ? "mov" : source.pathExtension
        let name = "\(UUID().uuidString).\(ext)"
        try FileManager.default.copyItem(at: source, to: url(for: name))
        return name
    }

    static func delete(_ fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    static func image(for fileName: String) -> UIImage? {
        UIImage(contentsOfFile: url(for: fileName).path())
    }

    /// A poster frame for a stored video.
    static func thumbnail(forVideo fileName: String) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url(for: fileName)))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)
        guard let (image, _) = try? await generator.image(at: .zero) else { return nil }
        return UIImage(cgImage: image)
    }
}

/// Lets PhotosPicker hand us a video as a file instead of loading it into memory.
nonisolated struct PickedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let copy = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).\(received.file.pathExtension)")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedVideo(url: copy)
        }
    }
}
