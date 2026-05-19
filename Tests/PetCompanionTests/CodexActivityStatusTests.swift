import Foundation
import Testing
@testable import PetCompanion

@Suite("Codex activity classification")
struct CodexActivityStatusTests {
    private let classifier = CodexActivityClassifier()
    private let now = Date(timeIntervalSince1970: 1_000)

    @Test("Codex not running is offline")
    func codexNotRunningIsOffline() {
        let snapshot = CodexActivitySnapshot(
            codexIsRunning: false,
            latestActivityDate: now,
            now: now
        )

        #expect(classifier.classify(snapshot) == .offline)
    }

    @Test("Recent activity is working")
    func recentActivityIsWorking() {
        let snapshot = CodexActivitySnapshot(
            codexIsRunning: true,
            latestActivityDate: now.addingTimeInterval(-3),
            now: now,
            activeThreshold: 8
        )

        #expect(classifier.classify(snapshot) == .working)
    }

    @Test("Missing or stale activity waits for user")
    func missingOrStaleActivityWaits() {
        let missing = CodexActivitySnapshot(
            codexIsRunning: true,
            latestActivityDate: nil,
            now: now
        )
        let stale = CodexActivitySnapshot(
            codexIsRunning: true,
            latestActivityDate: now.addingTimeInterval(-200),
            now: now,
            waitingThreshold: 90
        )

        #expect(classifier.classify(missing) == .waiting)
        #expect(classifier.classify(stale) == .waiting)
    }

    @Test("Statuses map to pet animations")
    func statusMapsToAnimations() {
        let mapper = PetAnimationMapper()

        #expect(mapper.animation(for: .offline) == .failed)
        #expect(mapper.animation(for: .working) == .running)
        #expect(mapper.animation(for: .waiting) == .waiting)
    }

    @Test("Action frame counts use tweened assets")
    func actionFrameCountsUseTweenedAssets() {
        let framePolicy = PetAnimationFramePolicy()

        #expect(framePolicy.frameCount(for: .running) == 24)
        #expect(framePolicy.frameCount(for: .waving) == 24)
        #expect(framePolicy.frameCount(for: .turning) == 25)
    }

    @Test("Animation timing adapts to frame count")
    func animationTimingAdaptsToFrameCount() {
        let timingPolicy = PetAnimationTimingPolicy()

        #expect(timingPolicy.totalDuration(for: .running) == 2.4)
        #expect(timingPolicy.totalDuration(for: .waving) == 2.4)
        #expect(timingPolicy.totalDuration(for: .turning) == 3.24)
        #expect(abs(timingPolicy.frameInterval(for: .running, frameCount: 24) - 0.1) < 0.0001)
        #expect(abs(timingPolicy.frameInterval(for: .turning, frameCount: 25) - 0.1296) < 0.0001)
    }
}
