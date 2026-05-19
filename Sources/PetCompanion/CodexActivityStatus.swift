import Foundation

public enum CodexActivityStatus: Hashable, Sendable {
    case offline
    case working
    case waiting
}

public enum PetAnimation: String, Hashable, Sendable {
    case idle
    case running
    case waiting
    case failed
    case waving
    case jumping
    case review
    case turning
    case glanceLeft
    case glanceRight
    case blink
    case slowBlink
    case eyeShiftLeft
    case eyeShiftRight
    case focusTighten
    case relaxFace
    case smallSmile
    case tiredSoften
    case curiousLook
    case breathing
    case hairSway
    case weightShift
    case shoulderRelax
    case tinyHandAdjust
    case thinking
    case adjustGlasses
    case nod
    case tapKeyboard
    case checkNotes
    case stretchWrist
    case cursorLook
    case hoverSmile
    case contextMenuAttend
    case focusShift
    case fixPosture
    case adjustOutfit
    case lookAround
    case stretch
    case stepAside
    case postureReset
    case dragReleaseSettle
    case wakeUp
}

public enum PetExpression: String, Hashable, Sendable {
    case neutral
    case focused
    case thinking
    case curious
    case happy
    case tired
    case error
}

public enum PetActionLayer: String, Hashable, Sendable {
    case pose
    case expression
    case micro
    case small
    case medium
    case large
    case interaction
    case debug
}

public enum PetActionPriority: Int, Hashable, Sendable {
    case p0 = 0
    case p1 = 1
    case p2 = 2
    case p3 = 3
    case p4 = 4
}

public enum PetActionRequestOutcome: String, Hashable, Sendable {
    case playNow
    case queue
    case merge
    case drop
}

public struct PetActionDescriptor: Equatable, Sendable {
    public let animation: PetAnimation
    public let layer: PetActionLayer
    public let priority: PetActionPriority
    public let allowedStatuses: Set<CodexActivityStatus>
    public let expressions: [PetExpression]
    public let cooldown: ClosedRange<TimeInterval>
    public let canQueue: Bool
    public let defaultEligible: Bool

    public init(
        animation: PetAnimation,
        layer: PetActionLayer,
        priority: PetActionPriority,
        allowedStatuses: Set<CodexActivityStatus>,
        expressions: [PetExpression],
        cooldown: ClosedRange<TimeInterval>,
        canQueue: Bool,
        defaultEligible: Bool = true
    ) {
        self.animation = animation
        self.layer = layer
        self.priority = priority
        self.allowedStatuses = allowedStatuses
        self.expressions = expressions
        self.cooldown = cooldown
        self.canQueue = canQueue
        self.defaultEligible = defaultEligible
    }
}

public struct PetActionCatalog: Sendable {
    private let descriptors: [PetActionDescriptor]

    public init() {
        self.descriptors = Self.defaultDescriptors
    }

    public func descriptor(for animation: PetAnimation) -> PetActionDescriptor? {
        descriptors.first { $0.animation == animation }
    }

    public func animations(for status: CodexActivityStatus, layer: PetActionLayer) -> [PetAnimation] {
        descriptors
            .filter { descriptor in
                descriptor.defaultEligible
                    && descriptor.layer == layer
                    && descriptor.allowedStatuses.contains(status)
            }
            .map(\.animation)
    }

    private static let allStatuses: Set<CodexActivityStatus> = [.offline, .working, .waiting]
    private static let activeStatuses: Set<CodexActivityStatus> = [.working, .waiting]

    private static let defaultDescriptors: [PetActionDescriptor] = [
        PetActionDescriptor(animation: .idle, layer: .pose, priority: .p2, allowedStatuses: [.waiting], expressions: [.neutral], cooldown: 0...0, canQueue: false),
        PetActionDescriptor(animation: .waiting, layer: .pose, priority: .p2, allowedStatuses: [.waiting], expressions: [.neutral], cooldown: 0...0, canQueue: false),
        PetActionDescriptor(animation: .review, layer: .pose, priority: .p2, allowedStatuses: [.working], expressions: [.focused], cooldown: 0...0, canQueue: false),
        PetActionDescriptor(animation: .failed, layer: .pose, priority: .p2, allowedStatuses: [.offline], expressions: [.error], cooldown: 0...0, canQueue: false),
        PetActionDescriptor(animation: .blink, layer: .expression, priority: .p3, allowedStatuses: activeStatuses, expressions: [.neutral, .focused], cooldown: 3...8, canQueue: false),
        PetActionDescriptor(animation: .slowBlink, layer: .expression, priority: .p3, allowedStatuses: [.waiting, .offline], expressions: [.tired, .neutral], cooldown: 20...45, canQueue: false),
        PetActionDescriptor(animation: .eyeShiftLeft, layer: .expression, priority: .p3, allowedStatuses: activeStatuses, expressions: [.neutral, .focused, .curious], cooldown: 8...20, canQueue: false),
        PetActionDescriptor(animation: .eyeShiftRight, layer: .expression, priority: .p3, allowedStatuses: activeStatuses, expressions: [.neutral, .focused, .curious], cooldown: 8...20, canQueue: false),
        PetActionDescriptor(animation: .focusTighten, layer: .expression, priority: .p1, allowedStatuses: [.working], expressions: [.focused], cooldown: 8...18, canQueue: false, defaultEligible: false),
        PetActionDescriptor(animation: .relaxFace, layer: .expression, priority: .p1, allowedStatuses: [.waiting], expressions: [.neutral], cooldown: 8...18, canQueue: false, defaultEligible: false),
        PetActionDescriptor(animation: .smallSmile, layer: .expression, priority: .p3, allowedStatuses: [.waiting], expressions: [.happy], cooldown: 25...60, canQueue: false),
        PetActionDescriptor(animation: .tiredSoften, layer: .expression, priority: .p3, allowedStatuses: [.waiting], expressions: [.tired], cooldown: 60...120, canQueue: false),
        PetActionDescriptor(animation: .curiousLook, layer: .expression, priority: .p1, allowedStatuses: activeStatuses, expressions: [.curious], cooldown: 10...20, canQueue: false, defaultEligible: false),
        PetActionDescriptor(animation: .breathing, layer: .micro, priority: .p3, allowedStatuses: activeStatuses, expressions: [.neutral, .focused], cooldown: 4...10, canQueue: false),
        PetActionDescriptor(animation: .hairSway, layer: .micro, priority: .p3, allowedStatuses: activeStatuses, expressions: [.neutral], cooldown: 12...30, canQueue: false),
        PetActionDescriptor(animation: .weightShift, layer: .micro, priority: .p3, allowedStatuses: [.waiting], expressions: [.neutral, .tired], cooldown: 12...30, canQueue: false),
        PetActionDescriptor(animation: .shoulderRelax, layer: .micro, priority: .p3, allowedStatuses: [.working, .waiting], expressions: [.neutral, .focused], cooldown: 20...45, canQueue: false),
        PetActionDescriptor(animation: .tinyHandAdjust, layer: .micro, priority: .p3, allowedStatuses: activeStatuses, expressions: [.focused], cooldown: 20...45, canQueue: false),
        PetActionDescriptor(animation: .adjustGlasses, layer: .small, priority: .p2, allowedStatuses: [.working], expressions: [.focused], cooldown: 30...60, canQueue: true),
        PetActionDescriptor(animation: .thinking, layer: .small, priority: .p2, allowedStatuses: [.working], expressions: [.thinking], cooldown: 24...50, canQueue: true),
        PetActionDescriptor(animation: .nod, layer: .small, priority: .p2, allowedStatuses: [.working], expressions: [.focused], cooldown: 20...45, canQueue: true),
        PetActionDescriptor(animation: .tapKeyboard, layer: .small, priority: .p2, allowedStatuses: [.working], expressions: [.focused], cooldown: 30...60, canQueue: true),
        PetActionDescriptor(animation: .checkNotes, layer: .small, priority: .p2, allowedStatuses: [.working], expressions: [.thinking], cooldown: 35...70, canQueue: true),
        PetActionDescriptor(animation: .stretchWrist, layer: .small, priority: .p2, allowedStatuses: [.working], expressions: [.focused], cooldown: 60...120, canQueue: true),
        PetActionDescriptor(animation: .waving, layer: .small, priority: .p2, allowedStatuses: [.waiting], expressions: [.happy, .curious], cooldown: 40...90, canQueue: true),
        PetActionDescriptor(animation: .running, layer: .small, priority: .p2, allowedStatuses: activeStatuses, expressions: [.focused], cooldown: 45...90, canQueue: true, defaultEligible: false),
        PetActionDescriptor(animation: .glanceLeft, layer: .medium, priority: .p4, allowedStatuses: activeStatuses, expressions: [.curious], cooldown: 45...90, canQueue: false),
        PetActionDescriptor(animation: .glanceRight, layer: .medium, priority: .p4, allowedStatuses: activeStatuses, expressions: [.curious], cooldown: 45...90, canQueue: false),
        PetActionDescriptor(animation: .focusShift, layer: .medium, priority: .p4, allowedStatuses: [.working], expressions: [.focused, .curious], cooldown: 60...120, canQueue: false),
        PetActionDescriptor(animation: .fixPosture, layer: .medium, priority: .p4, allowedStatuses: activeStatuses, expressions: [.neutral, .focused], cooldown: 60...120, canQueue: false),
        PetActionDescriptor(animation: .adjustOutfit, layer: .medium, priority: .p4, allowedStatuses: [.waiting], expressions: [.neutral], cooldown: 90...150, canQueue: false),
        PetActionDescriptor(animation: .lookAround, layer: .large, priority: .p4, allowedStatuses: [.waiting], expressions: [.curious], cooldown: 90...180, canQueue: false),
        PetActionDescriptor(animation: .stretch, layer: .large, priority: .p4, allowedStatuses: activeStatuses, expressions: [.tired, .neutral], cooldown: 120...240, canQueue: false),
        PetActionDescriptor(animation: .stepAside, layer: .large, priority: .p4, allowedStatuses: [.waiting], expressions: [.neutral], cooldown: 180...300, canQueue: false),
        PetActionDescriptor(animation: .postureReset, layer: .large, priority: .p4, allowedStatuses: activeStatuses, expressions: [.neutral, .focused], cooldown: 90...180, canQueue: false),
        PetActionDescriptor(animation: .cursorLook, layer: .interaction, priority: .p1, allowedStatuses: activeStatuses, expressions: [.curious], cooldown: 2...5, canQueue: false),
        PetActionDescriptor(animation: .hoverSmile, layer: .interaction, priority: .p1, allowedStatuses: activeStatuses, expressions: [.happy], cooldown: 2...5, canQueue: false),
        PetActionDescriptor(animation: .contextMenuAttend, layer: .interaction, priority: .p1, allowedStatuses: allStatuses, expressions: [.curious], cooldown: 0...1, canQueue: false),
        PetActionDescriptor(animation: .dragReleaseSettle, layer: .interaction, priority: .p0, allowedStatuses: allStatuses, expressions: [.neutral], cooldown: 0...1, canQueue: false),
        PetActionDescriptor(animation: .wakeUp, layer: .interaction, priority: .p1, allowedStatuses: [.waiting], expressions: [.neutral, .curious], cooldown: 0...1, canQueue: false),
        PetActionDescriptor(animation: .turning, layer: .debug, priority: .p4, allowedStatuses: activeStatuses, expressions: [.neutral], cooldown: 0...0, canQueue: false, defaultEligible: false),
        PetActionDescriptor(animation: .jumping, layer: .debug, priority: .p4, allowedStatuses: activeStatuses, expressions: [.neutral], cooldown: 0...0, canQueue: false, defaultEligible: false)
    ]
}

public struct PetActionRequest: Equatable, Sendable {
    public let animation: PetAnimation
    public let sourceStatus: CodexActivityStatus
    public let submittedAt: Date
    public let layer: PetActionLayer
    public let priority: PetActionPriority
    public let canQueue: Bool

    public init(
        animation: PetAnimation,
        sourceStatus: CodexActivityStatus,
        submittedAt: Date,
        catalog: PetActionCatalog = PetActionCatalog()
    ) {
        let descriptor = catalog.descriptor(for: animation)
        self.animation = animation
        self.sourceStatus = sourceStatus
        self.submittedAt = submittedAt
        self.layer = descriptor?.layer ?? .small
        self.priority = descriptor?.priority ?? .p2
        self.canQueue = descriptor?.canQueue ?? false
    }
}

public struct PetActionTimelineState: Equatable, Sendable {
    public let currentStatus: CodexActivityStatus
    public let currentLayer: PetActionLayer?
    public let currentPriority: PetActionPriority?
    public let reservedUntil: Date?
    public let isDragging: Bool
    public let isHovering: Bool
    public let lastStatusChangeAt: Date?
    public let lastInteractionAt: Date?

    public init(
        currentStatus: CodexActivityStatus,
        currentLayer: PetActionLayer?,
        currentPriority: PetActionPriority?,
        reservedUntil: Date?,
        isDragging: Bool,
        isHovering: Bool,
        lastStatusChangeAt: Date?,
        lastInteractionAt: Date?
    ) {
        self.currentStatus = currentStatus
        self.currentLayer = currentLayer
        self.currentPriority = currentPriority
        self.reservedUntil = reservedUntil
        self.isDragging = isDragging
        self.isHovering = isHovering
        self.lastStatusChangeAt = lastStatusChangeAt
        self.lastInteractionAt = lastInteractionAt
    }
}

public struct PetActionDecision: Equatable, Sendable {
    public let outcome: PetActionRequestOutcome
    public let animation: PetAnimation

    public init(outcome: PetActionRequestOutcome, animation: PetAnimation) {
        self.outcome = outcome
        self.animation = animation
    }
}

public struct PetActionTimeline: Sendable {
    public init() {}

    public func decide(request: PetActionRequest, state: PetActionTimelineState) -> PetActionDecision {
        if state.isDragging && request.priority != .p0 {
            return PetActionDecision(outcome: .drop, animation: request.animation)
        }

        if request.sourceStatus != state.currentStatus && request.priority.rawValue > PetActionPriority.p1.rawValue {
            return PetActionDecision(outcome: .drop, animation: request.animation)
        }

        if state.currentLayer == .expression && request.layer == .expression {
            return PetActionDecision(outcome: .merge, animation: request.animation)
        }

        let now = request.submittedAt
        let timelineIsBusy = state.reservedUntil.map { $0 > now } ?? false
        let busyWithMicroAction = timelineIsBusy && state.currentLayer == .micro

        if request.layer == .large {
            if (timelineIsBusy && !busyWithMicroAction) || state.isHovering {
                return PetActionDecision(outcome: .drop, animation: request.animation)
            }
            if let lastInteractionAt = state.lastInteractionAt, now.timeIntervalSince(lastInteractionAt) < 8 {
                return PetActionDecision(outcome: .drop, animation: request.animation)
            }
            if let lastStatusChangeAt = state.lastStatusChangeAt, now.timeIntervalSince(lastStatusChangeAt) < 10 {
                return PetActionDecision(outcome: .drop, animation: request.animation)
            }
        }

        if busyWithMicroAction && request.layer != .micro {
            return PetActionDecision(outcome: .playNow, animation: request.animation)
        }

        guard timelineIsBusy else {
            return PetActionDecision(outcome: .playNow, animation: request.animation)
        }

        if request.priority.rawValue <= PetActionPriority.p1.rawValue {
            return PetActionDecision(outcome: .playNow, animation: request.animation)
        }

        if request.layer == .expression && state.currentLayer != .large {
            return PetActionDecision(outcome: .playNow, animation: request.animation)
        }

        if request.canQueue && request.layer == .small && state.currentLayer == .small {
            return PetActionDecision(outcome: .queue, animation: request.animation)
        }

        return PetActionDecision(outcome: .drop, animation: request.animation)
    }
}

public struct CodexActivitySnapshot: Equatable {
    public let codexIsRunning: Bool
    public let latestActivityDate: Date?
    public let now: Date
    public let activeThreshold: TimeInterval
    public let waitingThreshold: TimeInterval

    public init(
        codexIsRunning: Bool,
        latestActivityDate: Date?,
        now: Date,
        activeThreshold: TimeInterval = 8,
        waitingThreshold: TimeInterval = 90
    ) {
        self.codexIsRunning = codexIsRunning
        self.latestActivityDate = latestActivityDate
        self.now = now
        self.activeThreshold = activeThreshold
        self.waitingThreshold = waitingThreshold
    }
}

public struct CodexActivityClassifier {
    public init() {}

    public func classify(_ snapshot: CodexActivitySnapshot) -> CodexActivityStatus {
        guard snapshot.codexIsRunning else {
            return .offline
        }

        guard let latestActivityDate = snapshot.latestActivityDate else {
            return .waiting
        }

        let age = snapshot.now.timeIntervalSince(latestActivityDate)
        if age <= snapshot.activeThreshold {
            return .working
        }

        if age >= snapshot.waitingThreshold {
            return .waiting
        }

        return .waiting
    }
}

public struct PetAnimationMapper {
    public init() {}

    public func animation(for status: CodexActivityStatus) -> PetAnimation {
        switch status {
        case .offline:
            return .failed
        case .working:
            return .running
        case .waiting:
            return .waiting
        }
    }
}

public struct PetAnimationFramePolicy {
    public init() {}

    public func frameCount(for animation: PetAnimation) -> Int {
        switch animation {
        case .idle:
            return 10
        case .running:
            return 24
        case .waiting:
            return 10
        case .failed:
            return 10
        case .waving:
            return 24
        case .jumping:
            return 8
        case .review:
            return 10
        case .turning:
            return 25
        case .glanceLeft, .glanceRight:
            return 16
        case .blink:
            return 5
        case .slowBlink:
            return 8
        case .eyeShiftLeft, .eyeShiftRight:
            return 8
        case .focusTighten, .relaxFace, .smallSmile, .tiredSoften, .curiousLook, .hoverSmile, .contextMenuAttend, .dragReleaseSettle:
            return 12
        case .breathing, .hairSway:
            return 12
        case .weightShift, .shoulderRelax, .tinyHandAdjust:
            return 16
        case .thinking, .adjustGlasses, .tapKeyboard, .checkNotes, .stretchWrist, .focusShift, .fixPosture, .adjustOutfit:
            return 24
        case .nod, .cursorLook:
            return 16
        case .lookAround, .stretch, .stepAside, .postureReset:
            return 32
        case .wakeUp:
            return 20
        }
    }
}

public struct PetAnimationTimingPolicy {
    public init() {}

    public func totalDuration(for animation: PetAnimation) -> TimeInterval {
        switch animation {
        case .turning:
            return 3.24
        case .glanceLeft, .glanceRight:
            return 1.6
        case .blink:
            return 0.25
        case .slowBlink:
            return 0.7
        case .eyeShiftLeft, .eyeShiftRight:
            return 0.8
        case .focusTighten, .relaxFace, .smallSmile, .tiredSoften, .curiousLook, .hoverSmile, .contextMenuAttend:
            return 1.0
        case .breathing, .hairSway:
            return 1.2
        case .weightShift, .shoulderRelax, .tinyHandAdjust:
            return 1.6
        case .thinking, .adjustGlasses, .tapKeyboard, .checkNotes, .stretchWrist, .focusShift, .fixPosture, .adjustOutfit:
            return 2.4
        case .nod, .cursorLook:
            return 1.6
        case .lookAround, .postureReset:
            return 3.2
        case .stretch, .stepAside:
            return 3.6
        case .dragReleaseSettle:
            return 1.0
        case .wakeUp:
            return 2.0
        case .idle, .running, .waiting, .failed, .waving, .jumping, .review:
            return 2.4
        }
    }

    public func frameInterval(for animation: PetAnimation, frameCount: Int) -> TimeInterval {
        totalDuration(for: animation) / TimeInterval(max(1, frameCount))
    }
}

public struct PetMotionPolicy {
    public init() {}

    public func loopsContinuously(animation: PetAnimation) -> Bool {
        false
    }
}

public struct PetAmbientActionPolicy {
    public init() {}

    public func restingAnimation(for status: CodexActivityStatus) -> PetAnimation {
        switch status {
        case .offline:
            return .failed
        case .working:
            return .review
        case .waiting:
            return .waiting
        }
    }

    public func ambientAnimations(for status: CodexActivityStatus) -> [PetAnimation] {
        smallActionSuites(for: status).flatMap { $0 }
    }

    public func ambientSuites(for status: CodexActivityStatus) -> [[PetAnimation]] {
        smallActionSuites(for: status)
    }

    public func microActionSuites(for status: CodexActivityStatus) -> [[PetAnimation]] {
        switch status {
        case .offline:
            return []
        case .working:
            return [[.breathing], [.eyeShiftLeft], [.eyeShiftRight], [.tinyHandAdjust], [.hairSway]]
        case .waiting:
            return [[.breathing], [.weightShift], [.eyeShiftLeft], [.eyeShiftRight], [.shoulderRelax], [.tinyHandAdjust], [.hairSway]]
        }
    }

    public func smallActionSuites(for status: CodexActivityStatus) -> [[PetAnimation]] {
        switch status {
        case .offline:
            return []
        case .working:
            return [
                [.adjustGlasses],
                [.thinking],
                [.nod],
                [.tapKeyboard],
                [.checkNotes],
                [.stretchWrist]
            ]
        case .waiting:
            return [
                [.waving],
                [.smallSmile],
                [.slowBlink]
            ]
        }
    }

    public func largeActionSuites(for status: CodexActivityStatus) -> [[PetAnimation]] {
        switch status {
        case .offline:
            return []
        case .working:
            return [[.glanceLeft], [.glanceRight], [.focusShift], [.fixPosture], [.postureReset], [.stretch]]
        case .waiting:
            return [[.glanceLeft], [.glanceRight], [.adjustOutfit], [.lookAround], [.postureReset], [.stretch], [.stepAside]]
        }
    }
}
