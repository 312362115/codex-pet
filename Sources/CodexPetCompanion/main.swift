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
            (.review, "review")
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

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.clear.setFill()
        dirtyRect.fill()

        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        if let frame = frameProvider.frame(animation: animation, index: frameIndex) {
            context.interpolationQuality = .high
            context.draw(
                frame,
                in: CGRect(
                    x: 0,
                    y: 48,
                    width: config.displayWidth,
                    height: config.displayHeight
                )
            )
        }

        drawStatusPill()
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

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let config = CompanionConfig.standard
    private var window: PetWindow?
    private var petView: PetView?
    private var activityReader: CodexActivityReader?
    private var pollTimer: Timer?
    private var ambientTimer: Timer?
    private var animationTimer: Timer?
    private var currentStatus = CodexActivityStatus.waiting
    private var isDragging = false
    private var isPlayingAmbientAction = false
    private let ambientPolicy = PetAmbientActionPolicy()

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
            scheduleAmbientAction()
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

        currentStatus = status
        stopAmbientAnimation()
        if !isDragging {
            petView?.settle(status: status)
            scheduleAmbientAction()
        }
    }

    private func scheduleAmbientAction() {
        ambientTimer?.invalidate()
        guard !isDragging else {
            return
        }

        let interval = TimeInterval.random(in: 7.0...16.0)
        ambientTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.playAmbientAction()
        }
    }

    private func playAmbientAction() {
        guard !isDragging, !isPlayingAmbientAction, let petView else {
            scheduleAmbientAction()
            return
        }

        let candidates = ambientPolicy.ambientAnimations(for: currentStatus)
        guard let animation = candidates.randomElement() else {
            scheduleAmbientAction()
            return
        }

        isPlayingAmbientAction = true
        petView.play(animation: animation)
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { [weak self] timer in
            guard let self, let petView = self.petView else {
                timer.invalidate()
                return
            }

            if petView.advanceAnimationFrame() {
                timer.invalidate()
                self.isPlayingAmbientAction = false
                petView.settle(status: self.currentStatus)
                self.scheduleAmbientAction()
            }
        }
    }

    private func stopAmbientAnimation() {
        ambientTimer?.invalidate()
        ambientTimer = nil
        animationTimer?.invalidate()
        animationTimer = nil
        isPlayingAmbientAction = false
    }

    private func beginDragging() {
        isDragging = true
        stopAmbientAnimation()
    }

    private func endDragging() {
        isDragging = false
        petView?.settle(status: currentStatus)
        scheduleAmbientAction()
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
