import Foundation

@main
struct StatusTestRunner {
    static func main() {
        let classifier = CodexActivityClassifier()
        let mapper = PetAnimationMapper()
        let now = Date(timeIntervalSince1970: 1_000)

        let offline = CodexActivitySnapshot(
            codexIsRunning: false,
            latestActivityDate: now,
            now: now
        )
        expect(classifier.classify(offline) == .offline, "Codex not running should be offline")

        let active = CodexActivitySnapshot(
            codexIsRunning: true,
            latestActivityDate: now.addingTimeInterval(-3),
            now: now,
            activeThreshold: 8
        )
        expect(classifier.classify(active) == .working, "recent activity should be working")

        let missing = CodexActivitySnapshot(
            codexIsRunning: true,
            latestActivityDate: nil,
            now: now
        )
        expect(classifier.classify(missing) == .waiting, "missing activity should be waiting")

        let stale = CodexActivitySnapshot(
            codexIsRunning: true,
            latestActivityDate: now.addingTimeInterval(-200),
            now: now,
            waitingThreshold: 90
        )
        expect(classifier.classify(stale) == .waiting, "stale activity should be waiting")

        expect(mapper.animation(for: .offline) == .failed, "offline should map to failed animation")
        expect(mapper.animation(for: .working) == .running, "working should map to running animation")
        expect(mapper.animation(for: .waiting) == .waiting, "waiting should map to waiting animation")

        let framePolicy = PetAnimationFramePolicy()
        expect(framePolicy.frameCount(for: .idle) == 10, "idle should use still pose frames")
        expect(framePolicy.frameCount(for: .running) == 24, "running should use tweened action frames")
        expect(framePolicy.frameCount(for: .waiting) == 10, "waiting should use still pose frames")
        expect(framePolicy.frameCount(for: .failed) == 10, "failed should use still pose frames")
        expect(framePolicy.frameCount(for: .waving) == 24, "waving should use tweened action frames")
        expect(framePolicy.frameCount(for: .jumping) == 8, "jumping should use still pose frames")
        expect(framePolicy.frameCount(for: .review) == 10, "review should use still pose frames")
        expect(framePolicy.frameCount(for: .turning) == 25, "turning should use interpolated turntable frames")

        let timingPolicy = PetAnimationTimingPolicy()
        expect(timingPolicy.totalDuration(for: .running) == 2.4, "running should keep a calm short-action duration")
        expect(timingPolicy.totalDuration(for: .waving) == 2.4, "waving should keep a calm short-action duration")
        expect(timingPolicy.totalDuration(for: .turning) == 3.24, "turning should keep the previous large-action duration")
        expect(abs(timingPolicy.frameInterval(for: .running, frameCount: 24) - 0.1) < 0.0001, "running interval should adapt to the denser frame count")
        expect(abs(timingPolicy.frameInterval(for: .turning, frameCount: 25) - 0.1296) < 0.0001, "turning interval should adapt to the denser frame count")

        let motionPolicy = PetMotionPolicy()
        expect(!motionPolicy.loopsContinuously(animation: .idle), "idle should not loop continuously")
        expect(!motionPolicy.loopsContinuously(animation: .running), "running should not loop continuously in calm mode")
        expect(!motionPolicy.loopsContinuously(animation: .waiting), "waiting should not loop continuously")
        expect(!motionPolicy.loopsContinuously(animation: .failed), "failed should not loop continuously")

        let ambientPolicy = PetAmbientActionPolicy()
        expect(ambientPolicy.restingAnimation(for: .working) == .review, "working should rest in a focused pose")
        expect(ambientPolicy.restingAnimation(for: .waiting) == .waiting, "waiting should rest in a waiting pose")
        expect(ambientPolicy.restingAnimation(for: .offline) == .failed, "offline should rest in failed pose")
        expect(ambientPolicy.ambientSuites(for: .working) == [[.running], [.waving], [.running]], "working should use visible short action suites")
        expect(ambientPolicy.ambientSuites(for: .waiting) == [[.waving], [.running]], "waiting should use visible short action suites")
        expect(ambientPolicy.ambientSuites(for: .offline) == [], "offline should rest without extra ambient actions")
        expect(ambientPolicy.ambientAnimations(for: .waiting).contains(.waving), "waiting should include visible short actions")
        expect(!ambientPolicy.ambientAnimations(for: .waiting).contains(.turning), "waiting should avoid inconsistent turntable frames")
        expect(ambientPolicy.largeActionSuites(for: .working) == [[.turning]], "working large actions should be isolated")
        expect(ambientPolicy.largeActionSuites(for: .waiting) == [[.turning]], "waiting large actions should be isolated")
        expect(ambientPolicy.largeActionSuites(for: .offline) == [], "offline should avoid large ambient actions")

        print("PASS status logic")
    }

    @discardableResult
    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
        return true
    }
}
