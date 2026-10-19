import Foundation
import Testing
import UIKit
@testable import CRUX

@Suite("Beta media")
@MainActor
struct MediaStoreTests {
    @Test func savedPhotoLoadsBack() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1 // default is the screen scale, which would store 120 px
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30), format: format).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }
        let data = try #require(image.pngData())

        let name = try MediaStore.savePhoto(data)
        defer { MediaStore.delete(name) }

        let loaded = try #require(MediaStore.image(for: name))
        #expect(loaded.size.width == 40)
    }
}
