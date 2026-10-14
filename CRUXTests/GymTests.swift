import CoreLocation
import Foundation
import SwiftData
import Testing
@testable import CRUX

@Suite("Gyms")
@MainActor
struct GymTests {
    private func makeApp() -> AppModel {
        let defaults = UserDefaults(suiteName: "crux.tests.\(UUID().uuidString)")!
        return AppModel(container: CRUXApp.makeContainer(inMemory: true), defaults: defaults)
    }

    @Test func firstLaunchCreatesHiveWithStarterWalls() {
        let app = makeApp()
        #expect(app.gyms.count == 1)
        #expect(app.currentGym?.name == "Hive Vancouver")
        #expect(app.currentGym?.walls?.count == AppModel.defaultWallNames.count)
    }

    @Test func nearestGymWithinRadius() {
        let vancouver = Gym(name: "Hive Vancouver")
        vancouver.setLocation(CLLocationCoordinate2D(latitude: 49.2700, longitude: -123.0900))
        let surrey = Gym(name: "Hive Surrey")
        surrey.setLocation(CLLocationCoordinate2D(latitude: 49.1900, longitude: -122.8500))
        let noLocation = Gym(name: "Somewhere")

        let nearSurrey = CLLocation(latitude: 49.1910, longitude: -122.8505) // ~110 m away
        #expect(GymLocator.nearestGym(to: nearSurrey, in: [vancouver, surrey, noLocation])?.name == "Hive Surrey")

        let farAway = CLLocation(latitude: 49.2300, longitude: -122.9700)
        #expect(GymLocator.nearestGym(to: farAway, in: [vancouver, surrey, noLocation]) == nil)
    }

    @Test func switchingGymsWrapsAnOpenSession() throws {
        let app = makeApp()
        let vancouver = try #require(app.currentGym)
        let wall = try #require(vancouver.sortedWalls.first)
        let climb = Climb(grade: .three, holdColor: .blue)
        app.context.insert(climb)
        climb.wall = wall
        app.sessions.log(.attempt, on: climb)
        #expect(app.sessions.activeSession?.gym?.id == vancouver.id)

        let surrey = app.addGym(named: "Hive Surrey")
        let ended = app.select(surrey)

        #expect(ended?.gym?.id == vancouver.id)
        #expect(ended?.endedAt != nil)
        #expect(app.sessions.activeSession == nil)
        #expect(app.currentGym?.id == surrey.id)
    }

    @Test func reselectingTheSameGymKeepsTheSession() throws {
        let app = makeApp()
        let gym = try #require(app.currentGym)
        let climb = Climb(grade: .two, holdColor: .red)
        app.context.insert(climb)
        climb.wall = gym.sortedWalls.first
        app.sessions.log(.attempt, on: climb)

        #expect(app.select(gym) == nil)
        #expect(app.sessions.activeSession != nil)
    }

    @Test func deletingCurrentGymFallsBackAndRemovesItsClimbs() throws {
        let app = makeApp()
        let vancouver = try #require(app.currentGym)
        let surrey = app.addGym(named: "Hive Surrey")
        app.select(surrey)
        let climb = Climb(grade: .four, holdColor: .green)
        app.context.insert(climb)
        climb.wall = surrey.sortedWalls.first
        try app.context.save()

        app.delete(surrey)

        #expect(app.currentGym?.id == vancouver.id)
        #expect(app.gyms.map(\.name) == ["Hive Vancouver"])
        #expect(((try? app.context.fetch(FetchDescriptor<Climb>())) ?? []).isEmpty)
    }

    @Test func lastGymCannotBeDeleted() throws {
        let app = makeApp()
        let only = try #require(app.currentGym)
        app.delete(only)
        #expect(app.gyms.count == 1)
    }

    @Test func autoDetectIsOffByDefault() async {
        let app = makeApp()
        #expect(!app.autoSwitchGym)
        #expect(await app.autoDetectGym() == nil)
    }
}
