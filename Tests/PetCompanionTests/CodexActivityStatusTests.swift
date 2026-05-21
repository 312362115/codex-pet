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

    @Test("Pet catalog selects behavior profiles")
    func petCatalogSelectsBehaviorProfiles() {
        let catalog = PetCatalog()

        #expect(catalog.defaultPet.id == "lingxi-ol")
        #expect(catalog.defaultPet.behaviorProfile == .officeCompanion)
        #expect(catalog.pet(withID: "maneki-neko")?.displayName == "招财猫")
        #expect(catalog.pet(withID: "maneki-neko")?.behaviorProfile == .manekiNeko)
        #expect(catalog.selectedPet(for: "missing").id == "lingxi-ol")
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
        #expect(timingPolicy.totalDuration(for: .hairSway) == 1.2)
        #expect(timingPolicy.totalDuration(for: .weightShift) == 1.6)
        #expect(timingPolicy.totalDuration(for: .shoulderRelax) == 1.6)
        #expect(timingPolicy.totalDuration(for: .cursorLook) == 1.6)
        #expect(timingPolicy.totalDuration(for: .dragReleaseSettle) == 1.0)
        #expect(timingPolicy.totalDuration(for: .wakeUp) == 2.0)
        #expect(timingPolicy.totalDuration(for: .tapKeyboard) == 2.4)
        #expect(timingPolicy.totalDuration(for: .lookAround) == 3.2)
        #expect(timingPolicy.totalDuration(for: .stretch) == 3.6)
        #expect(abs(timingPolicy.frameInterval(for: .running, frameCount: 24) - 0.1) < 0.0001)
        #expect(abs(timingPolicy.frameInterval(for: .turning, frameCount: 25) - 0.1296) < 0.0001)
        #expect(abs(timingPolicy.frameInterval(for: .glanceLeft, frameCount: 16) - 0.1) < 0.0001)
        #expect(abs(timingPolicy.frameInterval(for: .glanceRight, frameCount: 16) - 0.1) < 0.0001)
    }

    @Test("Safe body micro motions use SpriteKit rig")
    func safeBodyMicroMotionsUseSpriteKitRig() {
        let renderModePolicy = PetRenderModePolicy()

        #expect(renderModePolicy.renderMode(for: .breathing) == .spriteKitRigMotion)
        #expect(renderModePolicy.renderMode(for: .blink) == .frameClip)
        #expect(renderModePolicy.renderMode(for: .slowBlink) == .frameClip)
        #expect(renderModePolicy.renderMode(for: .weightShift) == .spriteKitRigMotion)
        #expect(renderModePolicy.renderMode(for: .shoulderRelax) == .spriteKitRigMotion)
        #expect(renderModePolicy.renderMode(for: .cursorLook) == .spriteKitRigMotion)
        #expect(renderModePolicy.renderMode(for: .hairSway) == .spriteKitRigMotion)
        #expect(renderModePolicy.renderMode(for: .dragReleaseSettle) == .spriteKitRigMotion)
        #expect(renderModePolicy.renderMode(for: .wakeUp) == .spriteKitRigMotion)
    }

    @Test("Default large ambient actions use glance clips")
    func defaultLargeAmbientActionsUseGlanceClips() {
        let ambientPolicy = PetAmbientActionPolicy()

        #expect(!ambientPolicy.largeActionSuites(for: .working).flatMap { $0 }.contains(.turning))
        #expect(!ambientPolicy.largeActionSuites(for: .waiting).flatMap { $0 }.contains(.turning))
        #expect(ambientPolicy.restingAnimation(for: .idleRelaxed) == .idle)
        #expect(ambientPolicy.restingAnimation(for: .toolRunning) == .tapKeyboard)
        #expect(ambientPolicy.restingAnimation(for: .completedCalm) == .nod)
        #expect(ambientPolicy.restingFrameIndex(for: .toolRunning, frameCount: 24) > 0)
        #expect(ambientPolicy.restingFrameIndex(for: .completedCalm, frameCount: 16) > 0)
        #expect(ambientPolicy.microActionSuites(for: .working) == [[.breathing], [.tinyHandAdjust], [.hairSway]])
        #expect(ambientPolicy.microActionSuites(for: .waiting) == [[.breathing], [.weightShift], [.shoulderRelax], [.tinyHandAdjust], [.hairSway]])
        #expect(ambientPolicy.microActionSuites(for: .idleRelaxed).contains([.weightShift]))
        #expect(ambientPolicy.largeActionSuites(for: .working) == [[.glanceLeft], [.glanceRight], [.focusShift], [.fixPosture], [.postureReset], [.stretch]])
        #expect(ambientPolicy.largeActionSuites(for: .waiting) == [[.glanceLeft], [.glanceRight], [.adjustOutfit], [.lookAround], [.fixPosture], [.stepAside], [.postureReset], [.stretch]])
        let waitingVisibleActions = Set(
            ambientPolicy.smallActionSuites(for: .waitingAttentive).flatMap { $0 }
                + ambientPolicy.largeActionSuites(for: .waitingAttentive).flatMap { $0 }
        )
        #expect([.cursorLook, .waving, .nod, .tinyHandAdjust, .adjustOutfit, .glanceLeft, .glanceRight, .lookAround, .fixPosture, .stepAside, .postureReset, .stretch].allSatisfy(waitingVisibleActions.contains))
        #expect(ambientPolicy.smallActionSuites(for: .toolRunning) == [[.tapKeyboard], [.checkNotes], [.focusShift]])
        #expect(ambientPolicy.smallActionSuites(for: .waiting) == [[.cursorLook], [.waving], [.nod], [.tinyHandAdjust], [.adjustOutfit]])
        #expect(ambientPolicy.smallActionSuites(for: .idleRelaxed) == [[.waving], [.nod], [.cursorLook], [.tinyHandAdjust], [.adjustOutfit]])
        #expect(ambientPolicy.hoverActionSuites(for: .working) == [[.adjustGlasses], [.thinking]])
        #expect(ambientPolicy.hoverActionSuites(for: .waiting) == [[.cursorLook], [.waving]])
        #expect(ambientPolicy.hoverActionSuites(for: .toolRunning) == [[.tapKeyboard], [.focusShift], [.checkNotes]])
        #expect(ambientPolicy.largeActionSuites(for: .longWorkTired) == [[.stretch], [.postureReset]])
    }

    @Test("Scheduler intervals surface more generated actions")
    func schedulerIntervalsSurfaceMoreGeneratedActions() {
        let schedulerIntervalPolicy = PetActionSchedulerIntervalPolicy()

        #expect(schedulerIntervalPolicy.microActionIntervalRange(for: .waitingAttentive, initialDelay: true) == PetSchedulerIntervalRange(10, 16))
        #expect(schedulerIntervalPolicy.smallActionIntervalRange(for: .waitingAttentive, initialDelay: true) == PetSchedulerIntervalRange(24, 36))
        #expect(schedulerIntervalPolicy.largeActionIntervalRange(for: .waitingAttentive, initialDelay: true) == PetSchedulerIntervalRange(75, 110))
        #expect(schedulerIntervalPolicy.microActionIntervalRange(for: .waitingAttentive, initialDelay: false) == PetSchedulerIntervalRange(28, 46))
        #expect(schedulerIntervalPolicy.smallActionIntervalRange(for: .waitingAttentive, initialDelay: false) == PetSchedulerIntervalRange(55, 90))
        #expect(schedulerIntervalPolicy.largeActionIntervalRange(for: .idleRelaxed, initialDelay: false) == PetSchedulerIntervalRange(150, 240))
        #expect(schedulerIntervalPolicy.largeActionIntervalRange(for: .reviewFocused, initialDelay: false) == PetSchedulerIntervalRange(180, 300))
    }

    @Test("Maneki Neko profile uses lucky cat scheduling")
    func manekiNekoProfileUsesLuckyCatScheduling() {
        let ambientPolicy = PetAmbientActionPolicy(profile: .manekiNeko)
        let schedulerIntervalPolicy = PetActionSchedulerIntervalPolicy(profile: .manekiNeko)

        #expect(ambientPolicy.restingAnimation(for: .toolRunning) == .waiting)
        #expect(ambientPolicy.microActionSuites(for: .waitingAttentive) == [[.hairSway], [.breathing], [.slowBlink]])
        #expect(ambientPolicy.smallActionSuites(for: .waitingAttentive) == [[.waving], [.waving], [.cursorLook], [.nod]])
        #expect(ambientPolicy.largeActionSuites(for: .waitingAttentive) == [[.lookAround], [.glanceLeft], [.glanceRight]])
        #expect(ambientPolicy.hoverActionSuites(for: .waitingAttentive) == [[.waving], [.cursorLook], [.hairSway], [.slowBlink]])

        #expect(schedulerIntervalPolicy.microActionIntervalRange(for: .waitingAttentive, initialDelay: true) == PetSchedulerIntervalRange(2, 4))
        #expect(schedulerIntervalPolicy.smallActionIntervalRange(for: .waitingAttentive, initialDelay: true) == PetSchedulerIntervalRange(3, 6))
        #expect(schedulerIntervalPolicy.largeActionIntervalRange(for: .waitingAttentive, initialDelay: true) == PetSchedulerIntervalRange(8, 14))
        #expect(schedulerIntervalPolicy.smallActionIntervalRange(for: .waitingAttentive, initialDelay: false) == PetSchedulerIntervalRange(12, 22))
    }

    @Test("Action catalog classifies action layers")
    func actionCatalogClassifiesActionLayers() {
        let catalog = PetActionCatalog()

        #expect(catalog.descriptor(for: .blink)?.layer == .expression)
        #expect(catalog.descriptor(for: .blink)?.defaultEligible == false)
        #expect(catalog.descriptor(for: .slowBlink)?.defaultEligible == false)
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
        #expect(catalog.animations(for: .working, layer: .expression).isEmpty)
        #expect(catalog.animations(for: .offline, layer: .expression).isEmpty)
        #expect(catalog.animations(for: .waiting, layer: .large).contains(.stepAside))
        #expect(!catalog.animations(for: .waiting, layer: .large).contains(.turning))

        let disabledFaceOverlayActions: [PetAnimation] = [
            .blink, .slowBlink, .eyeShiftLeft, .eyeShiftRight, .focusTighten,
            .relaxFace, .smallSmile, .tiredSoften, .curiousLook, .hoverSmile, .contextMenuAttend
        ]
        for animation in disabledFaceOverlayActions {
            #expect(catalog.descriptor(for: animation)?.defaultEligible == false)
        }

        let defaultScheduledActions = [
            CodexActivityStatus.offline, .working, .waiting
        ].flatMap { status in
            [
                catalog.animations(for: status, layer: .pose),
                catalog.animations(for: status, layer: .micro),
                catalog.animations(for: status, layer: .small),
                catalog.animations(for: status, layer: .medium),
                catalog.animations(for: status, layer: .large),
                catalog.animations(for: status, layer: .interaction)
            ].flatMap { $0 }
        }
        for animation in defaultScheduledActions {
            #expect(catalog.descriptor(for: animation)?.expressions.isEmpty == false)
        }
    }

    @Test("Default window placement starts at bottom left")
    func defaultWindowPlacementStartsAtBottomLeft() {
        let windowPlacementPolicy = PetWindowPlacementPolicy()
        let origin = windowPlacementPolicy.initialOrigin(
            visibleFrame: PetWindowPlacementRect(x: 100, y: 40, width: 1440, height: 900),
            windowSize: PetWindowPlacementSize(width: 576, height: 672)
        )

        #expect(origin == PetWindowPlacementPoint(x: 124, y: 64))
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

        let runtimeSchedulingPolicy = PetRuntimeSchedulingPolicy()
        #expect(runtimeSchedulingPolicy.hoverBeginDecision(activeSchedulerKind: .small, activeActionLayer: .small) == .startHoverInteraction)
        #expect(runtimeSchedulingPolicy.hoverBeginDecision(activeSchedulerKind: .large, activeActionLayer: .large) == .startHoverInteraction)
        #expect(runtimeSchedulingPolicy.hoverBeginDecision(activeSchedulerKind: .interaction, activeActionLayer: .interaction) == .deferToActiveInteraction)
        #expect(runtimeSchedulingPolicy.shouldScheduleAmbientActions(
            isDragging: false,
            isHovering: false,
            hasActiveAction: true,
            hasValidAmbientTimer: false
        ) == false)
        #expect(runtimeSchedulingPolicy.shouldScheduleAmbientActions(
            isDragging: false,
            isHovering: false,
            hasActiveAction: false,
            hasValidAmbientTimer: false
        ))
    }
}
