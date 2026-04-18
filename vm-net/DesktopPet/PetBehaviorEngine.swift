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

    private enum Tuning {
        static let recentTargetHistoryLimit = 6
        static let targetCandidateCount = 18
        static let stepCandidateCount = 12
        static let recentTargetInfluenceRadius: CGFloat = 220
        static let preferredEdgeClearance: CGFloat = 96
    }

    private(set) var profile: DesktopPetBehaviorProfile
    private var isRoamingEnabled: Bool
    private var completedWanderCycles = 0
    private var nextReturnThreshold: Int
    private var migrationTarget: CGPoint?
    private var remainingMigrationSegments = 0
    private var isReturningHome = false
    private var recentWanderTargets: [CGPoint] = []
    private var lastWanderHeading: CGFloat?
    private var migrationTurnBias: CGFloat = 0

    init(
        profile: DesktopPetBehaviorProfile,
        isRoamingEnabled: Bool = true
    ) {
        self.profile = profile
        self.isRoamingEnabled = isRoamingEnabled
        self.nextReturnThreshold = Int.random(in: profile.wanderCycleBeforeHome)
    }

    mutating func reset(
        profile: DesktopPetBehaviorProfile,
        isRoamingEnabled: Bool? = nil
    ) {
        self.profile = profile
        if let isRoamingEnabled {
            self.isRoamingEnabled = isRoamingEnabled
        }
        completedWanderCycles = 0
        nextReturnThreshold = Int.random(in: profile.wanderCycleBeforeHome)
        migrationTarget = nil
        remainingMigrationSegments = 0
        isReturningHome = false
        recentWanderTargets.removeAll()
        lastWanderHeading = nil
        migrationTurnBias = 0
    }

    mutating func setRoamingEnabled(_ isEnabled: Bool) {
        isRoamingEnabled = isEnabled

        if !isEnabled {
            migrationTarget = nil
            remainingMigrationSegments = 0
            isReturningHome = false
            migrationTurnBias = 0
        }
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
        if !isRoamingEnabled {
            return makeRestingPlan(
                from: currentOrigin,
                movementBounds: movementBounds,
                homeOrigin: homeOrigin
            )
        }

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

    mutating func roamingDisabledPlan(
        currentOrigin: CGPoint,
        movementBounds: CGRect,
        homeOrigin: CGPoint?
    ) -> PetBehaviorPlan {
        makeRestingPlan(
            from: currentOrigin,
            movementBounds: movementBounds,
            homeOrigin: homeOrigin
        )
    }

    mutating func roamingEnabledPlan(
        currentOrigin: CGPoint,
        movementBounds: CGRect
    ) -> PetBehaviorPlan {
        resetWanderMemory()

        return makeWanderPlan(
            from: currentOrigin,
            in: movementBounds
        )
    }

    mutating func resetAfterManualRelocation() {
        resetWanderMemory()
        completedWanderCycles = 0
        nextReturnThreshold = Int.random(in: profile.wanderCycleBeforeHome)
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

        rememberWanderStep(to: target, from: currentOrigin)
        remainingMigrationSegments = max(remainingMigrationSegments - 1, 0)
        migrationTurnBias *= remainingMigrationSegments > 0 ? 0.78 : 0.35

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

    private func makeRestingPlan(
        from currentOrigin: CGPoint,
        movementBounds: CGRect,
        homeOrigin: CGPoint?
    ) -> PetBehaviorPlan {
        if let homeOrigin {
            let clampedHomeOrigin = clamp(homeOrigin, to: movementBounds)

            if distance(from: currentOrigin, to: clampedHomeOrigin) <= homeArrivalThreshold {
                return PetBehaviorPlan(
                    state: .restAtHome,
                    destination: clampedHomeOrigin,
                    speed: 0,
                    dwellDuration: TimeInterval.random(in: profile.restAtHomeDuration)
                )
            }

            return PetBehaviorPlan(
                state: .idle,
                destination: clamp(currentOrigin, to: movementBounds),
                speed: 0,
                dwellDuration: returnHomeIdleDuration
            )
        }

        return PetBehaviorPlan(
            state: .idle,
            destination: clamp(currentOrigin, to: movementBounds),
            speed: 0,
            dwellDuration: returnHomeIdleDuration
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
        migrationTurnBias = CGFloat.random(in: (-0.55)...0.55)
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
        var bestScore = -CGFloat.greatestFiniteMagnitude

        for _ in 0..<Tuning.targetCandidateCount {
            let candidate = randomOrigin(in: movementBounds)
            let candidateDistance = distance(from: currentOrigin, to: candidate)
            let headingScore = headingVarietyScore(
                from: currentOrigin,
                to: candidate
            )
            let spacingScore = min(
                nearestRecentTargetDistance(to: candidate),
                Tuning.recentTargetInfluenceRadius
            )
            let score =
                (candidateDistance * 0.012)
                + (spacingScore * 0.01)
                + (headingScore * 82)
                + CGFloat.random(in: (-8)...8)

            if
                candidateDistance >= minimumDistance,
                spacingScore >= Tuning.recentTargetInfluenceRadius * 0.58
            {
                bestCandidate = candidate
                break
            }

            if score > bestScore {
                bestCandidate = candidate
                bestScore = score
            }
        }

        return bestCandidate
    }

    private func randomMigrationStep(
        from currentOrigin: CGPoint,
        toward migrationTarget: CGPoint,
        in movementBounds: CGRect
    ) -> CGPoint {
        let targetHeading = atan2(
            migrationTarget.y - currentOrigin.y,
            migrationTarget.x - currentOrigin.x
        )
        let currentTargetDistance = distance(
            from: currentOrigin,
            to: migrationTarget
        )
        let jitterMagnitude: CGFloat = max(
            abs(profile.migrationHeadingJitter.lowerBound),
            abs(profile.migrationHeadingJitter.upperBound)
        )
        var bestCandidate: CGPoint?
        var bestScore = -CGFloat.greatestFiniteMagnitude

        for _ in 0..<Tuning.stepCandidateCount {
            let baseHeading = curvedHeading(toward: targetHeading)
            let direction = baseHeading + CGFloat.random(
                in: (-jitterMagnitude * 0.8)...(jitterMagnitude * 0.8)
            )
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

            let remainingDistance = distance(from: candidate, to: migrationTarget)
            let progressScore = currentTargetDistance - remainingDistance
            if progressScore <= 8 {
                continue
            }

            let spacingScore = min(
                nearestRecentTargetDistance(to: candidate),
                Tuning.recentTargetInfluenceRadius
            )
            let edgeClearanceScore = min(
                edgeClearance(for: candidate, in: movementBounds),
                Tuning.preferredEdgeClearance
            )
            let continuityScore = headingContinuityScore(direction)
            let score =
                (progressScore * 1.9)
                + (spacingScore * 0.16)
                + (edgeClearanceScore * 0.28)
                + (continuityScore * 18)
                + CGFloat.random(in: (-6)...6)

            if score > bestScore {
                bestCandidate = candidate
                bestScore = score
            }
        }

        if let bestCandidate {
            return bestCandidate
        }

        let fallbackDistance = min(
            CGFloat.random(in: profile.wanderStepDistance),
            distance(from: currentOrigin, to: migrationTarget)
        )
        let fallbackCandidate = CGPoint(
            x: currentOrigin.x + cos(targetHeading) * fallbackDistance,
            y: currentOrigin.y + sin(targetHeading) * fallbackDistance
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
        let jitterMagnitude: CGFloat = max(
            abs(profile.migrationHeadingJitter.lowerBound),
            abs(profile.migrationHeadingJitter.upperBound)
        ) * 0.55
        let jitterRange: ClosedRange<CGFloat> = (-jitterMagnitude)...jitterMagnitude

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

    private mutating func resetWanderMemory() {
        migrationTarget = nil
        remainingMigrationSegments = 0
        isReturningHome = false
        recentWanderTargets.removeAll()
        lastWanderHeading = nil
        migrationTurnBias = 0
    }

    private mutating func rememberWanderStep(
        to destination: CGPoint,
        from currentOrigin: CGPoint
    ) {
        recentWanderTargets.append(destination)
        if recentWanderTargets.count > Tuning.recentTargetHistoryLimit {
            recentWanderTargets.removeFirst(
                recentWanderTargets.count - Tuning.recentTargetHistoryLimit
            )
        }

        lastWanderHeading = atan2(
            destination.y - currentOrigin.y,
            destination.x - currentOrigin.x
        )
    }

    private func nearestRecentTargetDistance(to point: CGPoint) -> CGFloat {
        recentWanderTargets
            .map { distance(from: $0, to: point) }
            .min()
            ?? (Tuning.recentTargetInfluenceRadius * 2)
    }

    private func edgeClearance(
        for point: CGPoint,
        in movementBounds: CGRect
    ) -> CGFloat {
        min(
            point.x - movementBounds.minX,
            movementBounds.maxX - point.x,
            point.y - movementBounds.minY,
            movementBounds.maxY - point.y
        )
    }

    private func headingVarietyScore(
        from currentOrigin: CGPoint,
        to destination: CGPoint
    ) -> CGFloat {
        guard let lastWanderHeading else { return 0.45 }

        let heading = atan2(
            destination.y - currentOrigin.y,
            destination.x - currentOrigin.x
        )
        let delta = abs(normalizedAngle(heading - lastWanderHeading))
        let targetDelta = CGFloat.pi * 0.58

        return max(0, 1 - (abs(delta - targetDelta) / targetDelta))
    }

    private func headingContinuityScore(_ heading: CGFloat) -> CGFloat {
        guard let lastWanderHeading else { return 0.5 }

        let delta = abs(normalizedAngle(heading - lastWanderHeading))
        return 1 - min(delta / CGFloat.pi, 1)
    }

    private func curvedHeading(toward targetHeading: CGFloat) -> CGFloat {
        guard let lastWanderHeading else {
            return targetHeading + migrationTurnBias
        }

        let targetWeight: CGFloat = remainingMigrationSegments > 0 ? 0.58 : 0.72
        let blendedHeading = blendAngle(
            from: lastWanderHeading,
            to: targetHeading,
            weight: targetWeight
        )
        return blendedHeading + migrationTurnBias
    }

    private func blendAngle(
        from startAngle: CGFloat,
        to endAngle: CGFloat,
        weight: CGFloat
    ) -> CGFloat {
        let clampedWeight = min(max(weight, 0), 1)
        let x =
            (cos(startAngle) * (1 - clampedWeight))
            + (cos(endAngle) * clampedWeight)
        let y =
            (sin(startAngle) * (1 - clampedWeight))
            + (sin(endAngle) * clampedWeight)

        return atan2(y, x)
    }

    private func normalizedAngle(_ angle: CGFloat) -> CGFloat {
        var normalized = angle

        while normalized > CGFloat.pi {
            normalized -= CGFloat.pi * 2
        }

        while normalized < -CGFloat.pi {
            normalized += CGFloat.pi * 2
        }

        return normalized
    }
}
