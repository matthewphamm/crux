import Foundation
import Testing
@testable import CRUX

@Suite("Hex grading")
struct HexGradeTests {
    @Test("Hex grades map to Hive's published V ranges", arguments: [
        (1, "VB–V0"), (2, "V0–V2"), (3, "V2–V4"), (4, "V4–V6"), (5, "V6–V8"), (6, "V8–V10"), (7, "V10+"),
    ])
    func vRanges(grade: Int, expected: String) {
        #expect(HexGrade(rawValue: grade)?.vRange == expected)
        #expect(HiveHex.shared.approximateV(for: grade) == expected)
    }

    @Test func clampsOutOfRangeValues() {
        #expect(HexGrade(clamping: 0) == .one)
        #expect(HexGrade(clamping: 12) == .seven)
        #expect(HexGrade(clamping: 4) == .four)
    }

    @Test func labels() {
        #expect(HexGrade.four.label == "4 Hex")
        #expect(HexGrade.four.fullLabel == "4 Hex · V4–V6")
    }
}

@Suite("Send type inference")
struct SendTypeTests {
    @Test func firstTrySendIsFlash() {
        #expect(SendType.inferred(fromPrior: []) == .flash)
    }

    @Test func sendAfterAttemptsIsSend() {
        #expect(SendType.inferred(fromPrior: [.attempt, .attempt]) == .send)
    }

    @Test func sendAfterSendIsRepeat() {
        #expect(SendType.inferred(fromPrior: [.send]) == .repeat)
        #expect(SendType.inferred(fromPrior: [.attempt, .send, .attempt]) == .repeat)
    }
}

@Suite("Climb status")
@MainActor
struct ClimbStatusTests {
    @Test func untriedThenWorking() {
        let env = TestEnvironment()
        let climb = env.climb()
        #expect(climb.status == .untried)
        env.sessions.log(.attempt, on: climb)
        #expect(climb.status == .working)
    }

    @Test func becomesProjectAtThreshold() {
        let env = TestEnvironment()
        let climb = env.climb()
        env.work(climb, failures: Climb.projectThreshold - 1, thenSend: false)
        #expect(climb.status == .working)
        env.work(climb, failures: 1, thenSend: false)
        #expect(climb.status == .project)
    }

    @Test func flaggedClimbIsProjectImmediately() {
        let env = TestEnvironment()
        let climb = env.climb()
        climb.isProjectFlagged = true
        #expect(climb.status == .project)
    }

    @Test func flashAndSendStatuses() {
        let env = TestEnvironment()
        let flashed = env.climb()
        env.sessions.log(.send, on: flashed)
        #expect(flashed.status == .flashed)

        let sent = env.climb()
        env.work(sent, failures: 2, thenSend: true)
        #expect(sent.status == .sent)
        #expect(sent.triesToFirstSend == 3)
    }

    @Test func explicitSendTypeOverridesInference() {
        let env = TestEnvironment()
        let climb = env.climb()
        let result = env.sessions.log(.send, on: climb, sendType: .send)
        #expect(result.sendType == .send)
        #expect(climb.status == .sent)
    }
}
