//
//  PetBehaviorEngine.swift
//  vm-net
//
//  Created by Codex on 2026/4/16.
//

import AppKit

enum PetBehaviorState {
    case idle
    case wander
    case goHome
    case restAtHome

    var isMoving: Bool {
        switch self {
        case .wander, .goHome:
            return true
        case .idle, .restAtHome:
            return false
        }
    }
}

struct PetBehaviorPlan {
    let state: PetBehaviorState
    let destination: CGPoint
    let speed: CGFloat
    let dwellDuration: TimeInterval?
}

struct PetBehaviorEngine {

    private(set) var profile: DesktopPetBehaviorProfile
    private var completedWanderCycles = 0
    private var nextReturnThreshold: Int
    private var migrationTarget: CGPoint?
    private var remainingMigrationSegments = 0
    private var isReturningHome = false

    init(profile: DesktopPetBehaviorProfile) {
        self.profile = profile
        self.nextReturnThreshold = Int.random(in: profile.wanderCycleBeforeHome)
    }

    mutating func reset(profile: DesktopPetBehaviorProfile) {
        self.profile = profile
        completedWanderCycles = 0
        nextReturnThreshold = Int.random(in: profile.wanderCycleBeforeHome)
        migrationTarget = nil
        remainingMigrationSegments = 0
        isReturningHome = false
    }

    mutating func initialPlan(
        movementBounds: CGRect,
        homeOrigin: CGPoint?
    ) -> PetBehaviorPlan {
        if let homeOrigin {
            return PetBehaviorPlan(
                state: .restAtHome,
                destination: clamp(homeOrigin, to: movementBounds),
                speed: 0,
                dwellDuration: TimeInterval.random(in: profile.restAtHomeDuration)
            )
        }

        return PetBehaviorPlan(
            state: .idle,
            destination: randomOrigin(in: movementBounds),
            speed: 0,
            dwellDuration: wanderIdleDuration
        )
    }

    mutating func nextPlan(
        after state: PetBehaviorState,
        currentOrigin: CGPoint,
        movementBounds: CGRect,
        homeOrigin: CGPoint?
    ) -> PetBehaviorPlan {
        switch state {
        case .restAtHome:
            return makeWanderPlan(
                from: currentOrigin,
                in: movementBounds
            )

        case .idle:
            if
                isReturningHome,
                let homeOrigin
            {
                let clampedHomeOrigin = clamp(homeOrigin, to: movementBounds)

                if distance(from: currentOrigin, to: clampedHomeOrigin)
                    <= homeArrivalThreshold
                {
                    completedWanderCycles = 0
                    nextReturnThreshold = Int.random(in: profile.wanderCycleBeforeHome)
                    migrationTarget = nil
                    remainingMigrationSegments = 0
                    isReturningHome = false
                    return PetBehaviorPlan(
                        state: .restAtHome,
                        destination: clampedHomeOrigin,
                        speed: 0,
                        dwellDuration: TimeInterval.random(in: profile.restAtHomeDuration)
                    )
                }

                return makeHomewardPlan(
                    from: currentOrigin,
                    homeOrigin: clampedHomeOrigin,
                    in: movementBounds
                )
            }

            if
                let homeOrigin,
                completedWanderCycles >= nextReturnThreshold
            {
                migrationTarget = nil
                remainingMigrationSegments = 0
                isReturningHome = true
                return makeHomewardPlan(
                    from: currentOrigin,
                    homeOrigin: clamp(homeOrigin, to: movementBounds),
                    in: movementBounds
                )
            }

            return makeWanderPlan(
                from: currentOrigin,
                in: movementBounds
            )

        case .wander:
            completedWanderCycles += 1
            return PetBehaviorPlan(
                state: .idle,
                destination: clamp(currentOrigin, to: movementBounds),
                speed: 0,
                dwellDuration: wanderIdleDuration
            )

        case .goHome:
            return PetBehaviorPlan(
                state: .idle,
                destination: clamp(currentOrigin, to: movementBounds),
                speed: 0,
                dwellDuration: returnHomeIdleDuration
            )
        }
    }

    private mutating func makeWanderPlan(
        from currentOrigin: CGPoint,
        in movementBounds: CGRect
    ) -> PetBehaviorPlan {
        let finalTarget = resolveMigrationTarget(
            from: currentOrigin,
            in: movementBounds
        )
        var target = randomMigrationStep(
            from: currentOrigin,
            toward: finalTarget,
            in: movementBounds
        )

        for _ in 0..<4 where distance(from: currentOrigin, to: target) < 56 {
            target = randomMigrationStep(
                from: currentOrigin,
                toward: finalTarget,
                in: movementBounds
            )
        }

        remainingMigrationSegments = max(remainingMigrationSegments - 1, 0)

        return PetBehaviorPlan(
            state: .wander,
            destination: target,
            speed: CGFloat.random(in: profile.movementSpeed),
            dwellDuration: nil
        )
    }

    private func makeHomewardPlan(
        from currentOrigin: CGPoint,
        homeOrigin: CGPoint,
        in movementBounds: CGRect
    ) -> PetBehaviorPlan {
        let clampedHomeOrigin = clamp(homeOrigin, to: movementBounds)
        let target: CGPoint

        if distance(from: currentOrigin, to: clampedHomeOrigin) <= homeArrivalThreshold {
            target = clampedHomeOrigin
        } else {
            var candidate = randomHomewardStep(
                from: currentOrigin,
                toward: clampedHomeOrigin,
                in: movementBounds
            )

            for _ in 0..<4 where distance(from: currentOrigin, to: candidate) < 44 {
                candidate = randomHomewardStep(
                    from: currentOrigin,
                    toward: clampedHomeOrigin,
                    in: movementBounds
                )
            }

            target = candidate
        }

        return PetBehaviorPlan(
            state: .goHome,
            destination: target,
            speed: CGFloat.random(in: profile.movementSpeed),
            dwellDuration: nil
        )
    }

    private func randomOrigin(in movementBounds: CGRect) -> CGPoint {
        CGPoint(
            x: CGFloat.random(in: movementBounds.minX...movementBounds.maxX),
            y: CGFloat.random(in: movementBounds.minY...movementBounds.maxY)
        )
    }

    private mutating func resolveMigrationTarget(
        from currentOrigin: CGPoint,
        in movementBounds: CGRect
    ) -> CGPoint {
        if
            let migrationTarget,
            remainingMigrationSegments > 0,
            distance(from: currentOrigin, to: migrationTarget)
                > profile.migrationTargetArrivalThreshold
        {
            return migrationTarget
        }

        let target = randomMigrationTarget(
            from: currentOrigin,
            in: movementBounds
        )
        migrationTarget = target
        remainingMigrationSegments = Int.random(
            in: profile.migrationRetargetAfterSegments
        )
        return target
    }

    private func randomMigrationTarget(
        from currentOrigin: CGPoint,
        in movementBounds: CGRect
    ) -> CGPoint {
        let minimumDistance = min(
            max(profile.wanderStepDistance.upperBound * 2.5, 260),
            max(min(movementBounds.width, movementBounds.height) * 0.82, 140)
        )

        var bestCandidate = randomOrigin(in: movementBounds)
        var bestDistance = distance(from: currentOrigin, to: bestCandidate)

        for _ in 0..<8 {
            let candidate = randomOrigin(in: movementBounds)
            let candidateDistance = distance(from: currentOrigin, to: candidate)

            if candidateDistance >= minimumDistance {
                return candidate
            }

            if candidateDistance > bestDistance {
                bestCandidate = candidate
                bestDistance = candidateDistance
            }
        }

        return bestCandidate
    }

    private func randomMigrationStep(
        from currentOrigin: CGPoint,
        toward migrationTarget: CGPoint,
        in movementBounds: CGRect
    ) -> CGPoint {
        let heading = atan2(
            migrationTarget.y - currentOrigin.y,
            migrationTarget.x - currentOrigin.x
        )

        for _ in 0..<5 {
            let direction = heading + CGFloat.random(in: profile.migrationHeadingJitter)
            let stepDistance = CGFloat.random(in: profile.wanderStepDistance)
            let candidate = clamp(
                CGPoint(
                    x: currentOrigin.x + cos(direction) * stepDistance,
                    y: currentOrigin.y + sin(direction) * stepDistance
                ),
                to: movementBounds
            )

            let stepProgress = distance(from: currentOrigin, to: candidate)
            if stepProgress < 40 {
                continue
            }

            if distance(from: candidate, to: migrationTarget)
                < distance(from: currentOrigin, to: migrationTarget)
            {
                return candidate
            }
        }

        let fallbackDistance = min(
            CGFloat.random(in: profile.wanderStepDistance),
            distance(from: currentOrigin, to: migrationTarget)
        )
        let fallbackCandidate = CGPoint(
            x: currentOrigin.x + cos(heading) * fallbackDistance,
            y: currentOrigin.y + sin(heading) * fallbackDistance
        )
        return clamp(fallbackCandidate, to: movementBounds)
    }

    private func randomHomewardStep(
        from currentOrigin: CGPoint,
        toward homeOrigin: CGPoint,
        in movementBounds: CGRect
    ) -> CGPoint {
        let heading = atan2(
            homeOrigin.y - currentOrigin.y,
            homeOrigin.x - currentOrigin.x
        )
        let jitterMagnitude = max(
            abs(profile.migrationHeadingJitter.lowerBound),
            abs(profile.migrationHeadingJitter.upperBound)
        ) * 0.55
        let jitterRange = (-jitterMagnitude)...jitterMagnitude

        for _ in 0..<5 {
            let direction = heading + CGFloat.random(in: jitterRange)
            let stepDistance = min(
                CGFloat.random(in: profile.wanderStepDistance),
                distance(from: currentOrigin, to: homeOrigin)
            )
            let candidate = clamp(
                CGPoint(
                    x: currentOrigin.x + cos(direction) * stepDistance,
                    y: currentOrigin.y + sin(direction) * stepDistance
                ),
                to: movementBounds
            )

            let stepProgress = distance(from: currentOrigin, to: candidate)
            if stepProgress < 32 {
                continue
            }

            if distance(from: candidate, to: homeOrigin)
                < distance(from: currentOrigin, to: homeOrigin)
            {
                return candidate
            }
        }

        let fallbackDistance = min(
            CGFloat.random(in: profile.wanderStepDistance),
            distance(from: currentOrigin, to: homeOrigin)
        )
        let fallbackCandidate = CGPoint(
            x: currentOrigin.x + cos(heading) * fallbackDistance,
            y: currentOrigin.y + sin(heading) * fallbackDistance
        )
        return clamp(fallbackCandidate, to: movementBounds)
    }

    private var homeArrivalThreshold: CGFloat {
        max(
            profile.arrivalThreshold * 4,
            profile.wanderStepDistance.lowerBound * 0.65
        )
    }

    private var wanderIdleDuration: TimeInterval {
        let lowerBound = profile.idleDuration.lowerBound * 4
        let upperBound = profile.idleDuration.upperBound * 4
        return TimeInterval.random(in: lowerBound...upperBound)
    }

    private var returnHomeIdleDuration: TimeInterval {
        let lowerBound = profile.idleDuration.lowerBound * 1.45
        let upperBound = profile.idleDuration.upperBound * 1.95
        return TimeInterval.random(in: lowerBound...upperBound)
    }

    private func clamp(_ point: CGPoint, to movementBounds: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, movementBounds.minX), movementBounds.maxX),
            y: min(max(point.y, movementBounds.minY), movementBounds.maxY)
        )
    }

    private func distance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        hypot(rhs.x - lhs.x, rhs.y - lhs.y)
    }
}
