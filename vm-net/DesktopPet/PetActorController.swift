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
        static let tickInterval: TimeInterval = 1.0 / 30.0
    }

    let view: DesktopPetContentView
    var originDidChange: ((CGPoint) -> Void)?

    private(set) var asset: DesktopPetAsset

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
    private var hasInitializedPlan = false

    init(asset: DesktopPetAsset) {
        self.asset = asset
        self.behaviorEngine = PetBehaviorEngine(profile: asset.behavior)
        self.view = DesktopPetContentView(
            frame: NSRect(origin: .zero, size: asset.layout.panelSize),
            asset: asset
        )
    }

    var eventCaptureFrameInParent: CGRect {
        view.eventCaptureRectInSelf
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
        behaviorEngine.reset(profile: asset.behavior)
        view.applyAsset(asset)

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

    func updateEnvironment(
        movementBounds: CGRect,
        homeOrigin: CGPoint?
    ) {
        self.movementBounds = clampedMovementBounds(movementBounds)
        self.homeOrigin = homeOrigin.map(clampedOrigin(_:))
        currentOrigin = clampedOrigin(currentOrigin)
        destinationOrigin = clampedOrigin(
            self.homeOrigin ?? destinationOrigin
        )

        syncFrame()
        ensurePlanIfPossible()
    }

    func start() {
        view.setAmbientInteractionEnabled(true)
        ensurePlanIfPossible()

        guard tickTimer == nil else { return }

        let timer = Timer(
            timeInterval: Timing.tickInterval,
            target: self,
            selector: #selector(handleTickTimer),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    func stop() {
        tickTimer?.invalidate()
        tickTimer = nil
        view.setAmbientInteractionEnabled(false)
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
        guard !view.hasActiveInteraction else { return }

        if state.isMoving {
            advanceMovement(by: Timing.tickInterval)
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

        if state.isMoving {
            stateDeadline = nil
        } else {
            currentOrigin = destinationOrigin
            stateDeadline = plan.dwellDuration.map {
                Date().addingTimeInterval($0)
            }
            syncFrame()
        }
    }

    private func syncFrame() {
        view.frame = CGRect(origin: .zero, size: asset.layout.panelSize)
        originDidChange?(currentOrigin.rounded)
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
