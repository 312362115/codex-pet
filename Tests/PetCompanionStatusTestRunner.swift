import Foundation

@main
struct StatusTestRunner {
    static func main() {
        let classifier = CodexActivityClassifier()
        let phaseClassifier = CodexWorkPhaseClassifier()
        let transitionPolicy = PetPresentationTransitionPolicy()
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

        let petCatalog = PetCatalog()
        expect(petCatalog.defaultPet.id == "lingxi-ol", "Lingxi OL should remain the default pet")
        expect(petCatalog.pets.map(\.id) == ["lingxi-ol", "maneki-neko"], "catalog should expose selectable pets in menu order")
        expect(petCatalog.pet(withID: "maneki-neko")?.displayName == "招财猫", "catalog should include the Maneki Neko pet")
        expect(petCatalog.defaultPet.behaviorProfile == .officeCompanion, "Lingxi OL should use the office companion behavior profile")
        expect(petCatalog.pet(withID: "maneki-neko")?.behaviorProfile == .manekiNeko, "Maneki Neko should switch to the lucky cat behavior profile")
        expect(petCatalog.selectedPet(for: "missing").id == "lingxi-ol", "unknown persisted pet ids should fall back to the default pet")

        expect(phaseClassifier.classify(CodexMetadataSnapshot(
            codexIsRunning: false,
            latestActivityDate: now,
            now: now
        )) == .offline, "metadata phase should be offline when Codex is not running")
        expect(phaseClassifier.classify(CodexMetadataSnapshot(
            codexIsRunning: true,
            latestActivityDate: now,
            hasRecentError: true,
            now: now
        )) == .blocked, "recent errors should map to blocked phase")
        expect(phaseClassifier.classify(CodexMetadataSnapshot(
            codexIsRunning: true,
            latestActivityDate: now,
            continuousActiveDuration: 60 * 60,
            now: now
        )) == .longWorking, "long active sessions should map to long working phase")
        expect(phaseClassifier.classify(CodexMetadataSnapshot(
            codexIsRunning: true,
            latestActivityDate: now,
            hasRunningJob: true,
            now: now
        )) == .runningTool, "running jobs should map to tool-running phase")
        expect(phaseClassifier.classify(CodexMetadataSnapshot(
            codexIsRunning: true,
            latestActivityDate: now,
            hasRecentToolEvent: true,
            now: now
        )) == .runningTool, "recent tool log metadata should map to tool-running phase")
        expect(phaseClassifier.classify(CodexMetadataSnapshot(
            codexIsRunning: true,
            latestActivityDate: now.addingTimeInterval(-30),
            hasRecentCompletedJob: true,
            now: now
        )) == .completed, "recent completed jobs should map to completed phase")
        expect(phaseClassifier.classify(CodexMetadataSnapshot(
            codexIsRunning: true,
            latestActivityDate: now.addingTimeInterval(-3),
            activeThreadUpdatedAt: now.addingTimeInterval(-3),
            now: now
        )) == .thinking, "recent thread activity should map to thinking phase")
        expect(phaseClassifier.classify(CodexMetadataSnapshot(
            codexIsRunning: true,
            latestActivityDate: now.addingTimeInterval(-3),
            activeThreadUpdatedAt: now.addingTimeInterval(-30),
            now: now
        )) == .thinking, "fresh log metadata should keep the active thread in thinking phase")
        expect(phaseClassifier.classify(CodexMetadataSnapshot(
            codexIsRunning: true,
            latestActivityDate: now.addingTimeInterval(-30),
            activeThreadUpdatedAt: now.addingTimeInterval(-30),
            now: now,
            activeThreshold: 8,
            waitingThreshold: 90
        )) == .waitingUser, "recent but inactive thread should wait for user")
        expect(phaseClassifier.classify(CodexMetadataSnapshot(
            codexIsRunning: true,
            latestActivityDate: now.addingTimeInterval(-200),
            activeThreadUpdatedAt: now.addingTimeInterval(-200),
            now: now,
            waitingThreshold: 90
        )) == .idle, "stale metadata should map to idle")
        expect(CodexWorkPhase.runningTool.presentationState == .toolRunning, "running tool phase should settle into tool-running presentation")
        expect(CodexWorkPhase.waitingUser.presentationState == .waitingAttentive, "waiting user phase should settle into attentive waiting")
        expect(PetPresentationState.toolRunning.coarseStatus == .working, "tool-running presentation should keep working compatibility")
        expect(!transitionPolicy.canSwitch(
            from: .toolRunning,
            currentStateSince: now.addingTimeInterval(-3),
            to: .reviewFocused,
            candidateStateSince: now.addingTimeInterval(-3),
            now: now
        ), "tool-running should not be replaced before the minimum dwell")
        expect(!transitionPolicy.canSwitch(
            from: .reviewFocused,
            currentStateSince: now.addingTimeInterval(-20),
            to: .waitingAttentive,
            candidateStateSince: now.addingTimeInterval(-2),
            now: now
        ), "waiting should be confirmed before interrupting a focused state")
        expect(transitionPolicy.canSwitch(
            from: .reviewFocused,
            currentStateSince: now.addingTimeInterval(-20),
            to: .waitingAttentive,
            candidateStateSince: now.addingTimeInterval(-6),
            now: now
        ), "confirmed waiting should switch after focused dwell")
        expect(transitionPolicy.canSwitch(
            from: .toolRunning,
            currentStateSince: now,
            to: .blockedConcerned,
            candidateStateSince: now,
            now: now
        ), "blocked state should remain urgent")

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
        expect(timingPolicy.totalDuration(for: .hairSway) == 1.2, "hair sway proxy should stay subtle")
        expect(timingPolicy.totalDuration(for: .weightShift) == 1.6, "micro shifts should stay short")
        expect(timingPolicy.totalDuration(for: .shoulderRelax) == 1.6, "shoulder relax should stay short")
        expect(timingPolicy.totalDuration(for: .cursorLook) == 1.6, "cursor look should stay short")
        expect(timingPolicy.totalDuration(for: .dragReleaseSettle) == 1.0, "drag release settle should be a quick recovery")
        expect(timingPolicy.totalDuration(for: .wakeUp) == 2.0, "wake up should be readable but not slow")
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

        let renderModePolicy = PetRenderModePolicy()
        expect(renderModePolicy.renderMode(for: .breathing) == .spriteKitRigMotion, "breathing should use the SpriteKit rig")
        expect(renderModePolicy.renderMode(for: .weightShift) == .spriteKitRigMotion, "weight shift should use the SpriteKit rig body layer")
        expect(renderModePolicy.renderMode(for: .shoulderRelax) == .spriteKitRigMotion, "shoulder relax should use the SpriteKit rig body layer")
        expect(renderModePolicy.renderMode(for: .hairSway) == .spriteKitRigMotion, "hair sway should use the SpriteKit head proxy until hair parts are clean")
        expect(renderModePolicy.renderMode(for: .blink) == .frameClip, "blink should not use rig until it is regenerated as an integrated full-action expression")
        expect(renderModePolicy.renderMode(for: .slowBlink) == .frameClip, "slow blink should remain a full-frame PNG clip")
        expect(renderModePolicy.renderMode(for: .eyeShiftLeft) == .frameClip, "left eye shift should use PNG until face rig assets are clean")
        expect(renderModePolicy.renderMode(for: .eyeShiftRight) == .frameClip, "right eye shift should use PNG until face rig assets are clean")
        expect(renderModePolicy.renderMode(for: .cursorLook) == .spriteKitRigMotion, "cursor look should use the SpriteKit head layer")
        expect(renderModePolicy.renderMode(for: .dragReleaseSettle) == .spriteKitRigMotion, "drag release settle should use the SpriteKit body layer")
        expect(renderModePolicy.renderMode(for: .wakeUp) == .spriteKitRigMotion, "wake up should use the SpriteKit body layer")
        expect(renderModePolicy.renderMode(for: .waving) == .frameClip, "waving should remain a PNG frame clip")
        expect(renderModePolicy.renderMode(for: .turning) == .frameClip, "turning should remain a PNG frame clip")
        expect(renderModePolicy.renderMode(for: .tapKeyboard) == .frameClip, "tap keyboard should remain a PNG frame clip")
        expect(renderModePolicy.renderMode(for: .stretch) == .frameClip, "stretch should remain a PNG frame clip")
        expect(renderModePolicy.usesSpriteKitRig(.breathing), "breathing should report rig usage")
        expect(!renderModePolicy.usesSpriteKitRig(.blink), "blink should not report rig usage")
        expect(!renderModePolicy.usesSpriteKitRig(.slowBlink), "slow blink should not report rig usage")
        expect(renderModePolicy.usesSpriteKitRig(.weightShift), "weight shift should report rig usage")
        expect(renderModePolicy.usesSpriteKitRig(.shoulderRelax), "shoulder relax should report rig usage")
        expect(renderModePolicy.usesSpriteKitRig(.cursorLook), "cursor look should report rig usage")
        expect(renderModePolicy.usesSpriteKitRig(.hairSway), "hair sway should report rig usage as a head proxy")
        expect(renderModePolicy.usesSpriteKitRig(.dragReleaseSettle), "drag release settle should report rig usage")
        expect(renderModePolicy.usesSpriteKitRig(.wakeUp), "wake up should report rig usage")
        expect(!renderModePolicy.usesSpriteKitRig(.waving), "waving should not report rig usage")

        let ambientPolicy = PetAmbientActionPolicy()
        expect(ambientPolicy.restingAnimation(for: .working) == .review, "working should rest in a focused pose")
        expect(ambientPolicy.restingAnimation(for: .waiting) == .waiting, "waiting should rest in a waiting pose")
        expect(ambientPolicy.restingAnimation(for: .offline) == .failed, "offline should rest in failed pose")
        expect(ambientPolicy.restingAnimation(for: .idleRelaxed) == .idle, "idle relaxed should use the dedicated idle pose instead of reusing waiting")
        expect(ambientPolicy.restingAnimation(for: .toolRunning) == .tapKeyboard, "tool-running should have a distinct final display pose")
        expect(ambientPolicy.restingAnimation(for: .blockedConcerned) == .failed, "blocked should settle into a concerned failed-like pose")
        expect(ambientPolicy.restingAnimation(for: .completedCalm) == .nod, "completed should settle into a calm completion pose")
        expect(ambientPolicy.restingAnimation(for: .longWorkTired) == .stretchWrist, "long work should settle into a tired work pose")
        expect(ambientPolicy.restingFrameIndex(for: .toolRunning, frameCount: 24) > 0, "tool-running should settle on a readable in-action frame")
        expect(ambientPolicy.restingFrameIndex(for: .completedCalm, frameCount: 16) > 0, "completed should settle on a readable completion frame")
        expect(ambientPolicy.microActionSuites(for: .working) == [[.breathing], [.tinyHandAdjust], [.hairSway]], "working should include subtle non-face micro action suites")
        expect(
            ambientPolicy.microActionSuites(for: .waiting) == [[.breathing], [.weightShift], [.shoulderRelax], [.tinyHandAdjust], [.hairSway]],
            "waiting should include attentive rig-backed micro action suites"
        )
        expect(ambientPolicy.microActionSuites(for: .idleRelaxed).contains([.weightShift]), "idle relaxed should keep idle weight shifts")
        expect(
            ambientPolicy.ambientSuites(for: .working) == [[.adjustGlasses], [.thinking], [.nod], [.tapKeyboard], [.checkNotes], [.stretchWrist]],
            "working should rotate through all focused short action suites"
        )
        expect(ambientPolicy.ambientSuites(for: .waiting) == [[.cursorLook], [.waving], [.nod], [.tinyHandAdjust], [.adjustOutfit]], "waiting should rotate more visible action clips without legacy face-overlay clips")
        expect(ambientPolicy.ambientSuites(for: .offline) == [], "offline should rest without extra ambient actions")
        expect(ambientPolicy.smallActionSuites(for: .idleRelaxed) == [[.waving], [.nod], [.cursorLook], [.tinyHandAdjust], [.adjustOutfit]], "idle relaxed should not be limited to one repeated wave")
        expect(ambientPolicy.ambientAnimations(for: .waiting).contains(.waving), "waiting should include visible short actions")
        expect(ambientPolicy.ambientAnimations(for: .waiting).contains(.adjustOutfit), "waiting should expose more generated action frames in normal runtime")
        expect(!ambientPolicy.ambientAnimations(for: .waiting).contains(.turning), "waiting should avoid inconsistent turntable frames")
        expect(!ambientPolicy.largeActionSuites(for: .working).flatMap { $0 }.contains(.turning), "working should avoid full turntable in default large actions")
        expect(!ambientPolicy.largeActionSuites(for: .waiting).flatMap { $0 }.contains(.turning), "waiting should avoid full turntable in default large actions")
        expect(ambientPolicy.largeActionSuites(for: .working) == [[.glanceLeft], [.glanceRight], [.focusShift], [.fixPosture], [.postureReset], [.stretch]], "working large actions should include attention, posture, and stretch clips")
        expect(
            ambientPolicy.largeActionSuites(for: .waiting) == [[.glanceLeft], [.glanceRight], [.adjustOutfit], [.lookAround], [.fixPosture], [.stepAside], [.postureReset], [.stretch]],
            "waiting large actions should include the generated exploratory and posture clips"
        )
        let waitingVisibleActions = Set(
            ambientPolicy.smallActionSuites(for: .waitingAttentive).flatMap { $0 }
                + ambientPolicy.largeActionSuites(for: .waitingAttentive).flatMap { $0 }
        )
        expect(
            [.cursorLook, .waving, .nod, .tinyHandAdjust, .adjustOutfit, .glanceLeft, .glanceRight, .lookAround, .fixPosture, .stepAside, .postureReset, .stretch].allSatisfy(waitingVisibleActions.contains),
            "waiting should expose the broad generated action set in normal ambient scheduling"
        )
        expect(ambientPolicy.largeActionSuites(for: .offline) == [], "offline should avoid large ambient actions")
        expect(ambientPolicy.hoverActionSuites(for: .working) == [[.adjustGlasses], [.thinking]], "working hover should avoid legacy face-overlay clips")
        expect(ambientPolicy.hoverActionSuites(for: .waiting) == [[.cursorLook], [.waving]], "waiting hover should avoid legacy face-overlay clips")
        expect(ambientPolicy.hoverActionSuites(for: .offline) == [[.failed]], "offline hover should keep the failed pose")
        expect(ambientPolicy.hoverActionSuites(for: .toolRunning) == [[.tapKeyboard], [.focusShift], [.checkNotes]], "tool-running hover should be visibly different from waiting hover")
        expect(ambientPolicy.smallActionSuites(for: .toolRunning) == [[.tapKeyboard], [.checkNotes], [.focusShift]], "tool-running should use tool-oriented actions")
        expect(ambientPolicy.smallActionSuites(for: .blockedConcerned).contains([.shoulderRelax]), "blocked should use low-energy recovery actions")
        expect(ambientPolicy.largeActionSuites(for: .longWorkTired) == [[.stretch], [.postureReset]], "long work should use rest-oriented large actions")

        let schedulerIntervalPolicy = PetActionSchedulerIntervalPolicy()
        expect(
            schedulerIntervalPolicy.microActionIntervalRange(for: .waitingAttentive, initialDelay: true) == PetSchedulerIntervalRange(10, 16),
            "initial micro actions should not start a dense motion cluster"
        )
        expect(
            schedulerIntervalPolicy.smallActionIntervalRange(for: .waitingAttentive, initialDelay: true) == PetSchedulerIntervalRange(24, 36),
            "initial small actions should be visible without making the pet constantly move"
        )
        expect(
            schedulerIntervalPolicy.largeActionIntervalRange(for: .waitingAttentive, initialDelay: true) == PetSchedulerIntervalRange(75, 110),
            "initial large actions should not stack with startup micro and small actions"
        )
        expect(
            schedulerIntervalPolicy.microActionIntervalRange(for: .waitingAttentive, initialDelay: false) == PetSchedulerIntervalRange(28, 46),
            "waiting micro actions should leave quiet gaps between subtle motions"
        )
        expect(
            schedulerIntervalPolicy.smallActionIntervalRange(for: .waitingAttentive, initialDelay: false) == PetSchedulerIntervalRange(55, 90),
            "waiting small actions should use more clips over time without constant motion"
        )
        expect(
            schedulerIntervalPolicy.largeActionIntervalRange(for: .idleRelaxed, initialDelay: false) == PetSchedulerIntervalRange(150, 240),
            "idle large actions should be occasional instead of continuous"
        )
        expect(
            schedulerIntervalPolicy.largeActionIntervalRange(for: .reviewFocused, initialDelay: false) == PetSchedulerIntervalRange(180, 300),
            "working large actions should remain low frequency"
        )

        let manekiAmbientPolicy = PetAmbientActionPolicy(profile: .manekiNeko)
        expect(
            manekiAmbientPolicy.restingAnimation(for: .toolRunning) == .waiting,
            "Maneki Neko should settle into compact cat poses instead of tool-specific work poses"
        )
        expect(
            manekiAmbientPolicy.microActionSuites(for: .waitingAttentive) == [[.hairSway], [.breathing], [.slowBlink]],
            "Maneki Neko waiting micro actions should prioritize tail sway, body motion, and a subtle slow blink"
        )
        expect(
            manekiAmbientPolicy.smallActionSuites(for: .waitingAttentive) == [[.waving], [.waving], [.cursorLook], [.nod]],
            "Maneki Neko waiting small actions should prioritize repeated beckoning"
        )
        expect(
            manekiAmbientPolicy.largeActionSuites(for: .waitingAttentive) == [[.lookAround], [.glanceLeft], [.glanceRight]],
            "Maneki Neko waiting large actions should include left/right head turns"
        )
        expect(
            manekiAmbientPolicy.hoverActionSuites(for: .waitingAttentive) == [[.waving], [.cursorLook], [.hairSway], [.slowBlink]],
            "Maneki Neko hover should expose waving, head turns, tail motion, and the slow blink"
        )

        let manekiSchedulerIntervalPolicy = PetActionSchedulerIntervalPolicy(profile: .manekiNeko)
        expect(
            manekiSchedulerIntervalPolicy.microActionIntervalRange(for: .waitingAttentive, initialDelay: true) == PetSchedulerIntervalRange(2, 4),
            "Maneki Neko should start tail/body micro motion immediately after switching"
        )
        expect(
            manekiSchedulerIntervalPolicy.smallActionIntervalRange(for: .waitingAttentive, initialDelay: true) == PetSchedulerIntervalRange(3, 6),
            "Maneki Neko should begin beckoning shortly after switching"
        )
        expect(
            manekiSchedulerIntervalPolicy.largeActionIntervalRange(for: .waitingAttentive, initialDelay: true) == PetSchedulerIntervalRange(8, 14),
            "Maneki Neko should show left/right attention early enough to notice"
        )
        expect(
            manekiSchedulerIntervalPolicy.smallActionIntervalRange(for: .waitingAttentive, initialDelay: false) == PetSchedulerIntervalRange(12, 22),
            "Maneki Neko should beckon more often than the human companion"
        )

        let catalog = PetActionCatalog()
        expect(catalog.descriptor(for: .blink)?.layer == .expression, "blink should remain a legacy expression descriptor")
        expect(catalog.descriptor(for: .blink)?.defaultEligible == false, "blink should not be scheduled separately from full action frames")
        expect(catalog.descriptor(for: .slowBlink)?.defaultEligible == false, "slow blink should stay out of default catalog scheduling and be profile-selected when assets exist")
        expect(catalog.descriptor(for: .breathing)?.layer == .micro, "breathing should be a micro action")
        expect(catalog.descriptor(for: .adjustGlasses)?.layer == .small, "adjust glasses should be a small action")
        expect(catalog.descriptor(for: .focusShift)?.layer == .medium, "focus shift should be a medium action")
        expect(catalog.descriptor(for: .lookAround)?.layer == .large, "look around should be a large action")
        expect(catalog.descriptor(for: .stretch)?.layer == .large, "stretch should be a large action")
        expect(catalog.descriptor(for: .hoverSmile)?.layer == .interaction, "hover smile should be an interaction action")
        expect(catalog.descriptor(for: .hoverSmile)?.defaultEligible == false, "legacy hover smile clip should not be scheduled by default")
        expect(catalog.descriptor(for: .contextMenuAttend)?.defaultEligible == false, "legacy context menu face clip should not be scheduled by default")
        expect(catalog.descriptor(for: .turning)?.layer == .debug, "full turntable should only be a debug action")
        let disabledFaceOverlayActions: [PetAnimation] = [
            .blink, .slowBlink, .eyeShiftLeft, .eyeShiftRight, .focusTighten,
            .relaxFace, .smallSmile, .tiredSoften, .curiousLook, .hoverSmile, .contextMenuAttend
        ]
        for animation in disabledFaceOverlayActions {
            expect(catalog.descriptor(for: animation)?.defaultEligible == false, "\(animation.rawValue) should not be scheduled by default")
            expect(renderModePolicy.renderMode(for: animation) == .frameClip, "\(animation.rawValue) should not use rig until clean face assets exist")
        }
        expect(catalog.animations(for: .working, layer: .micro).contains(.breathing), "working micro actions should include breathing")
        expect(catalog.animations(for: .waiting, layer: .micro).contains(.tinyHandAdjust), "waiting micro actions should include tiny hand adjustment")
        expect(catalog.animations(for: .working, layer: .small) == [.adjustGlasses, .thinking, .nod, .tapKeyboard, .checkNotes, .stretchWrist], "working small actions should express focused work")
        expect(catalog.animations(for: .waiting, layer: .expression).isEmpty, "waiting should not schedule separate expression overlays")
        expect(catalog.animations(for: .working, layer: .expression).isEmpty, "working should not schedule separate expression overlays")
        expect(catalog.animations(for: .offline, layer: .expression).isEmpty, "offline should not schedule separate expression overlays")
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
            expect(catalog.descriptor(for: animation)?.expressions.isEmpty == false, "\(animation.rawValue) should carry baked expression intent")
        }
        expect(catalog.animations(for: .waiting, layer: .large).contains(.stepAside), "waiting large action catalog should include step aside")
        expect(!catalog.animations(for: .waiting, layer: .large).contains(.turning), "default large action catalog should exclude full turntable")

        let windowPlacementPolicy = PetWindowPlacementPolicy()
        let defaultOrigin = windowPlacementPolicy.initialOrigin(
            visibleFrame: PetWindowPlacementRect(x: 0, y: 0, width: 1440, height: 900),
            windowSize: PetWindowPlacementSize(width: 576, height: 672)
        )
        expect(defaultOrigin.x == 24, "default window should start near the left edge")
        expect(defaultOrigin.y == 24, "default window should start near the bottom edge")
        let offsetScreenOrigin = windowPlacementPolicy.initialOrigin(
            visibleFrame: PetWindowPlacementRect(x: 100, y: 40, width: 1440, height: 900),
            windowSize: PetWindowPlacementSize(width: 576, height: 672)
        )
        expect(offsetScreenOrigin.x == 124, "default window should use visible frame left edge on offset screens")
        expect(offsetScreenOrigin.y == 64, "default window should use visible frame bottom edge on offset screens")

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
        let queuedSmall = timeline.decide(
            request: PetActionRequest(animation: .waving, sourcePresentationState: .waitingAttentive, submittedAt: now),
            state: busyState
        )
        expect(queuedSmall.outcome == .queue, "small actions may queue behind another small action")

        let droppedLarge = timeline.decide(
            request: PetActionRequest(animation: .lookAround, sourcePresentationState: .waitingAttentive, submittedAt: now),
            state: busyState
        )
        expect(droppedLarge.outcome == .drop, "large actions should drop when the timeline is busy")

        let hoverInterrupt = timeline.decide(
            request: PetActionRequest(animation: .cursorLook, sourcePresentationState: .waitingAttentive, submittedAt: now),
            state: busyState
        )
        expect(hoverInterrupt.outcome == .playNow, "interaction actions should interrupt ambient actions")

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
        let smallInterruptsMicro = timeline.decide(
            request: PetActionRequest(animation: .waving, sourcePresentationState: .waitingAttentive, submittedAt: now),
            state: microBusyState
        )
        expect(smallInterruptsMicro.outcome == .playNow, "larger visible actions should interrupt micro actions")

        let runtimeSchedulingPolicy = PetRuntimeSchedulingPolicy()
        expect(
            runtimeSchedulingPolicy.hoverBeginDecision(activeSchedulerKind: .small, activeActionLayer: .small) == .startHoverInteraction,
            "hover should interrupt an active small ambient action"
        )
        expect(
            runtimeSchedulingPolicy.hoverBeginDecision(activeSchedulerKind: .large, activeActionLayer: .large) == .startHoverInteraction,
            "hover should interrupt an active large ambient action"
        )
        expect(
            runtimeSchedulingPolicy.hoverBeginDecision(activeSchedulerKind: .interaction, activeActionLayer: .interaction) == .deferToActiveInteraction,
            "hover should not interrupt an active interaction action"
        )
        expect(
            runtimeSchedulingPolicy.shouldScheduleAmbientActions(
                isDragging: false,
                isHovering: false,
                hasActiveAction: true,
                hasValidAmbientTimer: false
            ) == false,
            "launch scheduling should not add ambient timers while an interaction is active"
        )
        expect(
            runtimeSchedulingPolicy.shouldScheduleAmbientActions(
                isDragging: false,
                isHovering: false,
                hasActiveAction: false,
                hasValidAmbientTimer: false
            ),
            "launch scheduling should start ambient timers when runtime is idle"
        )

        let draggingState = PetActionTimelineState(
            currentPresentationState: .waitingAttentive,
            currentLayer: nil,
            currentPriority: nil,
            reservedUntil: nil,
            isDragging: true,
            isHovering: false,
            lastStatusChangeAt: now.addingTimeInterval(-30),
            lastInteractionAt: now
        )
        let blockedDuringDrag = timeline.decide(
            request: PetActionRequest(animation: .shoulderRelax, sourcePresentationState: .waitingAttentive, submittedAt: now),
            state: draggingState
        )
        expect(blockedDuringDrag.outcome == .drop, "drag should suppress non-P0 actions")

        let staleStatus = timeline.decide(
            request: PetActionRequest(animation: .waving, sourcePresentationState: .waitingAttentive, submittedAt: now),
            state: PetActionTimelineState(
                currentPresentationState: .reviewFocused,
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
