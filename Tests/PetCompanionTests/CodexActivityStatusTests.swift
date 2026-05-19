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
        #expect(framePolicy.frameCount(for: .glanceLeft) == 16)
        #expect(framePolicy.frameCount(for: .glanceRight) == 16)
        #expect(framePolicy.frameCount(for: .blink) == 5)
        #expect(framePolicy.frameCount(for: .slowBlink) == 8)
        #expect(framePolicy.frameCount(for: .eyeShiftLeft) == 8)
        #expect(framePolicy.frameCount(for: .breathing) == 12)
        #expect(framePolicy.frameCount(for: .weightShift) == 16)
        #expect(framePolicy.frameCount(for: .adjustGlasses) == 24)
        #expect(framePolicy.frameCount(for: .tapKeyboard) == 24)
        #expect(framePolicy.frameCount(for: .focusShift) == 24)
        #expect(framePolicy.frameCount(for: .lookAround) == 32)
        #expect(framePolicy.frameCount(for: .stretch) == 32)
    }

    @Test("Animation timing adapts to frame count")
    func animationTimingAdaptsToFrameCount() {
        let timingPolicy = PetAnimationTimingPolicy()

        #expect(timingPolicy.totalDuration(for: .running) == 2.4)
        #expect(timingPolicy.totalDuration(for: .waving) == 2.4)
        #expect(timingPolicy.totalDuration(for: .turning) == 3.24)
        #expect(timingPolicy.totalDuration(for: .glanceLeft) == 1.6)
        #expect(timingPolicy.totalDuration(for: .glanceRight) == 1.6)
        #expect(timingPolicy.totalDuration(for: .blink) == 0.25)
        #expect(timingPolicy.totalDuration(for: .slowBlink) == 0.7)
        #expect(timingPolicy.totalDuration(for: .eyeShiftLeft) == 0.8)
        #expect(timingPolicy.totalDuration(for: .breathing) == 1.2)
        #expect(timingPolicy.totalDuration(for: .weightShift) == 1.6)
        #expect(timingPolicy.totalDuration(for: .tapKeyboard) == 2.4)
        #expect(timingPolicy.totalDuration(for: .lookAround) == 3.2)
        #expect(timingPolicy.totalDuration(for: .stretch) == 3.6)
        #expect(abs(timingPolicy.frameInterval(for: .running, frameCount: 24) - 0.1) < 0.0001)
        #expect(abs(timingPolicy.frameInterval(for: .turning, frameCount: 25) - 0.1296) < 0.0001)
        #expect(abs(timingPolicy.frameInterval(for: .glanceLeft, frameCount: 16) - 0.1) < 0.0001)
        #expect(abs(timingPolicy.frameInterval(for: .glanceRight, frameCount: 16) - 0.1) < 0.0001)
    }

    @Test("Default large ambient actions use glance clips")
    func defaultLargeAmbientActionsUseGlanceClips() {
        let ambientPolicy = PetAmbientActionPolicy()

        #expect(!ambientPolicy.largeActionSuites(for: .working).flatMap { $0 }.contains(.turning))
        #expect(!ambientPolicy.largeActionSuites(for: .waiting).flatMap { $0 }.contains(.turning))
        #expect(ambientPolicy.microActionSuites(for: .working) == [[.breathing], [.eyeShiftLeft], [.eyeShiftRight], [.tinyHandAdjust], [.hairSway]])
        #expect(ambientPolicy.microActionSuites(for: .waiting) == [[.breathing], [.weightShift], [.eyeShiftLeft], [.eyeShiftRight], [.shoulderRelax], [.tinyHandAdjust], [.hairSway]])
        #expect(ambientPolicy.largeActionSuites(for: .working) == [[.glanceLeft], [.glanceRight], [.focusShift], [.fixPosture], [.postureReset], [.stretch]])
        #expect(ambientPolicy.largeActionSuites(for: .waiting) == [[.glanceLeft], [.glanceRight], [.adjustOutfit], [.lookAround], [.postureReset], [.stretch], [.stepAside]])
    }

    @Test("Action catalog classifies action layers")
    func actionCatalogClassifiesActionLayers() {
        let catalog = PetActionCatalog()

        #expect(catalog.descriptor(for: .blink)?.layer == .expression)
        #expect(catalog.descriptor(for: .breathing)?.layer == .micro)
        #expect(catalog.descriptor(for: .adjustGlasses)?.layer == .small)
        #expect(catalog.descriptor(for: .focusShift)?.layer == .medium)
        #expect(catalog.descriptor(for: .lookAround)?.layer == .large)
        #expect(catalog.descriptor(for: .stretch)?.layer == .large)
        #expect(catalog.descriptor(for: .hoverSmile)?.layer == .interaction)
        #expect(catalog.descriptor(for: .turning)?.layer == .debug)
        #expect(catalog.animations(for: .working, layer: .micro).contains(.breathing))
        #expect(catalog.animations(for: .waiting, layer: .micro).contains(.tinyHandAdjust))
        #expect(catalog.animations(for: .working, layer: .small) == [.adjustGlasses, .thinking, .nod, .tapKeyboard, .checkNotes, .stretchWrist])
        #expect(catalog.animations(for: .waiting, layer: .expression).contains(.slowBlink))
        #expect(catalog.animations(for: .waiting, layer: .large).contains(.stepAside))
        #expect(!catalog.animations(for: .waiting, layer: .large).contains(.turning))
    }

    @Test("Action timeline resolves conflicts")
    func actionTimelineResolvesConflicts() {
        let now = Date(timeIntervalSince1970: 1_000)
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

        #expect(timeline.decide(
            request: PetActionRequest(animation: .waving, sourceStatus: .waiting, submittedAt: now),
            state: busyState
        ).outcome == .queue)
        #expect(timeline.decide(
            request: PetActionRequest(animation: .lookAround, sourceStatus: .waiting, submittedAt: now),
            state: busyState
        ).outcome == .drop)
        #expect(timeline.decide(
            request: PetActionRequest(animation: .cursorLook, sourceStatus: .waiting, submittedAt: now),
            state: busyState
        ).outcome == .playNow)

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
        #expect(timeline.decide(
            request: PetActionRequest(animation: .waving, sourceStatus: .waiting, submittedAt: now),
            state: microBusyState
        ).outcome == .playNow)
    }
}
