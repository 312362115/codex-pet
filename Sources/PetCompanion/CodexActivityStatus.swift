import Foundation

public enum CodexActivityStatus: Hashable, Sendable {
    case offline
    case working
    case waiting
}

public enum CodexWorkPhase: String, Hashable, Sendable {
    case offline
    case idle
    case thinking
    case runningTool
    case waitingUser
    case blocked
    case completed
    case longWorking

    public var presentationState: PetPresentationState {
        switch self {
        case .offline:
            return .offlineRest
        case .idle:
            return .idleRelaxed
        case .thinking:
            return .reviewFocused
        case .runningTool:
            return .toolRunning
        case .waitingUser:
            return .waitingAttentive
        case .blocked:
            return .blockedConcerned
        case .completed:
            return .completedCalm
        case .longWorking:
            return .longWorkTired
        }
    }
}

public enum PetPresentationState: String, Hashable, Sendable {
    case offlineRest
    case idleRelaxed
    case reviewFocused
    case toolRunning
    case waitingAttentive
    case blockedConcerned
    case completedCalm
    case longWorkTired

    public var coarseStatus: CodexActivityStatus {
        switch self {
        case .offlineRest:
            return .offline
        case .idleRelaxed, .waitingAttentive, .completedCalm:
            return .waiting
        case .reviewFocused, .toolRunning, .blockedConcerned, .longWorkTired:
            return .working
        }
    }

    public var statusText: String {
        switch self {
        case .offlineRest:
            return "Codex 离线"
        case .idleRelaxed:
            return "Codex 待命"
        case .reviewFocused:
            return "正在思考"
        case .toolRunning:
            return "运行工具中"
        case .waitingAttentive:
            return "等待你确认"
        case .blockedConcerned:
            return "遇到错误"
        case .completedCalm:
            return "这轮完成"
        case .longWorkTired:
            return "连续工作中"
        }
    }
}

public extension CodexActivityStatus {
    var defaultPresentationState: PetPresentationState {
        switch self {
        case .offline:
            return .offlineRest
        case .working:
            return .reviewFocused
        case .waiting:
            return .waitingAttentive
        }
    }
}

public enum PetBehaviorProfile: String, Hashable, Sendable {
    case officeCompanion
    case manekiNeko
}

public struct PetAssetSpec: Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let highResolutionFrameDirectoryName: String
    public let spriteSheetDirectoryName: String
    public let rigAssetDirectoryName: String?
    public let behaviorProfile: PetBehaviorProfile

    public init(
        id: String,
        displayName: String,
        highResolutionFrameDirectoryName: String,
        spriteSheetDirectoryName: String,
        rigAssetDirectoryName: String? = nil,
        behaviorProfile: PetBehaviorProfile = .officeCompanion
    ) {
        self.id = id
        self.displayName = displayName
        self.highResolutionFrameDirectoryName = highResolutionFrameDirectoryName
        self.spriteSheetDirectoryName = spriteSheetDirectoryName
        self.rigAssetDirectoryName = rigAssetDirectoryName
        self.behaviorProfile = behaviorProfile
    }
}

public struct PetCatalog: Sendable {
    public let pets: [PetAssetSpec]

    public init(pets: [PetAssetSpec] = Self.defaultPets) {
        self.pets = pets.isEmpty ? Self.defaultPets : pets
    }

    public var defaultPet: PetAssetSpec {
        pets[0]
    }

    public func pet(withID id: String) -> PetAssetSpec? {
        pets.first { $0.id == id }
    }

    public func selectedPet(for id: String?) -> PetAssetSpec {
        guard let id, let pet = pet(withID: id) else {
            return defaultPet
        }
        return pet
    }

    public static let defaultPets: [PetAssetSpec] = [
        PetAssetSpec(
            id: "lingxi-ol",
            displayName: "Lingxi OL",
            highResolutionFrameDirectoryName: "lingxi-ol-hires",
            spriteSheetDirectoryName: "lingxi-ol",
            rigAssetDirectoryName: "lingxi-ol-rig"
        ),
        PetAssetSpec(
            id: "maneki-neko",
            displayName: "招财猫",
            highResolutionFrameDirectoryName: "maneki-neko-hires",
            spriteSheetDirectoryName: "maneki-neko",
            behaviorProfile: .manekiNeko
        )
    ]
}

public struct PetPresentationTransitionPolicy: Sendable {
    public init() {}

    public func canSwitch(
        from currentState: PetPresentationState,
        currentStateSince: Date,
        to candidateState: PetPresentationState,
        candidateStateSince: Date,
        now: Date
    ) -> Bool {
        if candidateState == currentState {
            return true
        }

        if isUrgent(candidateState) {
            return true
        }

        let currentDwell = now.timeIntervalSince(currentStateSince)
        guard currentDwell >= minimumDwellDuration(for: currentState) else {
            return false
        }

        let candidateDwell = now.timeIntervalSince(candidateStateSince)
        return candidateDwell >= confirmationDelay(from: currentState, to: candidateState)
    }

    public func minimumDwellDuration(for state: PetPresentationState) -> TimeInterval {
        switch state {
        case .offlineRest:
            return 2
        case .idleRelaxed:
            return 8
        case .reviewFocused:
            return 10
        case .toolRunning:
            return 10
        case .waitingAttentive:
            return 8
        case .blockedConcerned:
            return 8
        case .completedCalm:
            return 6
        case .longWorkTired:
            return 20
        }
    }

    public func confirmationDelay(
        from currentState: PetPresentationState,
        to candidateState: PetPresentationState
    ) -> TimeInterval {
        switch candidateState {
        case .offlineRest, .blockedConcerned, .longWorkTired:
            return 0
        case .completedCalm:
            return 1.5
        case .reviewFocused, .toolRunning:
            return currentState == .idleRelaxed ? 1 : 2
        case .waitingAttentive, .idleRelaxed:
            return 5
        }
    }

    private func isUrgent(_ state: PetPresentationState) -> Bool {
        state == .offlineRest || state == .blockedConcerned
    }
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

public enum PetSchedulerKind: String, Hashable, Sendable {
    case micro
    case small
    case large
    case interaction
}

public enum PetHoverBeginDecision: Equatable, Sendable {
    case startHoverInteraction
    case deferToActiveInteraction
}

public struct PetRuntimeSchedulingPolicy: Sendable {
    public init() {}

    public func hoverBeginDecision(
        activeSchedulerKind: PetSchedulerKind?,
        activeActionLayer: PetActionLayer?
    ) -> PetHoverBeginDecision {
        if activeSchedulerKind == .interaction || activeActionLayer == .interaction {
            return .deferToActiveInteraction
        }
        return .startHoverInteraction
    }

    public func shouldScheduleAmbientActions(
        isDragging: Bool,
        isHovering: Bool,
        hasActiveAction: Bool,
        hasValidAmbientTimer: Bool
    ) -> Bool {
        !isDragging && !isHovering && !hasActiveAction && !hasValidAmbientTimer
    }
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
        PetActionDescriptor(animation: .blink, layer: .expression, priority: .p3, allowedStatuses: activeStatuses, expressions: [.neutral, .focused], cooldown: 3...8, canQueue: false, defaultEligible: false),
        PetActionDescriptor(animation: .slowBlink, layer: .expression, priority: .p3, allowedStatuses: allStatuses, expressions: [.happy, .tired, .neutral], cooldown: 20...45, canQueue: false, defaultEligible: false),
        PetActionDescriptor(animation: .eyeShiftLeft, layer: .expression, priority: .p3, allowedStatuses: activeStatuses, expressions: [.neutral, .focused, .curious], cooldown: 8...20, canQueue: false, defaultEligible: false),
        PetActionDescriptor(animation: .eyeShiftRight, layer: .expression, priority: .p3, allowedStatuses: activeStatuses, expressions: [.neutral, .focused, .curious], cooldown: 8...20, canQueue: false, defaultEligible: false),
        PetActionDescriptor(animation: .focusTighten, layer: .expression, priority: .p1, allowedStatuses: [.working], expressions: [.focused], cooldown: 8...18, canQueue: false, defaultEligible: false),
        PetActionDescriptor(animation: .relaxFace, layer: .expression, priority: .p1, allowedStatuses: [.waiting], expressions: [.neutral], cooldown: 8...18, canQueue: false, defaultEligible: false),
        PetActionDescriptor(animation: .smallSmile, layer: .expression, priority: .p3, allowedStatuses: [.waiting], expressions: [.happy], cooldown: 25...60, canQueue: false, defaultEligible: false),
        PetActionDescriptor(animation: .tiredSoften, layer: .expression, priority: .p3, allowedStatuses: [.waiting], expressions: [.tired], cooldown: 60...120, canQueue: false, defaultEligible: false),
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
        PetActionDescriptor(animation: .hoverSmile, layer: .interaction, priority: .p1, allowedStatuses: activeStatuses, expressions: [.happy], cooldown: 2...5, canQueue: false, defaultEligible: false),
        PetActionDescriptor(animation: .contextMenuAttend, layer: .interaction, priority: .p1, allowedStatuses: allStatuses, expressions: [.curious], cooldown: 0...1, canQueue: false, defaultEligible: false),
        PetActionDescriptor(animation: .dragReleaseSettle, layer: .interaction, priority: .p0, allowedStatuses: allStatuses, expressions: [.neutral], cooldown: 0...1, canQueue: false),
        PetActionDescriptor(animation: .wakeUp, layer: .interaction, priority: .p1, allowedStatuses: [.waiting], expressions: [.neutral, .curious], cooldown: 0...1, canQueue: false),
        PetActionDescriptor(animation: .turning, layer: .debug, priority: .p4, allowedStatuses: activeStatuses, expressions: [.neutral], cooldown: 0...0, canQueue: false, defaultEligible: false),
        PetActionDescriptor(animation: .jumping, layer: .debug, priority: .p4, allowedStatuses: activeStatuses, expressions: [.neutral], cooldown: 0...0, canQueue: false, defaultEligible: false)
    ]
}

public struct PetActionRequest: Equatable, Sendable {
    public let animation: PetAnimation
    public let sourcePresentationState: PetPresentationState
    public let submittedAt: Date
    public let layer: PetActionLayer
    public let priority: PetActionPriority
    public let canQueue: Bool

    public init(
        animation: PetAnimation,
        sourcePresentationState: PetPresentationState,
        submittedAt: Date,
        catalog: PetActionCatalog = PetActionCatalog()
    ) {
        let descriptor = catalog.descriptor(for: animation)
        self.animation = animation
        self.sourcePresentationState = sourcePresentationState
        self.submittedAt = submittedAt
        self.layer = descriptor?.layer ?? .small
        self.priority = descriptor?.priority ?? .p2
        self.canQueue = descriptor?.canQueue ?? false
    }
}

public struct PetActionTimelineState: Equatable, Sendable {
    public let currentPresentationState: PetPresentationState
    public let currentLayer: PetActionLayer?
    public let currentPriority: PetActionPriority?
    public let reservedUntil: Date?
    public let isDragging: Bool
    public let isHovering: Bool
    public let lastStatusChangeAt: Date?
    public let lastInteractionAt: Date?

    public init(
        currentPresentationState: PetPresentationState,
        currentLayer: PetActionLayer?,
        currentPriority: PetActionPriority?,
        reservedUntil: Date?,
        isDragging: Bool,
        isHovering: Bool,
        lastStatusChangeAt: Date?,
        lastInteractionAt: Date?
    ) {
        self.currentPresentationState = currentPresentationState
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

        if request.sourcePresentationState != state.currentPresentationState && request.priority.rawValue > PetActionPriority.p1.rawValue {
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

public struct CodexMetadataSnapshot: Equatable, Sendable {
    public let codexIsRunning: Bool
    public let latestActivityDate: Date?
    public let activeThreadUpdatedAt: Date?
    public let hasRecentUserEvent: Bool
    public let hasRunningJob: Bool
    public let hasPendingJob: Bool
    public let hasRecentToolEvent: Bool
    public let hasRecentFailedJob: Bool
    public let hasRecentCompletedJob: Bool
    public let hasActiveGoal: Bool
    public let hasRecentCompletedGoal: Bool
    public let hasRecentError: Bool
    public let continuousActiveDuration: TimeInterval?
    public let now: Date
    public let activeThreshold: TimeInterval
    public let waitingThreshold: TimeInterval
    public let longWorkingThreshold: TimeInterval

    public init(
        codexIsRunning: Bool,
        latestActivityDate: Date?,
        activeThreadUpdatedAt: Date? = nil,
        hasRecentUserEvent: Bool = false,
        hasRunningJob: Bool = false,
        hasPendingJob: Bool = false,
        hasRecentToolEvent: Bool = false,
        hasRecentFailedJob: Bool = false,
        hasRecentCompletedJob: Bool = false,
        hasActiveGoal: Bool = false,
        hasRecentCompletedGoal: Bool = false,
        hasRecentError: Bool = false,
        continuousActiveDuration: TimeInterval? = nil,
        now: Date,
        activeThreshold: TimeInterval = 8,
        waitingThreshold: TimeInterval = 90,
        longWorkingThreshold: TimeInterval = 50 * 60
    ) {
        self.codexIsRunning = codexIsRunning
        self.latestActivityDate = latestActivityDate
        self.activeThreadUpdatedAt = activeThreadUpdatedAt
        self.hasRecentUserEvent = hasRecentUserEvent
        self.hasRunningJob = hasRunningJob
        self.hasPendingJob = hasPendingJob
        self.hasRecentToolEvent = hasRecentToolEvent
        self.hasRecentFailedJob = hasRecentFailedJob
        self.hasRecentCompletedJob = hasRecentCompletedJob
        self.hasActiveGoal = hasActiveGoal
        self.hasRecentCompletedGoal = hasRecentCompletedGoal
        self.hasRecentError = hasRecentError
        self.continuousActiveDuration = continuousActiveDuration
        self.now = now
        self.activeThreshold = activeThreshold
        self.waitingThreshold = waitingThreshold
        self.longWorkingThreshold = longWorkingThreshold
    }
}

public struct CodexWorkPhaseClassifier: Sendable {
    public init() {}

    public func classify(_ snapshot: CodexMetadataSnapshot) -> CodexWorkPhase {
        guard snapshot.codexIsRunning else {
            return .offline
        }

        if snapshot.hasRecentError || snapshot.hasRecentFailedJob {
            return .blocked
        }

        if let continuousActiveDuration = snapshot.continuousActiveDuration,
           continuousActiveDuration >= snapshot.longWorkingThreshold {
            return .longWorking
        }

        if snapshot.hasRunningJob || snapshot.hasPendingJob || snapshot.hasRecentToolEvent {
            return .runningTool
        }

        if snapshot.hasRecentCompletedJob || snapshot.hasRecentCompletedGoal {
            return .completed
        }

        let latestUserVisibleActivity = [
            snapshot.activeThreadUpdatedAt,
            snapshot.latestActivityDate
        ].compactMap { $0 }.max()
        guard let latestUserVisibleActivity else {
            return snapshot.hasActiveGoal ? .thinking : .idle
        }

        let activityAge = snapshot.now.timeIntervalSince(latestUserVisibleActivity)
        if activityAge <= snapshot.activeThreshold {
            return .thinking
        }

        if activityAge <= snapshot.waitingThreshold || snapshot.hasRecentUserEvent {
            return .waitingUser
        }

        return snapshot.hasActiveGoal ? .thinking : .idle
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

public struct PetWindowPlacementSize: Equatable, Sendable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct PetWindowPlacementPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct PetWindowPlacementRect: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct PetWindowPlacementPolicy: Sendable {
    public let margin: Double

    public init(margin: Double = 24) {
        self.margin = margin
    }

    public func initialOrigin(
        visibleFrame: PetWindowPlacementRect,
        windowSize: PetWindowPlacementSize
    ) -> PetWindowPlacementPoint {
        let horizontalMargin = windowSize.width + margin <= visibleFrame.width ? margin : 0
        let verticalMargin = windowSize.height + margin <= visibleFrame.height ? margin : 0
        return PetWindowPlacementPoint(
            x: visibleFrame.x + horizontalMargin,
            y: visibleFrame.y + verticalMargin
        )
    }
}

public enum PetRenderMode: Hashable, Sendable {
    case frameClip
    case spriteKitRigMotion
}

public struct PetRenderModePolicy {
    public init() {}

    public func renderMode(for animation: PetAnimation) -> PetRenderMode {
        switch animation {
        case .breathing, .hairSway, .weightShift, .shoulderRelax, .cursorLook, .dragReleaseSettle, .wakeUp:
            return .spriteKitRigMotion
        case .idle, .running, .waiting, .failed, .waving, .jumping, .review, .turning, .glanceLeft, .glanceRight,
             .blink, .slowBlink, .eyeShiftLeft, .eyeShiftRight, .focusTighten, .relaxFace, .smallSmile, .tiredSoften,
             .curiousLook, .tinyHandAdjust, .thinking, .adjustGlasses,
             .nod, .tapKeyboard, .checkNotes, .stretchWrist, .hoverSmile, .contextMenuAttend,
             .focusShift, .fixPosture, .adjustOutfit, .lookAround, .stretch, .stepAside, .postureReset:
            return .frameClip
        }
    }

    public func usesSpriteKitRig(_ animation: PetAnimation) -> Bool {
        renderMode(for: animation) == .spriteKitRigMotion
    }
}

public struct PetAmbientActionPolicy {
    public let profile: PetBehaviorProfile

    public init(profile: PetBehaviorProfile = .officeCompanion) {
        self.profile = profile
    }

    public func restingAnimation(for presentationState: PetPresentationState) -> PetAnimation {
        if profile == .manekiNeko {
            switch presentationState {
            case .offlineRest:
                return .failed
            case .idleRelaxed, .reviewFocused, .toolRunning, .waitingAttentive, .longWorkTired:
                return .waiting
            case .blockedConcerned:
                return .failed
            case .completedCalm:
                return .nod
            }
        }

        switch presentationState {
        case .offlineRest:
            return .failed
        case .idleRelaxed:
            return .idle
        case .reviewFocused:
            return .review
        case .toolRunning:
            return .tapKeyboard
        case .waitingAttentive:
            return .waiting
        case .blockedConcerned:
            return .failed
        case .completedCalm:
            return .nod
        case .longWorkTired:
            return .stretchWrist
        }
    }

    public func restingFrameIndex(for presentationState: PetPresentationState, frameCount: Int) -> Int {
        let safeFrameCount = max(1, frameCount)
        let progress: Double
        switch presentationState {
        case .offlineRest:
            progress = 0.55
        case .idleRelaxed:
            progress = 0.25
        case .reviewFocused:
            progress = 0.40
        case .toolRunning:
            progress = 0.55
        case .waitingAttentive:
            progress = 0.10
        case .blockedConcerned:
            progress = 0.70
        case .completedCalm:
            progress = 0.65
        case .longWorkTired:
            progress = 0.55
        }
        return min(safeFrameCount - 1, max(0, Int(Double(safeFrameCount - 1) * progress)))
    }

    public func restingAnimation(for status: CodexActivityStatus) -> PetAnimation {
        restingAnimation(for: status.defaultPresentationState)
    }

    public func ambientAnimations(for status: CodexActivityStatus) -> [PetAnimation] {
        smallActionSuites(for: status).flatMap { $0 }
    }

    public func ambientSuites(for status: CodexActivityStatus) -> [[PetAnimation]] {
        smallActionSuites(for: status)
    }

    public func microActionSuites(for presentationState: PetPresentationState) -> [[PetAnimation]] {
        if profile == .manekiNeko {
            switch presentationState {
            case .offlineRest:
                return []
            case .idleRelaxed, .waitingAttentive:
                return [[.hairSway], [.breathing], [.slowBlink]]
            case .reviewFocused, .toolRunning:
                return [[.hairSway], [.breathing], [.slowBlink]]
            case .blockedConcerned:
                return [[.breathing], [.slowBlink]]
            case .completedCalm:
                return [[.hairSway], [.breathing], [.slowBlink]]
            case .longWorkTired:
                return [[.hairSway], [.breathing], [.slowBlink]]
            }
        }

        switch presentationState {
        case .offlineRest:
            return []
        case .idleRelaxed:
            return [[.breathing], [.weightShift], [.shoulderRelax], [.hairSway]]
        case .waitingAttentive:
            return [[.breathing], [.weightShift], [.shoulderRelax], [.tinyHandAdjust], [.hairSway]]
        case .reviewFocused:
            return [[.breathing], [.tinyHandAdjust], [.hairSway]]
        case .toolRunning:
            return [[.tinyHandAdjust], [.hairSway]]
        case .blockedConcerned:
            return [[.shoulderRelax]]
        case .completedCalm:
            return [[.breathing], [.shoulderRelax]]
        case .longWorkTired:
            return [[.shoulderRelax], [.tinyHandAdjust]]
        }
    }

    public func microActionSuites(for status: CodexActivityStatus) -> [[PetAnimation]] {
        microActionSuites(for: status.defaultPresentationState)
    }

    public func smallActionSuites(for presentationState: PetPresentationState) -> [[PetAnimation]] {
        if profile == .manekiNeko {
            switch presentationState {
            case .offlineRest:
                return []
            case .idleRelaxed, .waitingAttentive:
                return [[.waving], [.waving], [.cursorLook], [.nod]]
            case .reviewFocused, .toolRunning:
                return [[.cursorLook], [.glanceLeft], [.glanceRight], [.nod]]
            case .blockedConcerned:
                return [[.glanceLeft], [.glanceRight]]
            case .completedCalm:
                return [[.waving], [.nod]]
            case .longWorkTired:
                return [[.glanceLeft], [.glanceRight], [.nod]]
            }
        }

        switch presentationState {
        case .offlineRest:
            return []
        case .idleRelaxed:
            return [[.waving], [.nod], [.cursorLook], [.tinyHandAdjust], [.adjustOutfit]]
        case .waitingAttentive:
            return [[.cursorLook], [.waving], [.nod], [.tinyHandAdjust], [.adjustOutfit]]
        case .reviewFocused:
            return [[.adjustGlasses], [.thinking], [.nod], [.tapKeyboard], [.checkNotes], [.stretchWrist]]
        case .toolRunning:
            return [[.tapKeyboard], [.checkNotes], [.focusShift]]
        case .blockedConcerned:
            return [[.glanceLeft], [.glanceRight], [.shoulderRelax]]
        case .completedCalm:
            return [[.nod], [.waving], [.shoulderRelax]]
        case .longWorkTired:
            return [[.stretchWrist], [.shoulderRelax], [.fixPosture]]
        }
    }

    public func smallActionSuites(for status: CodexActivityStatus) -> [[PetAnimation]] {
        smallActionSuites(for: status.defaultPresentationState)
    }

    public func largeActionSuites(for presentationState: PetPresentationState) -> [[PetAnimation]] {
        if profile == .manekiNeko {
            switch presentationState {
            case .offlineRest:
                return []
            case .idleRelaxed, .waitingAttentive:
                return [[.lookAround], [.glanceLeft], [.glanceRight]]
            case .reviewFocused, .toolRunning:
                return [[.glanceLeft], [.glanceRight], [.lookAround]]
            case .blockedConcerned:
                return [[.glanceLeft], [.glanceRight]]
            case .completedCalm:
                return [[.glanceLeft], [.glanceRight], [.lookAround]]
            case .longWorkTired:
                return [[.lookAround]]
            }
        }

        switch presentationState {
        case .offlineRest:
            return []
        case .idleRelaxed:
            return [[.lookAround], [.postureReset], [.stretch], [.stepAside]]
        case .waitingAttentive:
            return [[.glanceLeft], [.glanceRight], [.adjustOutfit], [.lookAround], [.fixPosture], [.stepAside], [.postureReset], [.stretch]]
        case .reviewFocused:
            return [[.glanceLeft], [.glanceRight], [.focusShift], [.fixPosture], [.postureReset], [.stretch]]
        case .toolRunning:
            return [[.focusShift], [.fixPosture]]
        case .blockedConcerned:
            return [[.glanceLeft], [.glanceRight]]
        case .completedCalm:
            return [[.shoulderRelax], [.postureReset]]
        case .longWorkTired:
            return [[.stretch], [.postureReset]]
        }
    }

    public func largeActionSuites(for status: CodexActivityStatus) -> [[PetAnimation]] {
        largeActionSuites(for: status.defaultPresentationState)
    }

    public func hoverActionSuites(for presentationState: PetPresentationState) -> [[PetAnimation]] {
        if profile == .manekiNeko {
            switch presentationState {
            case .offlineRest:
                return [[.failed]]
            case .idleRelaxed, .waitingAttentive:
                return [[.waving], [.cursorLook], [.hairSway], [.slowBlink]]
            case .reviewFocused, .toolRunning:
                return [[.cursorLook], [.glanceLeft], [.glanceRight], [.slowBlink]]
            case .blockedConcerned:
                return [[.glanceLeft], [.glanceRight]]
            case .completedCalm:
                return [[.waving], [.nod], [.slowBlink]]
            case .longWorkTired:
                return [[.lookAround], [.hairSway], [.slowBlink]]
            }
        }

        switch presentationState {
        case .offlineRest:
            return [[.failed]]
        case .idleRelaxed:
            return [[.wakeUp], [.waving], [.lookAround]]
        case .waitingAttentive:
            return [[.cursorLook], [.waving]]
        case .reviewFocused:
            return [[.adjustGlasses], [.thinking]]
        case .toolRunning:
            return [[.tapKeyboard], [.focusShift], [.checkNotes]]
        case .blockedConcerned:
            return [[.glanceLeft, .glanceRight]]
        case .completedCalm:
            return [[.nod], [.shoulderRelax]]
        case .longWorkTired:
            return [[.stretchWrist], [.shoulderRelax], [.fixPosture]]
        }
    }

    public func hoverActionSuites(for status: CodexActivityStatus) -> [[PetAnimation]] {
        hoverActionSuites(for: status.defaultPresentationState)
    }
}

public struct PetSchedulerIntervalRange: Equatable, Sendable {
    public let lowerBound: TimeInterval
    public let upperBound: TimeInterval

    public init(_ lowerBound: TimeInterval, _ upperBound: TimeInterval) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    public func randomInterval() -> TimeInterval {
        TimeInterval.random(in: lowerBound...upperBound)
    }
}

public struct PetActionSchedulerIntervalPolicy: Sendable {
    public let profile: PetBehaviorProfile

    public init(profile: PetBehaviorProfile = .officeCompanion) {
        self.profile = profile
    }

    public func smallActionIntervalRange(
        for presentationState: PetPresentationState,
        initialDelay: Bool
    ) -> PetSchedulerIntervalRange {
        if profile == .manekiNeko {
            if initialDelay {
                return PetSchedulerIntervalRange(3, 6)
            }

            switch presentationState {
            case .offlineRest:
                return PetSchedulerIntervalRange(45, 90)
            case .reviewFocused, .toolRunning:
                return PetSchedulerIntervalRange(14, 24)
            case .blockedConcerned, .completedCalm, .longWorkTired:
                return PetSchedulerIntervalRange(16, 30)
            case .idleRelaxed, .waitingAttentive:
                return PetSchedulerIntervalRange(12, 22)
            }
        }

        if initialDelay {
            return PetSchedulerIntervalRange(24, 36)
        }

        switch presentationState {
        case .offlineRest:
            return PetSchedulerIntervalRange(75, 140)
        case .reviewFocused, .toolRunning:
            return PetSchedulerIntervalRange(45, 75)
        case .blockedConcerned, .completedCalm, .longWorkTired:
            return PetSchedulerIntervalRange(50, 90)
        case .idleRelaxed, .waitingAttentive:
            return PetSchedulerIntervalRange(55, 90)
        }
    }

    public func microActionIntervalRange(
        for presentationState: PetPresentationState,
        initialDelay: Bool
    ) -> PetSchedulerIntervalRange {
        if profile == .manekiNeko {
            if initialDelay {
                return PetSchedulerIntervalRange(2, 4)
            }

            switch presentationState {
            case .offlineRest:
                return PetSchedulerIntervalRange(45, 90)
            case .reviewFocused, .toolRunning:
                return PetSchedulerIntervalRange(8, 14)
            case .blockedConcerned, .completedCalm, .longWorkTired:
                return PetSchedulerIntervalRange(10, 18)
            case .idleRelaxed, .waitingAttentive:
                return PetSchedulerIntervalRange(7, 12)
            }
        }

        if initialDelay {
            return PetSchedulerIntervalRange(10, 16)
        }

        switch presentationState {
        case .offlineRest:
            return PetSchedulerIntervalRange(60, 120)
        case .reviewFocused, .toolRunning:
            return PetSchedulerIntervalRange(22, 38)
        case .blockedConcerned, .completedCalm, .longWorkTired:
            return PetSchedulerIntervalRange(30, 50)
        case .idleRelaxed, .waitingAttentive:
            return PetSchedulerIntervalRange(28, 46)
        }
    }

    public func largeActionIntervalRange(
        for presentationState: PetPresentationState,
        initialDelay: Bool
    ) -> PetSchedulerIntervalRange {
        if profile == .manekiNeko {
            if initialDelay {
                return PetSchedulerIntervalRange(8, 14)
            }

            switch presentationState {
            case .offlineRest:
                return PetSchedulerIntervalRange(90, 160)
            case .reviewFocused, .toolRunning:
                return PetSchedulerIntervalRange(32, 55)
            case .blockedConcerned, .completedCalm, .longWorkTired:
                return PetSchedulerIntervalRange(38, 70)
            case .idleRelaxed, .waitingAttentive:
                return PetSchedulerIntervalRange(30, 50)
            }
        }

        if initialDelay {
            return PetSchedulerIntervalRange(75, 110)
        }

        switch presentationState {
        case .offlineRest:
            return PetSchedulerIntervalRange(180, 300)
        case .reviewFocused, .toolRunning:
            return PetSchedulerIntervalRange(180, 300)
        case .blockedConcerned, .completedCalm, .longWorkTired:
            return PetSchedulerIntervalRange(150, 240)
        case .idleRelaxed, .waitingAttentive:
            return PetSchedulerIntervalRange(150, 240)
        }
    }
}
