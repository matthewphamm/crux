import CoreLocation
import Foundation
import MapKit
import Observation

/// One-shot, when-in-use location for recognising which gym you've walked into.
/// Location is only read when the app opens and is never stored or sent anywhere.
@Observable
final class GymLocator: NSObject, CLLocationManagerDelegate {
    /// How close you need to be for a gym to count as "here". Generous, since GPS indoors drifts.
    static let detectionRadius: CLLocationDistance = 400

    private let manager = CLLocationManager()
    private var pending: [CheckedContinuation<CLLocation?, Never>] = []

    private(set) var authorization: CLAuthorizationStatus

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    var isDenied: Bool {
        authorization == .denied || authorization == .restricted
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    /// A single location fix, or nil if unavailable or not permitted.
    func currentLocation() async -> CLLocation? {
        guard isAuthorized else { return nil }
        return await withCheckedContinuation { continuation in
            pending.append(continuation)
            if pending.count == 1 { manager.requestLocation() }
        }
    }

    /// The closest gym within the detection radius.
    static func nearestGym(to location: CLLocation, in gyms: [Gym], radius: CLLocationDistance = detectionRadius) -> Gym? {
        gyms
            .compactMap { gym in gym.location.map { (gym, $0.distance(from: location)) } }
            .filter { $0.1 <= radius }
            .min { $0.1 < $1.1 }?
            .0
    }

    /// Searches Apple Maps for a place by name, e.g. "Hive Climbing Surrey".
    static func search(_ query: String, near location: CLLocation?) async -> [GymPlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest
        if let location {
            request.region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 80_000, longitudinalMeters: 80_000)
        }
        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }
        return response.mapItems.prefix(8).map { item in
            GymPlace(
                name: item.name ?? query,
                address: item.address?.shortAddress ?? "",
                coordinate: item.location.coordinate
            )
        }
    }

    private func finish(_ location: CLLocation?) {
        let waiting = pending
        pending = []
        waiting.forEach { $0.resume(returning: location) }
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in self.finish(location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(nil) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.authorization = status }
    }
}

struct GymPlace: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: GymPlace, rhs: GymPlace) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
