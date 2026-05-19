import Foundation

public enum CodexActivityStatus: Equatable {
    case offline
    case working
    case waiting
}

public enum PetAnimation: String, Equatable {
    case idle
    case running
    case waiting
    case failed
    case waving
    case jumping
    case review
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
            return 10
        case .waiting:
            return 10
        case .failed:
            return 10
        case .waving:
            return 10
        case .jumping:
            return 8
        case .review:
            return 10
        }
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
        ambientSuites(for: status).flatMap { $0 }
    }

    public func ambientSuites(for status: CodexActivityStatus) -> [[PetAnimation]] {
        switch status {
        case .offline:
            return [[.failed]]
        case .working:
            return [
                [.review, .running, .review],
                [.review]
            ]
        case .waiting:
            return [
                [.waiting, .idle, .waiting],
                [.waiting]
            ]
        }
    }
}
