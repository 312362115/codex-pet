import Foundation
import Testing
@testable import PetCompanion

@Suite("Codex activity classification")
struct CodexActivityStatusTests {
    private let classifier = CodexActivityClassifier()
    private let phaseClassifier = CodexWorkPhaseClassifier()
    private let transitionPolicy = PetPresentationTransitionPolicy()
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

    @Test("Metadata maps to work phases and presentation states")
    func metadataMapsToWorkPhasesAndPresentationStates() {
        #expect(phaseClassifier.classify(CodexMetadataSnapshot(
            codexIsRunning: false,
            latestActivityDate: now,
            now: now
        )) == .offline)
        #expect(phaseClassifier.classify(CodexMetadataSnapshot(
            codexIsRunning: true,
            latestActivityDate: now,
            hasRecentError: true,
            now: now
        )) == .blocked)
        #expect(phaseClassifier.classify(CodexMetadataSnapshot(
            codexIsRunning: true,
            latestActivityDate: now,
            continuousActiveDuration: 60 * 60,
            now: now
        )) == .longWorking)
        #expect(phaseClassifier.classify(CodexMetadataSnapshot(
            codexIsRunning: true,
            latestActivityDate: now,
            hasRunningJob: true,
            now: now
        )) == .runningTool)
        #expect(phaseClassifier.classify(CodexMetadataSnapshot(
            codexIsRunning: true,
            latestActivityDate: now,
            hasRecentToolEvent: true,
            now: now
        )) == .runningTool)
        #expect(phaseClassifier.classify(CodexMetadataSnapshot(
            codexIsRunning: true,
            latestActivityDate: now.addingTimeInterval(-30),
            hasRecentCompletedJob: true,
            now: now
        )) == .completed)
        #expect(phaseClassifier.classify(CodexMetadataSnapshot(
            codexIsRunning: true,
            latestActivityDate: now.addingTimeInterval(-3),
            activeThreadUpdatedAt: now.addingTimeInterval(-3),
            now: now
        )) == .thinking)
        #expect(phaseClassifier.classify(CodexMetadataSnapshot(
            codexIsRunning: true,
            latestActivityDate: now.addingTimeInterval(-3),
            activeThreadUpdatedAt: now.addingTimeInterval(-30),
            now: now
        )) == .thinking)
        #expect(phaseClassifier.classify(CodexMetadataSnapshot(
            codexIsRunning: true,
            latestActivityDate: now.addingTimeInterval(-30),
            activeThreadUpdatedAt: now.addingTimeInterval(-30),
            now: now,
            activeThreshold: 8,
            waitingThreshold: 90
        )) == .waitingUser)
        #expect(CodexWorkPhase.runningTool.presentationState == .toolRunning)
        #expect(PetPresentationState.toolRunning.coarseStatus == .working)
    }

    @Test("Presentation transitions are debounced")
    func presentationTransitionsAreDebounced() {
        #expect(!transitionPolicy.canSwitch(
            from: .toolRunning,
            currentStateSince: now.addingTimeInterval(-3),
            to: .reviewFocused,
            candidateStateSince: now.addingTimeInterval(-3),
            now: now
        ))
        #expect(!transitionPolicy.canSwitch(
            from: .reviewFocused,
            currentStateSince: now.addingTimeInterval(-20),
            to: .waitingAttentive,
            candidateStateSince: now.addingTimeInterval(-2),
            now: now
        ))
        #expect(transitionPolicy.canSwitch(
            from: .reviewFocused,
            currentStateSince: now.addingTimeInterval(-20),
            to: .waitingAttentive,
            candidateStateSince: now.addingTimeInterval(-6),
            now: now
        ))
        #expect(transitionPolicy.canSwitch(
            from: .toolRunning,
            currentStateSince: now,
            to: .blockedConcerned,
            candidateStateSince: now,
            now: now
        ))
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
        #expect(ambientPolicy.restingAnimation(for: .toolRunning) == .tapKeyboard)
        #expect(ambientPolicy.restingAnimation(for: .completedCalm) == .nod)
        #expect(ambientPolicy.restingFrameIndex(for: .toolRunning, frameCount: 24) > 0)
        #expect(ambientPolicy.restingFrameIndex(for: .completedCalm, frameCount: 16) > 0)
        #expect(ambientPolicy.microActionSuites(for: .working) == [[.breathing], [.tinyHandAdjust], [.hairSway]])
        #expect(ambientPolicy.microActionSuites(for: .waiting) == [[.breathing], [.tinyHandAdjust], [.hairSway]])
        #expect(ambientPolicy.microActionSuites(for: .idleRelaxed).contains([.weightShift]))
        #expect(ambientPolicy.largeActionSuites(for: .working) == [[.glanceLeft], [.glanceRight], [.focusShift], [.fixPosture], [.postureReset]])
        #expect(ambientPolicy.largeActionSuites(for: .waiting) == [[.glanceLeft], [.glanceRight], [.adjustOutfit], [.lookAround]])
        #expect(ambientPolicy.smallActionSuites(for: .toolRunning) == [[.tapKeyboard], [.checkNotes], [.focusShift]])
        #expect(ambientPolicy.smallActionSuites(for: .waiting) == [[.cursorLook], [.waving]])
        #expect(ambientPolicy.hoverActionSuites(for: .working) == [[.adjustGlasses], [.thinking]])
        #expect(ambientPolicy.hoverActionSuites(for: .waiting) == [[.cursorLook], [.waving]])
        #expect(ambientPolicy.hoverActionSuites(for: .toolRunning) == [[.tapKeyboard], [.focusShift], [.checkNotes]])
        #expect(ambientPolicy.largeActionSuites(for: .longWorkTired) == [[.stretch], [.postureReset]])
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
        #expect(catalog.animations(for: .waiting, layer: .expression).isEmpty)
        #expect(catalog.animations(for: .waiting, layer: .large).contains(.stepAside))
        #expect(!catalog.animations(for: .waiting, layer: .large).contains(.turning))
    }

    @Test("Action timeline resolves conflicts")
    func actionTimelineResolvesConflicts() {
        let now = Date(timeIntervalSince1970: 1_000)
        let timeline = PetActionTimeline()
        let busyState = PetActionTimelineState(
            currentPresentationState: .waitingAttentive,
            currentLayer: .small,
            currentPriority: .p2,
            reservedUntil: now.addingTimeInterval(1.0),
            isDragging: false,
            isHovering: false,
            lastStatusChangeAt: now.addingTimeInterval(-30),
            lastInteractionAt: now.addingTimeInterval(-30)
        )

        #expect(timeline.decide(
            request: PetActionRequest(animation: .waving, sourcePresentationState: .waitingAttentive, submittedAt: now),
            state: busyState
        ).outcome == .queue)
        #expect(timeline.decide(
            request: PetActionRequest(animation: .lookAround, sourcePresentationState: .waitingAttentive, submittedAt: now),
            state: busyState
        ).outcome == .drop)
        #expect(timeline.decide(
            request: PetActionRequest(animation: .cursorLook, sourcePresentationState: .waitingAttentive, submittedAt: now),
            state: busyState
        ).outcome == .playNow)

        let microBusyState = PetActionTimelineState(
            currentPresentationState: .waitingAttentive,
            currentLayer: .micro,
            currentPriority: .p3,
            reservedUntil: now.addingTimeInterval(1.0),
            isDragging: false,
            isHovering: false,
            lastStatusChangeAt: now.addingTimeInterval(-30),
            lastInteractionAt: now.addingTimeInterval(-30)
        )
        #expect(timeline.decide(
            request: PetActionRequest(animation: .waving, sourcePresentationState: .waitingAttentive, submittedAt: now),
            state: microBusyState
        ).outcome == .playNow)
    }
}
