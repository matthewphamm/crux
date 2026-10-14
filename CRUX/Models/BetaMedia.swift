import Foundation
import SwiftData

nonisolated enum MediaKind: String, Codable {
    case photo, video
}

/// A photo or video of beta. The file lives in Application Support; only its name is stored here.
@Model
final class BetaMedia {
    var id: UUID = UUID()
    var kindRaw: String = MediaKind.photo.rawValue
    var fileName: String = ""
    var createdAt: Date = Date.now
    var climb: Climb?
    var attempt: Attempt?

    init(kind: MediaKind, fileName: String, createdAt: Date = .now) {
        self.kindRaw = kind.rawValue
        self.fileName = fileName
        self.createdAt = createdAt
    }

    var kind: MediaKind { MediaKind(rawValue: kindRaw) ?? .photo }
}
