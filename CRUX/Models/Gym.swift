import CoreLocation
import Foundation
import SwiftData

@Model
final class Gym {
    var id: UUID = UUID()
    var name: String = ""
    var gradeSystemID: String = HiveHex.shared.id
    var createdAt: Date = Date.now
    /// Where the gym is, so CRUX. can switch to it automatically. Optional; stays on device.
    var latitude: Double?
    var longitude: Double?
    var address: String = ""

    @Relationship(deleteRule: .cascade, inverse: \Wall.gym)
    var walls: [Wall]? = []

    @Relationship(deleteRule: .nullify, inverse: \ClimbSession.gym)
    var sessions: [ClimbSession]? = []

    init(name: String) {
        self.name = name
    }

    var sortedWalls: [Wall] {
        (walls ?? []).sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
    }

    var location: CLLocation? {
        guard let latitude, let longitude else { return nil }
        return CLLocation(latitude: latitude, longitude: longitude)
    }

    func setLocation(_ coordinate: CLLocationCoordinate2D?, address: String = "") {
        latitude = coordinate?.latitude
        longitude = coordinate?.longitude
        self.address = coordinate == nil ? "" : address
    }
}
