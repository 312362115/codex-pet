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
        expect(framePolicy.frameCount(for: .glanceLeft) == 16, "glance left should use a short interpolated action clip")
        expect(framePolicy.frameCount(for: .glanceRight) == 16, "glance right should use a short interpolated action clip")
        expect(framePolicy.frameCount(for: .blink) == 5, "blink should use a tiny expression clip")
        expect(framePolicy.frameCount(for: .slowBlink) == 8, "slow blink should use a longer expression clip")
        expect(framePolicy.frameCount(for: .eyeShiftLeft) == 8, "eye shifts should use tiny expression clips")
        expect(framePolicy.frameCount(for: .breathing) == 12, "breathing should use subtle micro frames")
        expect(framePolicy.frameCount(for: .weightShift) == 16, "weight shift should use micro action frames")
        expect(framePolicy.frameCount(for: .adjustGlasses) == 24, "adjust glasses should use a short action clip")
        expect(framePolicy.frameCount(for: .tapKeyboard) == 24, "tap keyboard should use a short action clip")
        expect(framePolicy.frameCount(for: .focusShift) == 24, "focus shift should use a medium action clip")
        expect(framePolicy.frameCount(for: .lookAround) == 32, "look around should use a fuller large-action clip")
        expect(framePolicy.frameCount(for: .stretch) == 32, "stretch should use a fuller large-action clip")

        let timingPolicy = PetAnimationTimingPolicy()
        expect(timingPolicy.totalDuration(for: .running) == 2.4, "running should keep a calm short-action duration")
        expect(timingPolicy.totalDuration(for: .waving) == 2.4, "waving should keep a calm short-action duration")
        expect(timingPolicy.totalDuration(for: .turning) == 3.24, "turning should keep the previous large-action duration")
        expect(timingPolicy.totalDuration(for: .glanceLeft) == 1.6, "glance left should be shorter than a full turn")
        expect(timingPolicy.totalDuration(for: .glanceRight) == 1.6, "glance right should be shorter than a full turn")
        expect(timingPolicy.totalDuration(for: .blink) == 0.25, "blink should be brief")
        expect(timingPolicy.totalDuration(for: .slowBlink) == 0.7, "slow blink should stay readable")
        expect(timingPolicy.totalDuration(for: .eyeShiftLeft) == 0.8, "eye shifts should stay quick")
        expect(timingPolicy.totalDuration(for: .breathing) == 1.2, "breathing should stay subtle")
        expect(timingPolicy.totalDuration(for: .weightShift) == 1.6, "micro shifts should stay short")
        expect(timingPolicy.totalDuration(for: .tapKeyboard) == 2.4, "small work gestures should use short-action duration")
        expect(timingPolicy.totalDuration(for: .lookAround) == 3.2, "look around should be slower than a short glance")
        expect(timingPolicy.totalDuration(for: .stretch) == 3.6, "large body gestures should be slow enough to read")
        expect(abs(timingPolicy.frameInterval(for: .running, frameCount: 24) - 0.1) < 0.0001, "running interval should adapt to the denser frame count")
        expect(abs(timingPolicy.frameInterval(for: .turning, frameCount: 25) - 0.1296) < 0.0001, "turning interval should adapt to the denser frame count")
        expect(abs(timingPolicy.frameInterval(for: .glanceLeft, frameCount: 16) - 0.1) < 0.0001, "glance left should keep a readable 10 fps cadence")
        expect(abs(timingPolicy.frameInterval(for: .glanceRight, frameCount: 16) - 0.1) < 0.0001, "glance right should keep a readable 10 fps cadence")

        let motionPolicy = PetMotionPolicy()
        expect(!motionPolicy.loopsContinuously(animation: .idle), "idle should not loop continuously")
        expect(!motionPolicy.loopsContinuously(animation: .running), "running should not loop continuously in calm mode")
        expect(!motionPolicy.loopsContinuously(animation: .waiting), "waiting should not loop continuously")
        expect(!motionPolicy.loopsContinuously(animation: .failed), "failed should not loop continuously")

        let ambientPolicy = PetAmbientActionPolicy()
        expect(ambientPolicy.restingAnimation(for: .working) == .review, "working should rest in a focused pose")
        expect(ambientPolicy.restingAnimation(for: .waiting) == .waiting, "waiting should rest in a waiting pose")
        expect(ambientPolicy.restingAnimation(for: .offline) == .failed, "offline should rest in failed pose")
        expect(ambientPolicy.microActionSuites(for: .working) == [[.breathing], [.eyeShiftLeft], [.eyeShiftRight], [.tinyHandAdjust], [.hairSway]], "working should include subtle micro action suites")
        expect(ambientPolicy.microActionSuites(for: .waiting) == [[.breathing], [.weightShift], [.eyeShiftLeft], [.eyeShiftRight], [.shoulderRelax], [.tinyHandAdjust], [.hairSway]], "waiting should include idle micro action suites")
        expect(ambientPolicy.ambientSuites(for: .working) == [[.adjustGlasses], [.thinking], [.nod], [.tapKeyboard], [.checkNotes], [.stretchWrist]], "working should use focused short action suites")
        expect(ambientPolicy.ambientSuites(for: .waiting) == [[.waving], [.smallSmile], [.slowBlink]], "waiting should use calm visible action suites")
        expect(ambientPolicy.ambientSuites(for: .offline) == [], "offline should rest without extra ambient actions")
        expect(ambientPolicy.ambientAnimations(for: .waiting).contains(.waving), "waiting should include visible short actions")
        expect(!ambientPolicy.ambientAnimations(for: .waiting).contains(.turning), "waiting should avoid inconsistent turntable frames")
        expect(!ambientPolicy.largeActionSuites(for: .working).flatMap { $0 }.contains(.turning), "working should avoid full turntable in default large actions")
        expect(!ambientPolicy.largeActionSuites(for: .waiting).flatMap { $0 }.contains(.turning), "waiting should avoid full turntable in default large actions")
        expect(ambientPolicy.largeActionSuites(for: .working) == [[.glanceLeft], [.glanceRight], [.focusShift], [.fixPosture], [.postureReset], [.stretch]], "working large actions should include attention and posture clips")
        expect(ambientPolicy.largeActionSuites(for: .waiting) == [[.glanceLeft], [.glanceRight], [.adjustOutfit], [.lookAround], [.postureReset], [.stretch], [.stepAside]], "waiting large actions should include exploratory and reset clips")
        expect(ambientPolicy.largeActionSuites(for: .offline) == [], "offline should avoid large ambient actions")

        let catalog = PetActionCatalog()
        expect(catalog.descriptor(for: .blink)?.layer == .expression, "blink should be an expression action")
        expect(catalog.descriptor(for: .breathing)?.layer == .micro, "breathing should be a micro action")
        expect(catalog.descriptor(for: .adjustGlasses)?.layer == .small, "adjust glasses should be a small action")
        expect(catalog.descriptor(for: .focusShift)?.layer == .medium, "focus shift should be a medium action")
        expect(catalog.descriptor(for: .lookAround)?.layer == .large, "look around should be a large action")
        expect(catalog.descriptor(for: .stretch)?.layer == .large, "stretch should be a large action")
        expect(catalog.descriptor(for: .hoverSmile)?.layer == .interaction, "hover smile should be an interaction action")
        expect(catalog.descriptor(for: .turning)?.layer == .debug, "full turntable should only be a debug action")
        expect(catalog.animations(for: .working, layer: .micro).contains(.breathing), "working micro actions should include breathing")
        expect(catalog.animations(for: .waiting, layer: .micro).contains(.tinyHandAdjust), "waiting micro actions should include tiny hand adjustment")
        expect(catalog.animations(for: .working, layer: .small) == [.adjustGlasses, .thinking, .nod, .tapKeyboard, .checkNotes, .stretchWrist], "working small actions should express focused work")
        expect(catalog.animations(for: .waiting, layer: .expression).contains(.slowBlink), "waiting expression actions should include slow blink")
        expect(catalog.animations(for: .waiting, layer: .large).contains(.stepAside), "waiting large action catalog should include step aside")
        expect(!catalog.animations(for: .waiting, layer: .large).contains(.turning), "default large action catalog should exclude full turntable")

        let timeline = PetActionTimeline()
        let busyState = PetActionTimelineState(
            currentStatus: .waiting,
            currentLayer: .small,
            currentPriority: .p2,
            reservedUntil: now.addingTimeInterval(1.0),
            isDragging: false,
            isHovering: false,
            lastStatusChangeAt: now.addingTimeInterval(-30),
            lastInteractionAt: now.addingTimeInterval(-30)
        )
        let queuedSmall = timeline.decide(
            request: PetActionRequest(animation: .waving, sourceStatus: .waiting, submittedAt: now),
            state: busyState
        )
        expect(queuedSmall.outcome == .queue, "small actions may queue behind another small action")

        let droppedLarge = timeline.decide(
            request: PetActionRequest(animation: .lookAround, sourceStatus: .waiting, submittedAt: now),
            state: busyState
        )
        expect(droppedLarge.outcome == .drop, "large actions should drop when the timeline is busy")

        let hoverInterrupt = timeline.decide(
            request: PetActionRequest(animation: .cursorLook, sourceStatus: .waiting, submittedAt: now),
            state: busyState
        )
        expect(hoverInterrupt.outcome == .playNow, "interaction actions should interrupt ambient actions")

        let microBusyState = PetActionTimelineState(
            currentStatus: .waiting,
            currentLayer: .micro,
            currentPriority: .p3,
            reservedUntil: now.addingTimeInterval(1.0),
            isDragging: false,
            isHovering: false,
            lastStatusChangeAt: now.addingTimeInterval(-30),
            lastInteractionAt: now.addingTimeInterval(-30)
        )
        let smallInterruptsMicro = timeline.decide(
            request: PetActionRequest(animation: .waving, sourceStatus: .waiting, submittedAt: now),
            state: microBusyState
        )
        expect(smallInterruptsMicro.outcome == .playNow, "larger visible actions should interrupt micro actions")

        let draggingState = PetActionTimelineState(
            currentStatus: .waiting,
            currentLayer: nil,
            currentPriority: nil,
            reservedUntil: nil,
            isDragging: true,
            isHovering: false,
            lastStatusChangeAt: now.addingTimeInterval(-30),
            lastInteractionAt: now
        )
        let blockedDuringDrag = timeline.decide(
            request: PetActionRequest(animation: .blink, sourceStatus: .waiting, submittedAt: now),
            state: draggingState
        )
        expect(blockedDuringDrag.outcome == .drop, "drag should suppress non-P0 actions")

        let staleStatus = timeline.decide(
            request: PetActionRequest(animation: .waving, sourceStatus: .waiting, submittedAt: now),
            state: PetActionTimelineState(
                currentStatus: .working,
                currentLayer: nil,
                currentPriority: nil,
                reservedUntil: nil,
                isDragging: false,
                isHovering: false,
                lastStatusChangeAt: now,
                lastInteractionAt: now.addingTimeInterval(-30)
            )
        )
        expect(staleStatus.outcome == .drop, "actions from an old status should be dropped")

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
