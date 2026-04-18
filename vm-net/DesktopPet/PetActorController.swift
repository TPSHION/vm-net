//
//  PetActorController.swift
//  vm-net
//
//  Created by Codex on 2026/4/16.
//

import AppKit

@MainActor
final class PetActorController {

    private enum Timing {
        static let movingTickInterval: TimeInterval = 1.0 / 20.0
        static let idleTickInterval: TimeInterval = 0.25
        static let timerToleranceRatio: Double = 0.25
    }

    var view: NSView {
        renderer.view
    }
    var originDidChange: ((CGPoint) -> Void)?
    var viewDidChange: ((NSView) -> Void)?

    private(set) var asset: DesktopPetAsset

    private var renderer: PetRenderer
    private var behaviorEngine: PetBehaviorEngine
    private weak var parentView: NSView?
    private var tickTimer: Timer?
    private var movementBounds: CGRect = .zero
    private var homeOrigin: CGPoint?
    private var currentOrigin = CGPoint.zero
    private var destinationOrigin = CGPoint.zero
    private var currentSpeed: CGFloat = 0
    private var state: PetBehaviorState = .restAtHome
    private var stateDeadline: Date?
    private var movementStartDate: Date?
    private var hasInitializedPlan = false
    private var isRoamingEnabled = true
    private var isManualDragActive = false
    private var currentTickInterval: TimeInterval?
    private var lastReportedOrigin: CGPoint?

    init(
        asset: DesktopPetAsset,
        isRoamingEnabled: Bool = true
    ) {
        self.asset = asset
        self.isRoamingEnabled = isRoamingEnabled
        self.renderer = PetRendererFactory.makeRenderer(for: asset)
        self.behaviorEngine = PetBehaviorEngine(
            profile: asset.behavior,
            isRoamingEnabled: isRoamingEnabled
        )
    }

    var eventCaptureFrameInParent: CGRect {
        renderer.eventCaptureRectInSelf
    }

    deinit {
        tickTimer?.invalidate()
    }

    func attach(to parentView: NSView) {
        self.parentView = parentView

        guard view.superview !== parentView else { return }

        view.removeFromSuperview()
        view.frame = CGRect(origin: .zero, size: asset.layout.panelSize)
        parentView.addSubview(view)
        syncFrame()
    }

    func applyAsset(_ asset: DesktopPetAsset) {
        let previousCenter = CGPoint(
            x: currentOrigin.x + (self.asset.layout.panelSize.width / 2),
            y: currentOrigin.y + (self.asset.layout.panelSize.height / 2)
        )

        self.asset = asset
        behaviorEngine.reset(
            profile: asset.behavior,
            isRoamingEnabled: isRoamingEnabled
        )
        replaceRenderer(for: asset)

        currentOrigin = CGPoint(
            x: previousCenter.x - (asset.layout.panelSize.width / 2),
            y: previousCenter.y - (asset.layout.panelSize.height / 2)
        )
        hasInitializedPlan = false

        if movementBounds != .zero {
            movementBounds = clampedMovementBounds(movementBounds)
            currentOrigin = clampedOrigin(currentOrigin)
            destinationOrigin = clampedOrigin(destinationOrigin)
        }

        syncFrame()
        ensurePlanIfPossible()
    }

    func setRoamingEnabled(_ isEnabled: Bool) {
        isRoamingEnabled = isEnabled
        behaviorEngine.setRoamingEnabled(isEnabled)

        guard hasInitializedPlan, movementBounds != .zero else { return }

        if !isEnabled {
            let plan = behaviorEngine.roamingDisabledPlan(
                currentOrigin: currentOrigin,
                movementBounds: movementBounds,
                homeOrigin: homeOrigin
            )
            apply(plan)
            return
        }

        let plan = behaviorEngine.roamingEnabledPlan(
            currentOrigin: currentOrigin,
            movementBounds: movementBounds
        )
        apply(plan)
    }

    func updateEnvironment(
        movementBounds: CGRect,
        homeOrigin: CGPoint?
    ) {
        self.movementBounds = clampedMovementBounds(movementBounds)
        let previousHomeOrigin = self.homeOrigin
        let resolvedHomeOrigin = homeOrigin.map(clampedOrigin(_:))
        self.homeOrigin = resolvedHomeOrigin
        currentOrigin = clampedOrigin(currentOrigin)

        switch state {
        case .restAtHome:
            if let resolvedHomeOrigin {
                currentOrigin = resolvedHomeOrigin
                destinationOrigin = resolvedHomeOrigin
            } else {
                destinationOrigin = clampedOrigin(destinationOrigin)
            }
        case .goHome:
            destinationOrigin = clampedOrigin(
                resolvedHomeOrigin ?? destinationOrigin
            )
        case .idle, .wander:
            if !isRoamingEnabled, let resolvedHomeOrigin {
                currentOrigin = resolvedHomeOrigin
                destinationOrigin = resolvedHomeOrigin
            } else if
                let previousHomeOrigin,
                let resolvedHomeOrigin,
                destinationOrigin == previousHomeOrigin
            {
                destinationOrigin = resolvedHomeOrigin
            } else {
                destinationOrigin = clampedOrigin(destinationOrigin)
            }
        }

        syncFrame()
        ensurePlanIfPossible()
    }

    func start() {
        renderer.setAmbientInteractionEnabled(true)
        ensurePlanIfPossible()
        scheduleTickTimerIfNeeded(force: true)
    }

    func stop() {
        tickTimer?.invalidate()
        tickTimer = nil
        currentTickInterval = nil
        movementStartDate = nil
        renderer.setAmbientInteractionEnabled(false)
    }

    private func ensurePlanIfPossible() {
        guard !hasInitializedPlan, movementBounds != .zero else { return }

        let plan = behaviorEngine.initialPlan(
            movementBounds: movementBounds,
            homeOrigin: homeOrigin
        )
        apply(plan)
        hasInitializedPlan = true
    }

    @objc
    private func handleTickTimer() {
        tick()
    }

    private func tick() {
        guard hasInitializedPlan, movementBounds != .zero else { return }
        guard !renderer.hasActiveInteraction, !isManualDragActive else { return }

        if state.isMoving {
            if let movementStartDate, Date() < movementStartDate {
                return
            }
            self.movementStartDate = nil
            advanceMovement(
                by: currentTickInterval ?? Timing.movingTickInterval
            )
            return
        }

        if let stateDeadline, Date() >= stateDeadline {
            let nextPlan = behaviorEngine.nextPlan(
                after: state,
                currentOrigin: currentOrigin,
                movementBounds: movementBounds,
                homeOrigin: homeOrigin
            )
            apply(nextPlan)
        }
    }

    private func advanceMovement(by deltaTime: TimeInterval) {
        let dx = destinationOrigin.x - currentOrigin.x
        let dy = destinationOrigin.y - currentOrigin.y
        let distance = hypot(dx, dy)

        if distance <= asset.behavior.arrivalThreshold {
            currentOrigin = destinationOrigin
            syncFrame()
            arrive()
            return
        }

        let step = currentSpeed * CGFloat(deltaTime)
        if step >= distance {
            currentOrigin = destinationOrigin
        } else {
            currentOrigin.x += (dx / distance) * step
            currentOrigin.y += (dy / distance) * step
        }

        syncFrame()

        if hypot(destinationOrigin.x - currentOrigin.x, destinationOrigin.y - currentOrigin.y)
            <= asset.behavior.arrivalThreshold {
            currentOrigin = destinationOrigin
            syncFrame()
            arrive()
        }
    }

    private func arrive() {
        let nextPlan = behaviorEngine.nextPlan(
            after: state,
            currentOrigin: currentOrigin,
            movementBounds: movementBounds,
            homeOrigin: homeOrigin
        )
        apply(nextPlan)
    }

    private func apply(_ plan: PetBehaviorPlan) {
        state = plan.state
        destinationOrigin = clampedOrigin(plan.destination)
        currentSpeed = plan.speed
        let movementVector = CGVector(
            dx: destinationOrigin.x - currentOrigin.x,
            dy: destinationOrigin.y - currentOrigin.y
        )

        renderer.applyBehaviorState(
            state,
            movementVector: state.isMoving ? movementVector : nil
        )

        if state.isMoving {
            stateDeadline = nil
            if state == .wander {
                renderer.playMovementGuide(toward: movementVector)
                movementStartDate = Date().addingTimeInterval(
                    renderer.movementGuideLeadDelay
                )
            } else {
                movementStartDate = nil
            }
        } else {
            movementStartDate = nil
            currentOrigin = destinationOrigin
            stateDeadline = plan.dwellDuration.map {
                Date().addingTimeInterval($0)
            }
            syncFrame()
        }

        if tickTimer != nil {
            scheduleTickTimerIfNeeded()
        }
    }

    private func syncFrame() {
        let desiredFrame = CGRect(origin: .zero, size: asset.layout.panelSize)
        if view.frame != desiredFrame {
            view.frame = desiredFrame
        }

        let roundedOrigin = currentOrigin.rounded
        guard roundedOrigin != lastReportedOrigin else { return }
        lastReportedOrigin = roundedOrigin
        originDidChange?(roundedOrigin)
    }

    private func replaceRenderer(for asset: DesktopPetAsset) {
        let wasRunning = tickTimer != nil
        let previousView = renderer.view

        renderer = PetRendererFactory.makeRenderer(for: asset)
        renderer.applyAsset(asset)
        renderer.setAmbientInteractionEnabled(wasRunning)

        if let parentView {
            previousView.removeFromSuperview()
            renderer.view.frame = CGRect(origin: .zero, size: asset.layout.panelSize)
            parentView.addSubview(renderer.view)
        }
        viewDidChange?(renderer.view)
    }

    func beginManualDrag() {
        guard !isManualDragActive else { return }

        isManualDragActive = true
        movementStartDate = nil
        stateDeadline = nil
        currentSpeed = 0
        scheduleTickTimerIfNeeded()

        if state.isMoving {
            state = .idle
            renderer.applyBehaviorState(.idle, movementVector: nil)
        }
    }

    func updateDraggedOrigin(_ origin: CGPoint) {
        let clamped = clampedOrigin(origin)

        currentOrigin = clamped
        destinationOrigin = clamped
        currentSpeed = 0

        if state.isMoving {
            state = .idle
            renderer.applyBehaviorState(.idle, movementVector: nil)
        }

        syncFrame()
    }

    func endManualDrag() {
        guard isManualDragActive else { return }

        isManualDragActive = false

        guard hasInitializedPlan, movementBounds != .zero else { return }

        if !isRoamingEnabled {
            let plan = behaviorEngine.roamingDisabledPlan(
                currentOrigin: currentOrigin,
                movementBounds: movementBounds,
                homeOrigin: homeOrigin
            )
            apply(plan)
            return
        }

        behaviorEngine.resetAfterManualRelocation()
        state = .idle
        destinationOrigin = currentOrigin
        currentSpeed = 0
        stateDeadline = Date().addingTimeInterval(
            TimeInterval.random(in: asset.behavior.idleDuration)
        )
        renderer.applyBehaviorState(.idle, movementVector: nil)
        syncFrame()
        scheduleTickTimerIfNeeded()
    }

    private var desiredTickInterval: TimeInterval {
        if state.isMoving || isManualDragActive {
            return Timing.movingTickInterval
        }

        return Timing.idleTickInterval
    }

    private func scheduleTickTimerIfNeeded(force: Bool = false) {
        let desiredTickInterval = desiredTickInterval

        if
            !force,
            let currentTickInterval,
            tickTimer != nil,
            abs(currentTickInterval - desiredTickInterval) < 0.001
        {
            return
        }

        tickTimer?.invalidate()

        let timer = Timer(
            timeInterval: desiredTickInterval,
            target: self,
            selector: #selector(handleTickTimer),
            userInfo: nil,
            repeats: true
        )
        timer.tolerance = desiredTickInterval * Timing.timerToleranceRatio
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
        currentTickInterval = desiredTickInterval
    }

    private func clampedOrigin(_ origin: CGPoint) -> CGPoint {
        guard movementBounds != .zero else { return origin }

        return CGPoint(
            x: min(max(origin.x, movementBounds.minX), movementBounds.maxX),
            y: min(max(origin.y, movementBounds.minY), movementBounds.maxY)
        )
    }

    private func clampedMovementBounds(_ bounds: CGRect) -> CGRect {
        CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: max(bounds.width, 1),
            height: max(bounds.height, 1)
        )
    }
}

private extension CGPoint {

    var rounded: CGPoint {
        CGPoint(x: x.rounded(), y: y.rounded())
    }
}
