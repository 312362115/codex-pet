import AppKit
import Foundation
import SpriteKit
#if canImport(PetCompanion)
import PetCompanion
#endif

private enum PetRow: Int {
    case idle = 0
    case runningRight = 1
    case runningLeft = 2
    case waving = 3
    case jumping = 4
    case failed = 5
    case waiting = 6
    case review = 7
    case running = 8
}

private struct CompanionConfig {
    let petImagePath: String
    let highResolutionFrameRoot: String
    let rigAssetRoot: String
    let codexAppPath: String
    let codexHome: String
    let displayWidth: CGFloat
    let displayHeight: CGFloat
    let cellWidth: Int
    let cellHeight: Int
    let columns: Int

    static var standard: CompanionConfig {
        let resourcePath = Bundle.main.resourcePath ?? ""
        let bundledFrameRoot = "\(resourcePath)/lingxi-ol-hires"
        let bundledPetImagePath = "\(resourcePath)/lingxi-ol/spritesheet.webp"
        let bundledRigAssetRoot = "\(resourcePath)/lingxi-ol-rig"
        let installedFrameRoot = "/Users/renlongyu/.codex/pet-companion/assets/lingxi-ol-hires"
        let installedPetImagePath = "/Users/renlongyu/.codex/pets/lingxi-ol/spritesheet.webp"
        let installedRigAssetRoot = "/Users/renlongyu/.codex/pet-companion/assets/lingxi-ol-rig"

        return CompanionConfig(
            petImagePath: FileManager.default.fileExists(atPath: bundledPetImagePath)
                ? bundledPetImagePath
                : installedPetImagePath,
            highResolutionFrameRoot: FileManager.default.fileExists(atPath: bundledFrameRoot)
                ? bundledFrameRoot
                : installedFrameRoot,
            rigAssetRoot: FileManager.default.fileExists(atPath: bundledRigAssetRoot)
                ? bundledRigAssetRoot
                : installedRigAssetRoot,
            codexAppPath: "/Applications/Codex.app",
            codexHome: "\(NSHomeDirectory())/.codex",
            displayWidth: 576,
            displayHeight: 624,
            cellWidth: 192,
            cellHeight: 208,
            columns: 8
        )
    }
}

private final class CodexActivityReader {
    private let config: CompanionConfig
    private let classifier = CodexActivityClassifier()
    private let phaseClassifier = CodexWorkPhaseClassifier()
    private let presentationTransitionPolicy = PetPresentationTransitionPolicy()
    private let metadataReader: CodexMetadataReader
    private var activeWorkStartedAt: Date?
    private var resolvedPresentationState: PetPresentationState?
    private var resolvedPresentationStateChangedAt: Date?
    private var candidatePresentationState: PetPresentationState?
    private var candidatePresentationStateFirstSeenAt: Date?

    init(config: CompanionConfig) {
        self.config = config
        self.metadataReader = CodexMetadataReader(config: config)
    }

    func currentStatus() -> CodexActivityStatus {
        currentPresentationState().coarseStatus
    }

    func currentPresentationState() -> PetPresentationState {
        let now = Date()
        let codexIsRunning = codexIsRunning()
        let latestActivityDate = latestActivityDate()

        updateActiveWorkStart(
            codexIsRunning: codexIsRunning,
            latestActivityDate: latestActivityDate,
            now: now
        )

        let snapshot = metadataReader.currentSnapshot(
            codexIsRunning: codexIsRunning,
            latestActivityDate: latestActivityDate,
            continuousActiveDuration: activeWorkStartedAt.map { now.timeIntervalSince($0) },
            now: now
        )
        let phase = phaseClassifier.classify(snapshot)
        if phase == .offline || phase == .idle || phase == .completed {
            activeWorkStartedAt = nil
        }
        return resolvePresentationState(phase.presentationState, now: now)
    }

    private func resolvePresentationState(
        _ candidateState: PetPresentationState,
        now: Date
    ) -> PetPresentationState {
        guard let currentState = resolvedPresentationState else {
            resolvedPresentationState = candidateState
            resolvedPresentationStateChangedAt = now
            return candidateState
        }

        if candidateState == currentState {
            candidatePresentationState = nil
            candidatePresentationStateFirstSeenAt = nil
            return currentState
        }

        if candidatePresentationState != candidateState {
            candidatePresentationState = candidateState
            candidatePresentationStateFirstSeenAt = now
        }

        let currentStateSince = resolvedPresentationStateChangedAt ?? now
        let candidateStateSince = candidatePresentationStateFirstSeenAt ?? now
        guard presentationTransitionPolicy.canSwitch(
            from: currentState,
            currentStateSince: currentStateSince,
            to: candidateState,
            candidateStateSince: candidateStateSince,
            now: now
        ) else {
            return currentState
        }

        resolvedPresentationState = candidateState
        resolvedPresentationStateChangedAt = now
        candidatePresentationState = nil
        candidatePresentationStateFirstSeenAt = nil
        return candidateState
    }

    private func updateActiveWorkStart(
        codexIsRunning: Bool,
        latestActivityDate: Date?,
        now: Date
    ) {
        guard codexIsRunning, let latestActivityDate else {
            activeWorkStartedAt = nil
            return
        }

        let activityAge = now.timeIntervalSince(latestActivityDate)
        if activityAge <= 8 {
            if activeWorkStartedAt == nil {
                activeWorkStartedAt = now
            }
        } else if activityAge > 90 {
            activeWorkStartedAt = nil
        }
    }

    func legacyStatus() -> CodexActivityStatus {
        let snapshot = CodexActivitySnapshot(
            codexIsRunning: codexIsRunning(),
            latestActivityDate: latestActivityDate(),
            now: Date()
        )
        return classifier.classify(snapshot)
    }

    private func codexIsRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            app.bundleIdentifier == "com.openai.codex" || app.localizedName == "Codex"
        }
    }

    private func latestActivityDate() -> Date? {
        let paths = [
            "\(config.codexHome)/logs_2.sqlite-wal",
            "\(config.codexHome)/state_5.sqlite-wal",
            "\(config.codexHome)/.codex-global-state.json",
            "\(config.codexHome)/session_index.jsonl"
        ]

        return paths.compactMap { path -> Date? in
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else {
                return nil
            }
            return attributes[.modificationDate] as? Date
        }.max()
    }
}

private struct CodexMetadataReader {
    private struct StateMetadata {
        let activeThreadUpdatedAt: Date?
        let hasRecentUserEvent: Bool
        let hasRunningJob: Bool
        let hasPendingJob: Bool
        let hasRecentFailedJob: Bool
        let hasRecentCompletedJob: Bool
        let hasActiveGoal: Bool
        let hasRecentCompletedGoal: Bool
    }

    private let config: CompanionConfig

    init(config: CompanionConfig) {
        self.config = config
    }

    func currentSnapshot(
        codexIsRunning: Bool,
        latestActivityDate: Date?,
        continuousActiveDuration: TimeInterval?,
        now: Date
    ) -> CodexMetadataSnapshot {
        let state = readStateMetadata(now: now)
        return CodexMetadataSnapshot(
            codexIsRunning: codexIsRunning,
            latestActivityDate: latestActivityDate,
            activeThreadUpdatedAt: state.activeThreadUpdatedAt,
            hasRecentUserEvent: state.hasRecentUserEvent,
            hasRunningJob: state.hasRunningJob,
            hasPendingJob: state.hasPendingJob,
            hasRecentToolEvent: hasRecentToolEvent(now: now),
            hasRecentFailedJob: state.hasRecentFailedJob,
            hasRecentCompletedJob: state.hasRecentCompletedJob,
            hasActiveGoal: state.hasActiveGoal,
            hasRecentCompletedGoal: state.hasRecentCompletedGoal,
            hasRecentError: hasRecentError(now: now),
            continuousActiveDuration: continuousActiveDuration,
            now: now
        )
    }

    private func readStateMetadata(now: Date) -> StateMetadata {
        let path = "\(config.codexHome)/state_5.sqlite"
        let nowSeconds = Int(now.timeIntervalSince1970)
        let nowMilliseconds = Int(now.timeIntervalSince1970 * 1000)
        let recentSeconds = nowSeconds - 180
        let recentMilliseconds = nowMilliseconds - 180_000
        let query = """
        WITH latest_thread AS (
          SELECT updated_at, updated_at_ms, has_user_event
          FROM threads
          WHERE archived = 0
          ORDER BY COALESCE(updated_at_ms, updated_at * 1000) DESC
          LIMIT 1
        )
        SELECT
          COALESCE((SELECT COALESCE(updated_at_ms / 1000, updated_at) FROM latest_thread), 0),
          COALESCE((SELECT has_user_event FROM latest_thread), 0),
          (SELECT COUNT(*) FROM agent_jobs WHERE lower(status) IN ('running', 'in_progress', 'active', 'processing', 'started')),
          (SELECT COUNT(*) FROM agent_job_items WHERE lower(status) IN ('running', 'in_progress', 'active', 'processing', 'started')),
          (SELECT COUNT(*) FROM agent_jobs WHERE lower(status) IN ('pending', 'queued')),
          (SELECT COUNT(*) FROM agent_job_items WHERE lower(status) IN ('pending', 'queued')),
          (SELECT COUNT(*) FROM agent_jobs WHERE lower(status) IN ('failed', 'error') AND COALESCE(completed_at, updated_at, started_at, created_at, 0) >= \(recentSeconds)),
          (SELECT COUNT(*) FROM agent_job_items WHERE lower(status) IN ('failed', 'error') AND COALESCE(completed_at, updated_at, created_at, 0) >= \(recentSeconds)),
          (SELECT COUNT(*) FROM agent_jobs WHERE lower(status) IN ('completed', 'complete', 'done', 'success', 'succeeded') AND COALESCE(completed_at, updated_at, started_at, created_at, 0) >= \(recentSeconds)),
          (SELECT COUNT(*) FROM agent_job_items WHERE lower(status) IN ('completed', 'complete', 'done', 'success', 'succeeded') AND COALESCE(completed_at, updated_at, created_at, 0) >= \(recentSeconds)),
          (SELECT COUNT(*) FROM thread_goals WHERE lower(status) IN ('active', 'paused', 'budget_limited')),
          (SELECT COUNT(*) FROM thread_goals WHERE lower(status) = 'complete' AND updated_at_ms >= \(recentMilliseconds));
        """

        guard let output = runSQLite(databasePath: path, query: query),
              let row = output.split(separator: "\n").first else {
            return StateMetadata(
                activeThreadUpdatedAt: nil,
                hasRecentUserEvent: false,
                hasRunningJob: false,
                hasPendingJob: false,
                hasRecentFailedJob: false,
                hasRecentCompletedJob: false,
                hasActiveGoal: false,
                hasRecentCompletedGoal: false
            )
        }

        let fields = row.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        func intValue(_ index: Int) -> Int {
            guard fields.indices.contains(index) else {
                return 0
            }
            return Int(fields[index]) ?? 0
        }

        let threadUpdatedAt = intValue(0) > 0
            ? Date(timeIntervalSince1970: TimeInterval(intValue(0)))
            : nil
        return StateMetadata(
            activeThreadUpdatedAt: threadUpdatedAt,
            hasRecentUserEvent: intValue(1) > 0,
            hasRunningJob: intValue(2) + intValue(3) > 0,
            hasPendingJob: intValue(4) + intValue(5) > 0,
            hasRecentFailedJob: intValue(6) + intValue(7) > 0,
            hasRecentCompletedJob: intValue(8) + intValue(9) > 0,
            hasActiveGoal: intValue(10) > 0,
            hasRecentCompletedGoal: intValue(11) > 0
        )
    }

    private func hasRecentError(now: Date) -> Bool {
        let path = "\(config.codexHome)/logs_2.sqlite"
        let recentSeconds = Int(now.timeIntervalSince1970) - 180
        let query = """
        SELECT COUNT(*)
        FROM logs
        WHERE upper(level) = 'ERROR'
          AND ts >= \(recentSeconds);
        """
        guard let output = runSQLite(databasePath: path, query: query),
              let count = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return count > 0
    }

    private func hasRecentToolEvent(now: Date) -> Bool {
        let path = "\(config.codexHome)/logs_2.sqlite"
        let recentSeconds = Int(now.timeIntervalSince1970) - 8
        let query = """
        SELECT COUNT(*)
        FROM logs
        WHERE ts >= \(recentSeconds)
          AND (
            lower(target) = 'rmcp::service'
            OR lower(target) = 'codex_core::shell_snapshot'
            OR lower(target) = 'codex_core::exec_policy'
            OR lower(target) LIKE 'codex_mcp::%'
            OR lower(target) LIKE 'codex_rmcp_client::%'
          )
          AND lower(target) NOT LIKE '%registry%';
        """
        guard let output = runSQLite(databasePath: path, query: query),
              let count = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return count > 0
    }

    private func runSQLite(databasePath: String, query: String) -> String? {
        guard FileManager.default.fileExists(atPath: databasePath) else {
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [
            "-readonly",
            "-batch",
            "-noheader",
            "-separator",
            "\t",
            databasePath,
            query
        ]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .newlines)
    }
}

private final class PetFrameProvider {
    private let spriteSheet: SpriteSheet
    private let framePolicy = PetAnimationFramePolicy()
    private var highResolutionFrames: [PetAnimation: [CGImage]] = [:]

    init(config: CompanionConfig) throws {
        self.spriteSheet = try SpriteSheet(path: config.petImagePath, config: config)
        self.highResolutionFrames = Self.loadHighResolutionFrames(config: config, framePolicy: framePolicy)
    }

    func frame(animation: PetAnimation, index: Int) -> CGImage? {
        if let frames = highResolutionFrames[animation], !frames.isEmpty {
            return frames[index % frames.count]
        }

        return spriteSheet.frame(row: row(for: animation), column: index)
    }

    func frameCount(for animation: PetAnimation) -> Int {
        if let frames = highResolutionFrames[animation], !frames.isEmpty {
            return frames.count
        }

        return framePolicy.frameCount(for: animation)
    }

    private static func loadHighResolutionFrames(
        config: CompanionConfig,
        framePolicy: PetAnimationFramePolicy
    ) -> [PetAnimation: [CGImage]] {
        let states: [(PetAnimation, String)] = [
            (.idle, "idle"),
            (.running, "running"),
            (.waiting, "waiting"),
            (.failed, "failed"),
            (.waving, "waving"),
            (.review, "review"),
            (.turning, "turning"),
            (.glanceLeft, "glance-left"),
            (.glanceRight, "glance-right"),
            (.breathing, "breathing"),
            (.hairSway, "hair-sway"),
            (.weightShift, "weight-shift"),
            (.shoulderRelax, "shoulder-relax"),
            (.tinyHandAdjust, "tiny-hand-adjust"),
            (.thinking, "thinking"),
            (.adjustGlasses, "adjust-glasses"),
            (.nod, "nod"),
            (.tapKeyboard, "tap-keyboard"),
            (.checkNotes, "check-notes"),
            (.stretchWrist, "stretch-wrist"),
            (.cursorLook, "cursor-look"),
            (.focusShift, "focus-shift"),
            (.fixPosture, "fix-posture"),
            (.adjustOutfit, "adjust-outfit"),
            (.lookAround, "look-around"),
            (.stretch, "stretch"),
            (.stepAside, "step-aside"),
            (.postureReset, "posture-reset"),
            (.dragReleaseSettle, "drag-release-settle"),
            (.wakeUp, "wake-up")
        ]

        var loaded: [PetAnimation: [CGImage]] = [:]
        for (animation, directoryName) in states {
            let count = framePolicy.frameCount(for: animation)
            let frames = (0..<count).compactMap { index -> CGImage? in
                let path = "\(config.highResolutionFrameRoot)/\(directoryName)/\(String(format: "%02d", index)).png"
                return loadImage(path: path)
            }
            if frames.count == count {
                loaded[animation] = frames
            }
        }
        return loaded
    }

    private static func loadImage(path: String) -> CGImage? {
        guard let nsImage = NSImage(contentsOfFile: path) else {
            return nil
        }

        var rect = NSRect(origin: .zero, size: nsImage.size)
        return nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    private func row(for animation: PetAnimation) -> PetRow {
        switch animation {
        case .idle:
            return .idle
        case .running:
            return .running
        case .waiting:
            return .waiting
        case .failed:
            return .failed
        case .waving:
            return .waving
        case .jumping:
            return .jumping
        case .review:
            return .review
        case .turning:
            return .runningRight
        case .glanceLeft:
            return .runningLeft
        case .glanceRight:
            return .runningRight
        case .blink, .slowBlink, .eyeShiftLeft, .eyeShiftRight, .focusTighten, .relaxFace, .smallSmile, .tiredSoften,
             .curiousLook, .breathing, .hairSway, .weightShift, .shoulderRelax, .tinyHandAdjust, .nod, .hoverSmile,
             .contextMenuAttend, .fixPosture, .adjustOutfit, .dragReleaseSettle, .wakeUp, .stretch, .postureReset:
            return .waiting
        case .thinking, .adjustGlasses, .tapKeyboard, .checkNotes, .stretchWrist, .cursorLook, .focusShift:
            return .running
        case .lookAround, .stepAside:
            return .runningRight
        }
    }
}

private final class SpriteSheet {
    private let image: CGImage
    private let config: CompanionConfig

    init(path: String, config: CompanionConfig) throws {
        guard let nsImage = NSImage(contentsOfFile: path) else {
            throw NSError(domain: "CodexPetCompanion", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Unable to load pet spritesheet at \(path)"
            ])
        }

        var rect = NSRect(origin: .zero, size: nsImage.size)
        guard let cgImage = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            throw NSError(domain: "CodexPetCompanion", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Unable to decode pet spritesheet at \(path)"
            ])
        }

        self.image = cgImage
        self.config = config
    }

    func frame(row: PetRow, column: Int) -> CGImage? {
        let clampedColumn = max(0, min(config.columns - 1, column))
        let rect = CGRect(
            x: clampedColumn * config.cellWidth,
            y: row.rawValue * config.cellHeight,
            width: config.cellWidth,
            height: config.cellHeight
        )
        return image.cropping(to: rect)
    }
}

private struct PetRigManifest: Decodable {
    let canvas: PetRigCanvas
    let parts: [PetRigPart]
}

private struct PetRigCanvas: Decodable {
    let width: Double
    let height: Double
}

private struct PetRigPart: Decodable {
    let id: String
    let image: String
    let parent: String?
    let position: PetRigPoint
    let anchor: PetRigPoint
    let zIndex: Double
}

private struct PetRigPoint: Decodable {
    let x: Double
    let y: Double
}

private final class PetRigProvider {
    let rootPath: String
    let manifest: PetRigManifest

    init?(config: CompanionConfig) {
        let manifestPath = "\(config.rigAssetRoot)/rig.json"
        guard FileManager.default.fileExists(atPath: manifestPath),
              let data = FileManager.default.contents(atPath: manifestPath),
              let manifest = try? JSONDecoder().decode(PetRigManifest.self, from: data) else {
            return nil
        }

        for part in manifest.parts {
            guard FileManager.default.fileExists(atPath: "\(config.rigAssetRoot)/\(part.image)") else {
                return nil
            }
        }

        self.rootPath = config.rigAssetRoot
        self.manifest = manifest
    }

    func image(for part: PetRigPart) -> NSImage? {
        NSImage(contentsOfFile: "\(rootPath)/\(part.image)")
    }
}

private final class PetRigScene: SKScene {
    private let provider: PetRigProvider
    private let rigNode = SKNode()
    private var partNodes: [String: SKSpriteNode] = [:]
    private var basePositions: [String: CGPoint] = [:]

    init(provider: PetRigProvider) {
        self.provider = provider
        let canvas = provider.manifest.canvas
        super.init(size: CGSize(width: canvas.width, height: canvas.height))
        scaleMode = .aspectFit
        backgroundColor = .clear
        buildRig()
        settle()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func settle() {
        removeAllActions()
        rigNode.removeAllActions()
        rigNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        rigNode.xScale = 1
        rigNode.yScale = 1
        rigNode.zRotation = 0

        for (id, node) in partNodes {
            node.removeAllActions()
            node.position = basePositions[id] ?? node.position
            node.xScale = 1
            node.yScale = 1
            node.zRotation = 0
            node.alpha = 1
        }
    }

    func canPlay(animation: PetAnimation) -> Bool {
        switch animation {
        case .breathing, .hairSway, .weightShift, .shoulderRelax, .cursorLook, .dragReleaseSettle, .wakeUp:
            return true
        case .idle, .running, .waiting, .failed, .waving, .jumping, .review, .turning, .glanceLeft, .glanceRight,
             .blink, .slowBlink, .eyeShiftLeft, .eyeShiftRight, .focusTighten, .relaxFace, .smallSmile, .tiredSoften,
             .curiousLook, .tinyHandAdjust, .thinking, .adjustGlasses,
             .nod, .tapKeyboard, .checkNotes, .stretchWrist, .hoverSmile, .contextMenuAttend,
             .focusShift, .fixPosture, .adjustOutfit, .lookAround, .stretch, .stepAside, .postureReset:
            return false
        }
    }

    func play(animation: PetAnimation, duration: TimeInterval, completion: @escaping () -> Void) -> Bool {
        guard canPlay(animation: animation) else {
            return false
        }

        settle()
        switch animation {
        case .breathing:
            playBreathing(duration: duration)
        case .hairSway:
            playHairSway(duration: duration)
        case .weightShift:
            playWeightShift(duration: duration)
        case .shoulderRelax:
            playShoulderRelax(duration: duration)
        case .cursorLook:
            playCursorLook(duration: duration)
        case .dragReleaseSettle:
            playDragReleaseSettle(duration: duration)
        case .wakeUp:
            playWakeUp(duration: duration)
        case .idle, .running, .waiting, .failed, .waving, .jumping, .review, .turning, .glanceLeft, .glanceRight,
             .blink, .slowBlink, .eyeShiftLeft, .eyeShiftRight, .focusTighten, .relaxFace, .smallSmile, .tiredSoften,
             .curiousLook, .tinyHandAdjust, .thinking, .adjustGlasses,
             .nod, .tapKeyboard, .checkNotes, .stretchWrist, .hoverSmile, .contextMenuAttend,
             .focusShift, .fixPosture, .adjustOutfit, .lookAround, .stretch, .stepAside, .postureReset:
            return false
        }

        run(.sequence([
            .wait(forDuration: duration),
            .run { [weak self] in
                self?.settle()
                completion()
            }
        ]))
        return true
    }

    private func buildRig() {
        addChild(rigNode)
        rigNode.position = CGPoint(x: size.width / 2, y: size.height / 2)

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        for part in provider.manifest.parts.sorted(by: { $0.zIndex < $1.zIndex }) {
            guard let image = provider.image(for: part) else {
                continue
            }
            let texture = SKTexture(image: image)
            let node = SKSpriteNode(texture: texture)
            node.name = part.id
            node.anchorPoint = CGPoint(x: part.anchor.x, y: part.anchor.y)
            node.zPosition = part.zIndex
            if let parentID = part.parent, let parentNode = partNodes[parentID] {
                node.position = CGPoint(x: part.position.x, y: part.position.y)
                parentNode.addChild(node)
            } else {
                node.position = CGPoint(x: part.position.x - center.x, y: part.position.y - center.y)
                rigNode.addChild(node)
            }
            partNodes[part.id] = node
            basePositions[part.id] = node.position
        }
    }

    private func playBreathing(duration: TimeInterval) {
        let up = SKAction.group([
            .scaleX(to: 1.002, y: 1.006, duration: duration * 0.5),
            .moveBy(x: 0, y: 2, duration: duration * 0.5)
        ])
        let down = SKAction.group([
            .scaleX(to: 1, y: 1, duration: duration * 0.5),
            .moveBy(x: 0, y: -2, duration: duration * 0.5)
        ])
        up.timingMode = .easeInEaseOut
        down.timingMode = .easeInEaseOut
        rigNode.run(.sequence([up, down]))
    }

    private func playHairSway(duration: TimeInterval) {
        let head = partNodes["head"]
        let body = partNodes["body"]
        let swayOut = SKAction.group([
            .moveBy(x: 2, y: 0, duration: duration * 0.28),
            .rotate(byAngle: -0.014, duration: duration * 0.28)
        ])
        let swayBack = SKAction.group([
            .moveBy(x: -4, y: 0, duration: duration * 0.44),
            .rotate(byAngle: 0.028, duration: duration * 0.44)
        ])
        let settle = SKAction.group([
            .moveBy(x: 2, y: 0, duration: duration * 0.28),
            .rotate(byAngle: -0.014, duration: duration * 0.28)
        ])
        let bodyCounterOut = SKAction.rotate(byAngle: 0.003, duration: duration * 0.28)
        let bodyCounterBack = SKAction.rotate(byAngle: -0.006, duration: duration * 0.44)
        let bodyCounterSettle = SKAction.rotate(byAngle: 0.003, duration: duration * 0.28)
        [swayOut, swayBack, settle, bodyCounterOut, bodyCounterBack, bodyCounterSettle].forEach { $0.timingMode = .easeInEaseOut }
        head?.run(.sequence([swayOut, swayBack, settle]))
        body?.run(.sequence([bodyCounterOut, bodyCounterBack, bodyCounterSettle]))
    }

    private func playWeightShift(duration: TimeInterval) {
        let left = SKAction.group([
            .moveBy(x: -4, y: 0, duration: duration * 0.25),
            .rotate(byAngle: 0.012, duration: duration * 0.25)
        ])
        let right = SKAction.group([
            .moveBy(x: 8, y: 0, duration: duration * 0.5),
            .rotate(byAngle: -0.024, duration: duration * 0.5)
        ])
        let center = SKAction.group([
            .moveBy(x: -4, y: 0, duration: duration * 0.25),
            .rotate(byAngle: 0.012, duration: duration * 0.25)
        ])
        [left, right, center].forEach { $0.timingMode = .easeInEaseOut }
        rigNode.run(.sequence([left, right, center]))
    }

    private func playShoulderRelax(duration: TimeInterval) {
        let body = partNodes["body"]
        let head = partNodes["head"]
        let bodyDown = SKAction.group([
            .moveBy(x: 0, y: -5, duration: duration * 0.35),
            .scaleX(to: 1.001, y: 0.996, duration: duration * 0.35)
        ])
        let bodySettle = SKAction.group([
            .moveBy(x: 0, y: 5, duration: duration * 0.45),
            .scaleX(to: 1, y: 1, duration: duration * 0.45)
        ])
        let headDown = SKAction.moveBy(x: 0, y: -2, duration: duration * 0.35)
        let headSettle = SKAction.moveBy(x: 0, y: 2, duration: duration * 0.45)
        let hold = SKAction.wait(forDuration: duration * 0.2)
        [bodyDown, bodySettle, headDown, headSettle].forEach { $0.timingMode = .easeInEaseOut }
        body?.run(.sequence([bodyDown, hold, bodySettle]))
        head?.run(.sequence([headDown, hold, headSettle]))
    }

    private func playCursorLook(duration: TimeInterval) {
        let head = partNodes["head"]
        let body = partNodes["body"]
        let turnIn = SKAction.group([
            .moveBy(x: 3, y: 1, duration: duration * 0.25),
            .rotate(byAngle: -0.028, duration: duration * 0.25)
        ])
        let hold = SKAction.wait(forDuration: duration * 0.35)
        let turnOut = SKAction.group([
            .moveBy(x: -3, y: -1, duration: duration * 0.4),
            .rotate(byAngle: 0.028, duration: duration * 0.4)
        ])
        let bodyCounterIn = SKAction.rotate(byAngle: 0.004, duration: duration * 0.25)
        let bodyCounterOut = SKAction.rotate(byAngle: -0.004, duration: duration * 0.4)
        [turnIn, turnOut, bodyCounterIn, bodyCounterOut].forEach { $0.timingMode = .easeInEaseOut }
        head?.run(.sequence([turnIn, hold, turnOut]))
        body?.run(.sequence([bodyCounterIn, hold, bodyCounterOut]))
    }

    private func playDragReleaseSettle(duration: TimeInterval) {
        let compress = SKAction.group([
            .moveBy(x: 0, y: -6, duration: duration * 0.28),
            .scaleX(to: 1.006, y: 0.992, duration: duration * 0.28)
        ])
        let rebound = SKAction.group([
            .moveBy(x: 0, y: 9, duration: duration * 0.32),
            .scaleX(to: 0.998, y: 1.004, duration: duration * 0.32)
        ])
        let settle = SKAction.group([
            .moveBy(x: 0, y: -3, duration: duration * 0.40),
            .scaleX(to: 1, y: 1, duration: duration * 0.40)
        ])
        [compress, rebound, settle].forEach { $0.timingMode = .easeInEaseOut }
        rigNode.run(.sequence([compress, rebound, settle]))
    }

    private func playWakeUp(duration: TimeInterval) {
        let head = partNodes["head"]
        let body = partNodes["body"]
        let bodyRise = SKAction.group([
            .moveBy(x: 0, y: 4, duration: duration * 0.36),
            .scaleX(to: 1.002, y: 1.006, duration: duration * 0.36)
        ])
        let bodySettle = SKAction.group([
            .moveBy(x: 0, y: -4, duration: duration * 0.44),
            .scaleX(to: 1, y: 1, duration: duration * 0.44)
        ])
        let headLift = SKAction.group([
            .moveBy(x: 0, y: 5, duration: duration * 0.36),
            .rotate(byAngle: -0.012, duration: duration * 0.36)
        ])
        let headSettle = SKAction.group([
            .moveBy(x: 0, y: -5, duration: duration * 0.44),
            .rotate(byAngle: 0.012, duration: duration * 0.44)
        ])
        let hold = SKAction.wait(forDuration: duration * 0.2)
        [bodyRise, bodySettle, headLift, headSettle].forEach { $0.timingMode = .easeInEaseOut }
        body?.run(.sequence([bodyRise, hold, bodySettle]))
        head?.run(.sequence([headLift, hold, headSettle]))
    }

}

private final class PetRigView: SKView {
    private let rigScene: PetRigScene

    init?(provider: PetRigProvider, frame: CGRect) {
        self.rigScene = PetRigScene(provider: provider)
        super.init(frame: frame)
        allowsTransparency = true
        ignoresSiblingOrder = true
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        presentScene(rigScene)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func supports(presentationState: PetPresentationState) -> Bool {
        switch presentationState {
        case .idleRelaxed, .waitingAttentive:
            return true
        case .offlineRest, .reviewFocused, .toolRunning, .blockedConcerned, .completedCalm, .longWorkTired:
            return false
        }
    }

    func settle(presentationState: PetPresentationState) -> Bool {
        guard supports(presentationState: presentationState) else {
            isHidden = true
            return false
        }

        rigScene.settle()
        isHidden = false
        return true
    }

    func play(animation: PetAnimation, duration: TimeInterval, completion: @escaping () -> Void) -> Bool {
        guard !isHidden else {
            return false
        }
        return rigScene.play(animation: animation, duration: duration, completion: completion)
    }

    func stop() {
        rigScene.settle()
    }
}

private final class PetWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

private enum PetPlayback {
    case frameClip
    case rigMotion(duration: TimeInterval)
}

private final class PetView: NSView {
    private let frameProvider: PetFrameProvider
    private let config: CompanionConfig
    private let renderModePolicy = PetRenderModePolicy()
    private let timingPolicy = PetAnimationTimingPolicy()
    private var rigView: PetRigView?
    private var shouldDrawFrameClip = true
    private var presentationState: PetPresentationState = .waitingAttentive
    private var animation = PetAnimation.waiting
    private var frameIndex = 0
    private let motionPolicy = PetMotionPolicy()
    private let ambientPolicy = PetAmbientActionPolicy()
    var onDragStart: (() -> Void)?
    var onDragEnd: (() -> Void)?
    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?
    var onContextMenuOpen: (() -> Void)?
    private var trackingArea: NSTrackingArea?

    init(frameProvider: PetFrameProvider, config: CompanionConfig) {
        self.frameProvider = frameProvider
        self.config = config
        super.init(frame: NSRect(x: 0, y: 0, width: config.displayWidth, height: config.displayHeight + 48))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        postsFrameChangedNotifications = true

        if let rigProvider = PetRigProvider(config: config),
           let rigView = PetRigView(
               provider: rigProvider,
               frame: CGRect(x: 0, y: 48, width: config.displayWidth, height: config.displayHeight)
           ) {
            rigView.autoresizingMask = [.width, .height]
            rigView.isHidden = true
            addSubview(rigView)
            self.rigView = rigView
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    func settle(presentationState: PetPresentationState) {
        let restingAnimation = ambientPolicy.restingAnimation(for: presentationState)
        let restingFrameIndex = ambientPolicy.restingFrameIndex(
            for: presentationState,
            frameCount: frameProvider.frameCount(for: restingAnimation)
        )
        let rigSettled = rigView?.settle(presentationState: presentationState) ?? false
        shouldDrawFrameClip = !rigSettled
        if self.presentationState != presentationState
            || self.animation != restingAnimation
            || self.frameIndex != restingFrameIndex
            || rigSettled {
            self.presentationState = presentationState
            self.animation = restingAnimation
            self.frameIndex = restingFrameIndex
            needsDisplay = true
        }
    }

    func play(animation: PetAnimation) -> PetPlayback {
        self.animation = animation
        self.frameIndex = 0
        if renderModePolicy.usesSpriteKitRig(animation),
           rigView?.play(
               animation: animation,
               duration: timingPolicy.totalDuration(for: animation),
               completion: {}
           ) == true {
            shouldDrawFrameClip = false
            needsDisplay = true
            return .rigMotion(duration: timingPolicy.totalDuration(for: animation))
        }

        rigView?.isHidden = true
        shouldDrawFrameClip = true
        needsDisplay = true
        return .frameClip
    }

    func frameCount(for animation: PetAnimation) -> Int {
        frameProvider.frameCount(for: animation)
    }

    func stopCurrentAnimation() {
        rigView?.stop()
    }

    func advanceAnimationFrame() -> Bool {
        guard motionPolicy.loopsContinuously(animation: animation) else {
            let nextFrameIndex = frameIndex + 1
            if nextFrameIndex >= frameProvider.frameCount(for: animation) {
                return true
            }
            frameIndex = nextFrameIndex
            needsDisplay = true
            return false
        }

        frameIndex = (frameIndex + 1) % frameProvider.frameCount(for: animation)
        needsDisplay = true
        return false
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEnter?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExit?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.clear.setFill()
        dirtyRect.fill()

        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        if shouldDrawFrameClip, let frame = frameProvider.frame(animation: animation, index: frameIndex) {
            context.interpolationQuality = .high
            let imageBounds = CGRect(
                x: 0,
                y: 48,
                width: bounds.width,
                height: max(0, bounds.height - 48)
            )
            context.draw(frame, in: aspectFitRect(for: frame, in: imageBounds))
        }

        drawStatusPill()
    }

    private func aspectFitRect(for frame: CGImage, in bounds: CGRect) -> CGRect {
        guard frame.width > 0, frame.height > 0, bounds.width > 0, bounds.height > 0 else {
            return bounds
        }

        let scale = min(bounds.width / CGFloat(frame.width), bounds.height / CGFloat(frame.height))
        let width = CGFloat(frame.width) * scale
        let height = CGFloat(frame.height) * scale
        return CGRect(
            x: bounds.midX - width / 2,
            y: bounds.midY - height / 2,
            width: width,
            height: height
        )
    }

    private func drawStatusPill() {
        let text: String
        let fillColor: NSColor
        switch presentationState {
        case .offlineRest:
            text = presentationState.statusText
            fillColor = NSColor(calibratedRed: 0.42, green: 0.42, blue: 0.45, alpha: 0.72)
        case .reviewFocused, .toolRunning:
            text = presentationState.statusText
            fillColor = NSColor(calibratedRed: 0.09, green: 0.42, blue: 0.33, alpha: 0.78)
        case .blockedConcerned:
            text = presentationState.statusText
            fillColor = NSColor(calibratedRed: 0.55, green: 0.18, blue: 0.18, alpha: 0.78)
        case .completedCalm:
            text = presentationState.statusText
            fillColor = NSColor(calibratedRed: 0.22, green: 0.38, blue: 0.22, alpha: 0.78)
        case .longWorkTired:
            text = presentationState.statusText
            fillColor = NSColor(calibratedRed: 0.46, green: 0.34, blue: 0.18, alpha: 0.78)
        case .idleRelaxed, .waitingAttentive:
            text = presentationState.statusText
            fillColor = NSColor(calibratedRed: 0.20, green: 0.25, blue: 0.34, alpha: 0.76)
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()
        let pillWidth = min(config.displayWidth - 48, textSize.width + 44)
        let pillRect = NSRect(
            x: (bounds.width - pillWidth) / 2,
            y: 8,
            width: pillWidth,
            height: 32
        )

        fillColor.setFill()
        NSBezierPath(roundedRect: pillRect, xRadius: 16, yRadius: 16).fill()

        attributed.draw(at: NSPoint(
            x: pillRect.midX - textSize.width / 2,
            y: pillRect.midY - textSize.height / 2
        ))
    }

    override func mouseDown(with event: NSEvent) {
        onDragStart?()
        window?.performDrag(with: event)
        onDragEnd?()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        onContextMenuOpen?()
        let menu = NSMenu()
        let openItem = NSMenuItem(title: "打开 Codex", action: #selector(AppDelegate.openCodex), keyEquivalent: "")
        openItem.target = NSApp.delegate
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "退出宠物", action: #selector(AppDelegate.quit), keyEquivalent: "q")
        quitItem.target = NSApp.delegate
        menu.addItem(quitItem)
        return menu
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let config = CompanionConfig.standard
    private var window: PetWindow?
    private var petView: PetView?
    private var activityReader: CodexActivityReader?
    private var pollTimer: Timer?
    private var microActionTimer: Timer?
    private var smallActionTimer: Timer?
    private var largeActionTimer: Timer?
    private var animationTimer: Timer?
    private var currentPresentationState = PetPresentationState.waitingAttentive
    private var isDragging = false
    private var isHovering = false
    private var actionSuite: [PetAnimation] = []
    private var actionSuiteStep = 0
    private var activeSchedulerKind: PetSchedulerKind?
    private var activeActionLayer: PetActionLayer?
    private var activeActionPriority: PetActionPriority?
    private var activeActionReservedUntil: Date?
    private var lastStatusChangeAt = Date()
    private var lastInteractionAt = Date.distantPast
    private var queuedSmallAction: [PetAnimation]?
    private var hoverOwnsCurrentInteraction = false
    private var suiteCursors: [String: Int] = [:]
    private let ambientPolicy = PetAmbientActionPolicy()
    private let actionCatalog = PetActionCatalog()
    private let actionTimeline = PetActionTimeline()
    private let timingPolicy = PetAnimationTimingPolicy()
    private let schedulerIntervalPolicy = PetActionSchedulerIntervalPolicy()
    private let runtimeSchedulingPolicy = PetRuntimeSchedulingPolicy()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        do {
            let frameProvider = try PetFrameProvider(config: config)
            let petView = PetView(frameProvider: frameProvider, config: config)
            self.petView = petView
            self.activityReader = CodexActivityReader(config: config)
            petView.onDragStart = { [weak self] in
                self?.beginDragging()
            }
            petView.onDragEnd = { [weak self] in
                self?.endDragging()
            }
            petView.onMouseEnter = { [weak self] in
                self?.beginHovering()
            }
            petView.onMouseExit = { [weak self] in
                self?.endHovering()
            }
            petView.onContextMenuOpen = { [weak self] in
                self?.beginContextMenuAttention()
            }

            let frame = initialWindowFrame()
            let window = PetWindow(
                contentRect: frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.contentView = petView
            window.makeKeyAndOrderFront(nil)
            self.window = window

            pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.pollPresentationState()
                }
            }

            pollPresentationState()
            scheduleAllSchedulersIfIdle(initialDelay: true)
        } catch {
            presentStartupError(error)
        }
    }

    @objc func openCodex() {
        let url = URL(fileURLWithPath: config.codexAppPath)
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    private func pollPresentationState() {
        guard let presentationState = activityReader?.currentPresentationState() else {
            handlePresentationState(.offlineRest)
            return
        }
        handlePresentationState(presentationState)
    }

    private func handlePresentationState(_ presentationState: PetPresentationState) {
        guard presentationState != currentPresentationState else {
            return
        }

        let previousPresentationState = currentPresentationState
        currentPresentationState = presentationState
        lastStatusChangeAt = Date()
        stopScheduledAndActiveActions()
        if !isDragging {
            petView?.settle(presentationState: presentationState)
            let transition = presentationTransitionSuite(from: previousPresentationState, to: presentationState)
            if transition.isEmpty {
                scheduleAllSchedulers(initialDelay: true)
            } else {
                requestActionSuite(transition, kind: .interaction, sourcePresentationState: presentationState)
            }
        }
    }

    private func scheduleAllSchedulers(initialDelay: Bool = false) {
        scheduleMicroAction(initialDelay: initialDelay)
        scheduleSmallAction(initialDelay: initialDelay)
        scheduleLargeAction(initialDelay: initialDelay)
    }

    private func scheduleAllSchedulersIfIdle(initialDelay: Bool = false) {
        guard runtimeSchedulingPolicy.shouldScheduleAmbientActions(
            isDragging: isDragging,
            isHovering: isHovering,
            hasActiveAction: hasActiveAction,
            hasValidAmbientTimer: hasValidAmbientActionTimer
        ) else {
            return
        }
        scheduleAllSchedulers(initialDelay: initialDelay)
    }

    private var hasActiveAction: Bool {
        activeSchedulerKind != nil || !actionSuite.isEmpty || (animationTimer?.isValid == true)
    }

    private var hasValidAmbientActionTimer: Bool {
        microActionTimer?.isValid == true
            || smallActionTimer?.isValid == true
            || largeActionTimer?.isValid == true
    }

    private func invalidateAmbientActionTimers() {
        microActionTimer?.invalidate()
        microActionTimer = nil
        smallActionTimer?.invalidate()
        smallActionTimer = nil
        largeActionTimer?.invalidate()
        largeActionTimer = nil
    }

    private func scheduleMicroAction(initialDelay: Bool = false) {
        microActionTimer?.invalidate()
        microActionTimer = nil
        guard !isDragging, !isHovering else {
            return
        }

        let interval = microActionInterval(initialDelay: initialDelay)
        microActionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.requestNextAction(kind: .micro)
            }
        }
    }

    private func scheduleSmallAction(initialDelay: Bool = false) {
        smallActionTimer?.invalidate()
        smallActionTimer = nil
        guard !isDragging, !isHovering else {
            return
        }

        let interval = smallActionInterval(initialDelay: initialDelay)
        smallActionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.requestNextAction(kind: .small)
            }
        }
    }

    private func scheduleLargeAction(initialDelay: Bool = false) {
        largeActionTimer?.invalidate()
        largeActionTimer = nil
        guard !isDragging, !isHovering else {
            return
        }

        let interval = largeActionInterval(initialDelay: initialDelay)
        largeActionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.requestNextAction(kind: .large)
            }
        }
    }

    private func requestNextAction(kind: PetSchedulerKind) {
        guard !isDragging, !isHovering, petView != nil else {
            scheduleAction(kind: kind)
            return
        }

        let suite = nextSuite(kind: kind)
        guard !suite.isEmpty else {
            scheduleAction(kind: kind)
            return
        }

        requestActionSuite(suite, kind: kind, sourcePresentationState: currentPresentationState)
    }

    private func requestActionSuite(
        _ suite: [PetAnimation],
        kind: PetSchedulerKind,
        sourcePresentationState: PetPresentationState
    ) {
        guard !suite.isEmpty else {
            scheduleAction(kind: kind)
            return
        }
        if kind == .micro,
           activeActionLayer != nil,
           activeActionLayer != actionLayer(for: kind) {
            scheduleAction(kind: kind)
            return
        }

        let primaryAnimation = primaryAnimation(in: suite) ?? suite[0]
        let request = PetActionRequest(
            animation: primaryAnimation,
            sourcePresentationState: sourcePresentationState,
            submittedAt: Date(),
            catalog: actionCatalog
        )
        let state = PetActionTimelineState(
            currentPresentationState: currentPresentationState,
            currentLayer: activeActionLayer,
            currentPriority: activeActionPriority,
            reservedUntil: activeActionReservedUntil,
            isDragging: isDragging,
            isHovering: isHovering,
            lastStatusChangeAt: lastStatusChangeAt,
            lastInteractionAt: lastInteractionAt
        )
        let decision = actionTimeline.decide(request: request, state: state)

        switch decision.outcome {
        case .playNow, .merge:
            playActionSuite(suite, kind: kind, request: request)
        case .queue:
            if kind == .small {
                queuedSmallAction = suite
            } else {
                scheduleAction(kind: kind)
            }
        case .drop:
            scheduleAction(kind: kind)
        }
    }

    private func playActionSuite(_ suite: [PetAnimation], kind: PetSchedulerKind, request: PetActionRequest) {
        if kind == .interaction {
            invalidateAmbientActionTimers()
        }
        activeSchedulerKind = kind
        activeActionLayer = request.layer
        activeActionPriority = request.priority
        activeActionReservedUntil = Date().addingTimeInterval(totalDuration(for: suite))
        actionSuite = suite
        actionSuiteStep = 0
        playNextActionSuiteStep()
    }

    private func playNextActionSuiteStep() {
        guard !isDragging, let petView else {
            finishAction()
            return
        }

        guard actionSuiteStep < actionSuite.count else {
            finishAction()
            return
        }

        let animation = actionSuite[actionSuiteStep]
        actionSuiteStep += 1
        let playback = petView.play(animation: animation)
        animationTimer?.invalidate()
        switch playback {
        case .frameClip:
            let frameInterval = timingPolicy.frameInterval(for: animation, frameCount: petView.frameCount(for: animation))
            animationTimer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let petView = self.petView else {
                        self?.animationTimer?.invalidate()
                        self?.animationTimer = nil
                        return
                    }

                    if petView.advanceAnimationFrame() {
                        self.animationTimer?.invalidate()
                        self.animationTimer = nil
                        self.playNextActionSuiteStep()
                    }
                }
            }
        case .rigMotion(let duration):
            animationTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.animationTimer?.invalidate()
                    self?.animationTimer = nil
                    self?.playNextActionSuiteStep()
                }
            }
        }
    }

    private func finishAction() {
        animationTimer?.invalidate()
        animationTimer = nil
        actionSuite = []
        actionSuiteStep = 0
        let finishedKind = activeSchedulerKind
        activeSchedulerKind = nil
        activeActionLayer = nil
        activeActionPriority = nil
        activeActionReservedUntil = nil
        petView?.settle(presentationState: currentPresentationState)

        if let queuedSmallAction, !isDragging, !isHovering {
            self.queuedSmallAction = nil
            requestActionSuite(queuedSmallAction, kind: .small, sourcePresentationState: currentPresentationState)
            return
        }

        switch finishedKind {
        case .micro:
            scheduleMicroAction()
        case .small:
            scheduleSmallAction()
        case .large:
            scheduleLargeAction()
        case .interaction:
            scheduleAllSchedulers(initialDelay: true)
        case nil:
            scheduleAllSchedulers(initialDelay: true)
        }
    }

    private func nextSuite(kind: PetSchedulerKind) -> [PetAnimation] {
        switch kind {
        case .micro:
            return nextActionSuite(from: ambientPolicy.microActionSuites(for: currentPresentationState), kind: kind)
        case .small:
            return nextActionSuite(from: ambientPolicy.smallActionSuites(for: currentPresentationState), kind: kind)
        case .large:
            return nextActionSuite(from: ambientPolicy.largeActionSuites(for: currentPresentationState), kind: kind)
        case .interaction:
            return hoverSuite()
        }
    }

    private func nextActionSuite(from suites: [[PetAnimation]], kind: PetSchedulerKind) -> [PetAnimation] {
        guard !suites.isEmpty else {
            return []
        }

        let cursorKey = "\(currentPresentationState.rawValue)-\(kind.rawValue)"
        let cursor = suiteCursors[cursorKey, default: 0]
        suiteCursors[cursorKey] = cursor + 1
        return suites[cursor % suites.count]
    }

    private func scheduleAction(kind: PetSchedulerKind) {
        switch kind {
        case .micro:
            scheduleMicroAction()
        case .small:
            scheduleSmallAction()
        case .large:
            scheduleLargeAction()
        case .interaction:
            break
        }
    }

    private func stopScheduledAndActiveActions() {
        invalidateAmbientActionTimers()
        animationTimer?.invalidate()
        animationTimer = nil
        petView?.stopCurrentAnimation()
        actionSuite = []
        actionSuiteStep = 0
        activeSchedulerKind = nil
        activeActionLayer = nil
        activeActionPriority = nil
        activeActionReservedUntil = nil
        queuedSmallAction = nil
        hoverOwnsCurrentInteraction = false
    }

    private func beginHovering() {
        guard !isDragging else {
            return
        }

        isHovering = true
        lastInteractionAt = Date()
        switch runtimeSchedulingPolicy.hoverBeginDecision(
            activeSchedulerKind: activeSchedulerKind,
            activeActionLayer: activeActionLayer
        ) {
        case .deferToActiveInteraction:
            invalidateAmbientActionTimers()
            return
        case .startHoverInteraction:
            stopScheduledAndActiveActions()
            hoverOwnsCurrentInteraction = true
            requestActionSuite(hoverSuite(), kind: .interaction, sourcePresentationState: currentPresentationState)
        }
    }

    private func endHovering() {
        isHovering = false
        lastInteractionAt = Date()
        guard !isDragging else {
            return
        }
        if hoverOwnsCurrentInteraction {
            stopScheduledAndActiveActions()
            petView?.settle(presentationState: currentPresentationState)
        }
        hoverOwnsCurrentInteraction = false
        scheduleAllSchedulers(initialDelay: true)
    }

    private func hoverSuite() -> [PetAnimation] {
        let suites = ambientPolicy.hoverActionSuites(for: currentPresentationState)
        guard !suites.isEmpty else {
            return []
        }
        return nextActionSuite(from: suites, kind: .interaction)
    }

    private func beginContextMenuAttention() {
        guard !isDragging else {
            return
        }

        lastInteractionAt = Date()
        stopScheduledAndActiveActions()
        if currentPresentationState == .offlineRest {
            requestActionSuite([.failed], kind: .interaction, sourcePresentationState: currentPresentationState)
        } else {
            requestActionSuite([.cursorLook], kind: .interaction, sourcePresentationState: currentPresentationState)
        }
    }

    private func beginDragging() {
        isDragging = true
        lastInteractionAt = Date()
        stopScheduledAndActiveActions()
    }

    private func endDragging() {
        isDragging = false
        lastInteractionAt = Date()
        requestActionSuite([.dragReleaseSettle], kind: .interaction, sourcePresentationState: currentPresentationState)
    }

    private func presentationTransitionSuite(
        from previousState: PetPresentationState,
        to state: PetPresentationState
    ) -> [PetAnimation] {
        switch (previousState, state) {
        case (_, .offlineRest):
            return []
        case (.offlineRest, .idleRelaxed), (.offlineRest, .waitingAttentive):
            return [.wakeUp]
        case (_, .idleRelaxed):
            return [.shoulderRelax]
        case (.offlineRest, .reviewFocused), (.offlineRest, .toolRunning):
            return [.wakeUp, .adjustGlasses]
        case (_, .reviewFocused):
            return [.adjustGlasses]
        case (_, .toolRunning):
            return [.tapKeyboard]
        case (_, .waitingAttentive):
            return [.cursorLook]
        case (_, .blockedConcerned):
            return []
        case (_, .completedCalm):
            return [.nod]
        case (_, .longWorkTired):
            return [.stretchWrist]
        }
    }

    private func primaryAnimation(in suite: [PetAnimation]) -> PetAnimation? {
        suite.first { animation in
            actionCatalog.descriptor(for: animation)?.layer != .pose
        }
    }

    private func totalDuration(for suite: [PetAnimation]) -> TimeInterval {
        suite.reduce(0) { partial, animation in
            partial + timingPolicy.totalDuration(for: animation)
        }
    }

    private func actionLayer(for kind: PetSchedulerKind) -> PetActionLayer? {
        switch kind {
        case .micro:
            return .micro
        case .small:
            return .small
        case .large:
            return .large
        case .interaction:
            return .interaction
        }
    }

    private func smallActionInterval(initialDelay: Bool) -> TimeInterval {
        schedulerIntervalPolicy.smallActionIntervalRange(
            for: currentPresentationState,
            initialDelay: initialDelay
        ).randomInterval()
    }

    private func microActionInterval(initialDelay: Bool) -> TimeInterval {
        schedulerIntervalPolicy.microActionIntervalRange(
            for: currentPresentationState,
            initialDelay: initialDelay
        ).randomInterval()
    }

    private func largeActionInterval(initialDelay: Bool) -> TimeInterval {
        schedulerIntervalPolicy.largeActionIntervalRange(
            for: currentPresentationState,
            initialDelay: initialDelay
        ).randomInterval()
    }

    private func initialWindowFrame() -> NSRect {
        let size = NSSize(width: config.displayWidth, height: config.displayHeight + 48)
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = PetWindowPlacementPolicy().initialOrigin(
            visibleFrame: PetWindowPlacementRect(
                x: Double(visibleFrame.minX),
                y: Double(visibleFrame.minY),
                width: Double(visibleFrame.width),
                height: Double(visibleFrame.height)
            ),
            windowSize: PetWindowPlacementSize(width: Double(size.width), height: Double(size.height))
        )
        return NSRect(
            x: CGFloat(origin.x),
            y: CGFloat(origin.y),
            width: size.width,
            height: size.height
        )
    }

    private func presentStartupError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.messageText = "Codex Pet Companion 无法启动"
        alert.informativeText = error.localizedDescription
        alert.runModal()
        NSApp.terminate(nil)
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
