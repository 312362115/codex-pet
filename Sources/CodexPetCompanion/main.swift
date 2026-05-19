import AppKit
import Foundation

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
        let installedFrameRoot = "/Users/renlongyu/.codex/pet-companion/assets/lingxi-ol-hires"
        let installedPetImagePath = "/Users/renlongyu/.codex/pets/lingxi-ol/spritesheet.webp"

        return CompanionConfig(
            petImagePath: FileManager.default.fileExists(atPath: bundledPetImagePath)
                ? bundledPetImagePath
                : installedPetImagePath,
            highResolutionFrameRoot: FileManager.default.fileExists(atPath: bundledFrameRoot)
                ? bundledFrameRoot
                : installedFrameRoot,
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

    init(config: CompanionConfig) {
        self.config = config
    }

    func currentStatus() -> CodexActivityStatus {
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
            (.jumping, "jumping"),
            (.review, "review"),
            (.turning, "turning"),
            (.glanceLeft, "glance-left"),
            (.glanceRight, "glance-right"),
            (.blink, "blink"),
            (.slowBlink, "slow-blink"),
            (.eyeShiftLeft, "eye-shift-left"),
            (.eyeShiftRight, "eye-shift-right"),
            (.focusTighten, "focus-tighten"),
            (.relaxFace, "relax-face"),
            (.smallSmile, "small-smile"),
            (.tiredSoften, "tired-soften"),
            (.curiousLook, "curious-look"),
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
            (.hoverSmile, "hover-smile"),
            (.contextMenuAttend, "context-menu-attend"),
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

private final class PetWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

private final class PetView: NSView {
    private let frameProvider: PetFrameProvider
    private let config: CompanionConfig
    private var status: CodexActivityStatus = .waiting
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
    }

    required init?(coder: NSCoder) {
        nil
    }

    func settle(status: CodexActivityStatus) {
        let restingAnimation = ambientPolicy.restingAnimation(for: status)
        if self.status != status || self.animation != restingAnimation {
            self.status = status
            self.animation = restingAnimation
            self.frameIndex = 0
            needsDisplay = true
        }
    }

    func play(animation: PetAnimation) {
        self.animation = animation
        self.frameIndex = 0
        needsDisplay = true
    }

    func frameCount(for animation: PetAnimation) -> Int {
        frameProvider.frameCount(for: animation)
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

        if let frame = frameProvider.frame(animation: animation, index: frameIndex) {
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
        switch status {
        case .offline:
            text = "Codex 离线"
            fillColor = NSColor(calibratedRed: 0.42, green: 0.42, blue: 0.45, alpha: 0.72)
        case .working:
            text = "Codex 工作中"
            fillColor = NSColor(calibratedRed: 0.09, green: 0.42, blue: 0.33, alpha: 0.78)
        case .waiting:
            text = "等待输入"
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

private enum PetSchedulerKind {
    case expression
    case micro
    case small
    case large
    case interaction
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let config = CompanionConfig.standard
    private var window: PetWindow?
    private var petView: PetView?
    private var activityReader: CodexActivityReader?
    private var pollTimer: Timer?
    private var expressionTimer: Timer?
    private var microActionTimer: Timer?
    private var smallActionTimer: Timer?
    private var largeActionTimer: Timer?
    private var animationTimer: Timer?
    private var currentStatus = CodexActivityStatus.waiting
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
    private var workingSuiteCursor = 0
    private var waitingSuiteCursor = 0
    private var offlineSuiteCursor = 0
    private var workingMicroSuiteCursor = 0
    private var waitingMicroSuiteCursor = 0
    private var workingLargeSuiteCursor = 0
    private var waitingLargeSuiteCursor = 0
    private var expressionCursor = 0
    private let ambientPolicy = PetAmbientActionPolicy()
    private let actionCatalog = PetActionCatalog()
    private let actionTimeline = PetActionTimeline()
    private let timingPolicy = PetAnimationTimingPolicy()

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
                self?.pollStatus()
            }

            pollStatus()
            scheduleAllSchedulers(initialDelay: true)
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

    private func pollStatus() {
        guard let status = activityReader?.currentStatus() else {
            handleStatus(.offline)
            return
        }
        handleStatus(status)
    }

    private func handleStatus(_ status: CodexActivityStatus) {
        guard status != currentStatus else {
            return
        }

        let previousStatus = currentStatus
        currentStatus = status
        lastStatusChangeAt = Date()
        stopScheduledAndActiveActions()
        if !isDragging {
            petView?.settle(status: status)
            let transition = statusTransitionSuite(from: previousStatus, to: status)
            if transition.isEmpty {
                scheduleAllSchedulers(initialDelay: true)
            } else {
                requestActionSuite(transition, kind: .interaction, sourceStatus: status)
            }
        }
    }

    private func scheduleAllSchedulers(initialDelay: Bool = false) {
        scheduleExpressionAction(initialDelay: initialDelay)
        scheduleMicroAction(initialDelay: initialDelay)
        scheduleSmallAction(initialDelay: initialDelay)
        scheduleLargeAction(initialDelay: initialDelay)
    }

    private func scheduleExpressionAction(initialDelay: Bool = false) {
        expressionTimer?.invalidate()
        guard !isDragging else {
            return
        }

        let interval = expressionInterval(initialDelay: initialDelay)
        expressionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.requestNextAction(kind: .expression)
        }
    }

    private func scheduleMicroAction(initialDelay: Bool = false) {
        microActionTimer?.invalidate()
        guard !isDragging else {
            return
        }

        let interval = microActionInterval(initialDelay: initialDelay)
        microActionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.requestNextAction(kind: .micro)
        }
    }

    private func scheduleSmallAction(initialDelay: Bool = false) {
        smallActionTimer?.invalidate()
        guard !isDragging else {
            return
        }

        let interval = smallActionInterval(initialDelay: initialDelay)
        smallActionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.requestNextAction(kind: .small)
        }
    }

    private func scheduleLargeAction(initialDelay: Bool = false) {
        largeActionTimer?.invalidate()
        guard !isDragging, !isHovering else {
            return
        }

        let interval = largeActionInterval(initialDelay: initialDelay)
        largeActionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.requestNextAction(kind: .large)
        }
    }

    private func requestNextAction(kind: PetSchedulerKind) {
        guard !isDragging, petView != nil else {
            scheduleAction(kind: kind)
            return
        }

        let suite = nextSuite(kind: kind)
        guard !suite.isEmpty else {
            scheduleAction(kind: kind)
            return
        }

        requestActionSuite(suite, kind: kind, sourceStatus: currentStatus)
    }

    private func requestActionSuite(_ suite: [PetAnimation], kind: PetSchedulerKind, sourceStatus: CodexActivityStatus) {
        guard !suite.isEmpty else {
            scheduleAction(kind: kind)
            return
        }
        if (kind == .expression || kind == .micro),
           activeActionLayer != nil,
           activeActionLayer != actionLayer(for: kind) {
            scheduleAction(kind: kind)
            return
        }

        let primaryAnimation = primaryAnimation(in: suite) ?? suite[0]
        let request = PetActionRequest(animation: primaryAnimation, sourceStatus: sourceStatus, submittedAt: Date(), catalog: actionCatalog)
        let state = PetActionTimelineState(
            currentStatus: currentStatus,
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
        petView.play(animation: animation)
        animationTimer?.invalidate()
        let frameInterval = timingPolicy.frameInterval(for: animation, frameCount: petView.frameCount(for: animation))
        animationTimer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { [weak self] timer in
            guard let self, let petView = self.petView else {
                timer.invalidate()
                return
            }

            if petView.advanceAnimationFrame() {
                timer.invalidate()
                self.playNextActionSuiteStep()
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
        petView?.settle(status: currentStatus)

        if let queuedSmallAction, !isDragging, !isHovering {
            self.queuedSmallAction = nil
            requestActionSuite(queuedSmallAction, kind: .small, sourceStatus: currentStatus)
            return
        }

        switch finishedKind {
        case .expression:
            scheduleExpressionAction()
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
        case .expression:
            let animations = actionCatalog.animations(for: currentStatus, layer: .expression)
            guard !animations.isEmpty else {
                return []
            }
            defer { expressionCursor += 1 }
            return [animations[expressionCursor % animations.count]]
        case .micro:
            return nextActionSuite(from: ambientPolicy.microActionSuites(for: currentStatus), kind: kind)
        case .small:
            return nextActionSuite(from: ambientPolicy.smallActionSuites(for: currentStatus), kind: kind)
        case .large:
            return nextActionSuite(from: ambientPolicy.largeActionSuites(for: currentStatus), kind: kind)
        case .interaction:
            return hoverSuite()
        }
    }

    private func nextActionSuite(from suites: [[PetAnimation]], kind: PetSchedulerKind) -> [PetAnimation] {
        guard !suites.isEmpty else {
            return []
        }

        switch (currentStatus, kind) {
        case (.working, .small):
            defer { workingSuiteCursor += 1 }
            return suites[workingSuiteCursor % suites.count]
        case (.waiting, .small):
            defer { waitingSuiteCursor += 1 }
            return suites[waitingSuiteCursor % suites.count]
        case (.offline, .small):
            defer { offlineSuiteCursor += 1 }
            return suites[offlineSuiteCursor % suites.count]
        case (.working, .micro):
            defer { workingMicroSuiteCursor += 1 }
            return suites[workingMicroSuiteCursor % suites.count]
        case (.waiting, .micro):
            defer { waitingMicroSuiteCursor += 1 }
            return suites[waitingMicroSuiteCursor % suites.count]
        case (.working, .large):
            defer { workingLargeSuiteCursor += 1 }
            return suites[workingLargeSuiteCursor % suites.count]
        case (.waiting, .large):
            defer { waitingLargeSuiteCursor += 1 }
            return suites[waitingLargeSuiteCursor % suites.count]
        case (.offline, .large), (.offline, .micro), (_, .expression), (_, .interaction):
            return suites[0]
        }
    }

    private func scheduleAction(kind: PetSchedulerKind) {
        switch kind {
        case .expression:
            scheduleExpressionAction()
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
        expressionTimer?.invalidate()
        expressionTimer = nil
        microActionTimer?.invalidate()
        microActionTimer = nil
        smallActionTimer?.invalidate()
        smallActionTimer = nil
        largeActionTimer?.invalidate()
        largeActionTimer = nil
        animationTimer?.invalidate()
        animationTimer = nil
        actionSuite = []
        actionSuiteStep = 0
        activeSchedulerKind = nil
        activeActionLayer = nil
        activeActionPriority = nil
        activeActionReservedUntil = nil
        queuedSmallAction = nil
    }

    private func beginHovering() {
        guard !isDragging else {
            return
        }

        isHovering = true
        lastInteractionAt = Date()
        stopScheduledAndActiveActions()
        requestActionSuite(hoverSuite(), kind: .interaction, sourceStatus: currentStatus)
    }

    private func endHovering() {
        isHovering = false
        lastInteractionAt = Date()
        guard !isDragging else {
            return
        }
        stopScheduledAndActiveActions()
        petView?.settle(status: currentStatus)
        scheduleAllSchedulers(initialDelay: true)
    }

    private func hoverSuite() -> [PetAnimation] {
        switch currentStatus {
        case .working:
            return [.curiousLook, .cursorLook, .hoverSmile]
        case .waiting:
            return [.curiousLook, .cursorLook, .hoverSmile]
        case .offline:
            return [.failed]
        }
    }

    private func beginContextMenuAttention() {
        guard !isDragging else {
            return
        }

        lastInteractionAt = Date()
        stopScheduledAndActiveActions()
        requestActionSuite([.contextMenuAttend], kind: .interaction, sourceStatus: currentStatus)
    }

    private func beginDragging() {
        isDragging = true
        lastInteractionAt = Date()
        stopScheduledAndActiveActions()
    }

    private func endDragging() {
        isDragging = false
        lastInteractionAt = Date()
        requestActionSuite([.dragReleaseSettle], kind: .interaction, sourceStatus: currentStatus)
    }

    private func statusTransitionSuite(from previousStatus: CodexActivityStatus, to status: CodexActivityStatus) -> [PetAnimation] {
        switch (previousStatus, status) {
        case (_, .offline):
            return []
        case (.offline, .waiting):
            return [.wakeUp]
        case (.working, .waiting):
            return [.relaxFace]
        case (.offline, .working):
            return [.wakeUp, .focusTighten]
        case (_, .working):
            return [.focusTighten]
        case (_, .waiting):
            return [.wakeUp]
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
        case .expression:
            return .expression
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

    private func expressionInterval(initialDelay: Bool) -> TimeInterval {
        if initialDelay {
            return TimeInterval.random(in: 2.5...5.0)
        }

        switch currentStatus {
        case .offline:
            return TimeInterval.random(in: 45.0...90.0)
        case .working:
            return TimeInterval.random(in: 4.0...9.0)
        case .waiting:
            return TimeInterval.random(in: 3.0...8.0)
        }
    }

    private func smallActionInterval(initialDelay: Bool) -> TimeInterval {
        if initialDelay {
            return TimeInterval.random(in: 10.0...18.0)
        }

        switch currentStatus {
        case .offline:
            return TimeInterval.random(in: 60.0...120.0)
        case .working:
            return TimeInterval.random(in: 12.0...30.0)
        case .waiting:
            return TimeInterval.random(in: 10.0...25.0)
        }
    }

    private func microActionInterval(initialDelay: Bool) -> TimeInterval {
        if initialDelay {
            return TimeInterval.random(in: 4.0...8.0)
        }

        switch currentStatus {
        case .offline:
            return TimeInterval.random(in: 60.0...120.0)
        case .working:
            return TimeInterval.random(in: 6.0...14.0)
        case .waiting:
            return TimeInterval.random(in: 7.0...16.0)
        }
    }

    private func largeActionInterval(initialDelay: Bool) -> TimeInterval {
        if initialDelay {
            return TimeInterval.random(in: 70.0...120.0)
        }

        switch currentStatus {
        case .offline:
            return TimeInterval.random(in: 120.0...240.0)
        case .working:
            return TimeInterval.random(in: 120.0...210.0)
        case .waiting:
            return TimeInterval.random(in: 90.0...180.0)
        }
    }

    private func initialWindowFrame() -> NSRect {
        let size = NSSize(width: config.displayWidth, height: config.displayHeight + 48)
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSRect(
            x: visibleFrame.maxX - size.width - 24,
            y: visibleFrame.minY + 24,
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

let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
