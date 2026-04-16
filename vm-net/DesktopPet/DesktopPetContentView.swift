//
//  DesktopPetContentView.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit
import MetalKit
import RiveRuntime

private extension CGRect {
    func expanded(by insets: NSEdgeInsets) -> CGRect {
        CGRect(
            x: origin.x + insets.left,
            y: origin.y + insets.bottom,
            width: size.width - insets.left - insets.right,
            height: size.height - insets.top - insets.bottom
        )
    }
}

final class DesktopPetContentView: NSView {

    private enum Timing {
        static let ambientStepDelay: TimeInterval = 0.08
        static let ambientResumeDelay: TimeInterval = 2.4
    }

    private(set) var asset: DesktopPetAsset

    private let backdropView = NSView()
    private var viewModel: RiveViewModel?
    private var riveView: RiveView?
    private var ambientInteractionTimer: Timer?
    private var ambientInteractionEnabled = false
    private var trackingArea: NSTrackingArea?
    private var userInteractionResumeWorkItem: DispatchWorkItem?
    private var isUserInteracting = false
    private var isDraggingInteractiveElement = false
    private var currentBehaviorState: PetBehaviorState = .restAtHome

    var hasActiveInteraction: Bool {
        isDraggingInteractiveElement
    }

    var eventCaptureRectInSelf: CGRect {
        guard allowsDirectPointerInteraction else { return .zero }
        return pointerCaptureRect ?? .zero
    }

    var movementGuideLeadDelay: TimeInterval {
        asset.riveBehavior?.movementGuideLeadDelay ?? 0
    }

    private var backdropWidthConstraint: NSLayoutConstraint?
    private var backdropHeightConstraint: NSLayoutConstraint?
    private var riveLeadingConstraint: NSLayoutConstraint?
    private var riveTrailingConstraint: NSLayoutConstraint?
    private var riveTopConstraint: NSLayoutConstraint?
    private var riveBottomConstraint: NSLayoutConstraint?

    override var intrinsicContentSize: NSSize {
        asset.layout.panelSize
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        enforceTransparentRendering()
    }

    override func layout() {
        super.layout()
        enforceTransparentRendering()
    }

    init(frame frameRect: NSRect, asset: DesktopPetAsset) {
        self.asset = asset
        super.init(frame: frameRect)

        setupView()
        rebuildRiveView()
        applyLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        ambientInteractionTimer?.invalidate()
        userInteractionResumeWorkItem?.cancel()
        tearDownRiveView()
    }

    func applyAsset(_ asset: DesktopPetAsset) {
        guard self.asset.id != asset.id else { return }

        self.asset = asset
        currentBehaviorState = .restAtHome
        invalidateIntrinsicContentSize()
        applyLayout()
        rebuildRiveView()
        ambientInteractionTimer?.invalidate()
        ambientInteractionTimer = nil
        isUserInteracting = false
        isDraggingInteractiveElement = false
    }

    func setAmbientInteractionEnabled(_ isEnabled: Bool) {
        ambientInteractionEnabled = isEnabled && supportsAnyInteraction

        if ambientInteractionEnabled {
            ambientInteractionTimer?.invalidate()
            ambientInteractionTimer = nil
            userInteractionResumeWorkItem?.cancel()
            isUserInteracting = false
        } else {
            ambientInteractionTimer?.invalidate()
            ambientInteractionTimer = nil
            userInteractionResumeWorkItem?.cancel()
            userInteractionResumeWorkItem = nil
            isUserInteracting = false
            isDraggingInteractiveElement = false
        }
    }

    func applyBehaviorState(
        _ state: PetBehaviorState,
        movementVector: CGVector?
    ) {
        currentBehaviorState = state
    }

    func playMovementGuide(toward vector: CGVector) {
        guard
            ambientInteractionEnabled,
            allowsMovementGuide,
            currentBehaviorState == .wander,
            !isUserInteracting,
            window?.isVisible == true,
            let path = makeMovementGuidePath(toward: vector)
        else {
            return
        }

        playSyntheticInteraction(path: path)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited, .enabledDuringMouseDrag],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard allowsDirectPointerInteraction, ambientInteractionEnabled || isDraggingInteractiveElement else {
            return nil
        }

        if isDraggingInteractiveElement {
            return self
        }

        return pointerCaptureRect?.contains(point) == true ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        beginInteractiveDragIfPossible(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        continueInteractiveDragIfNeeded(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        guard isDraggingInteractiveElement else { return }
        continueInteractiveDragIfNeeded(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        endInteractiveDragIfNeeded(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        cancelInteractiveDragIfNeeded(with: event)
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false

        backdropView.translatesAutoresizingMaskIntoConstraints = false
        backdropView.wantsLayer = true
        addSubview(backdropView)

        backdropWidthConstraint = backdropView.widthAnchor.constraint(equalToConstant: 0)
        backdropHeightConstraint = backdropView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            backdropView.centerXAnchor.constraint(equalTo: centerXAnchor),
            backdropView.centerYAnchor.constraint(equalTo: centerYAnchor),
            backdropWidthConstraint!,
            backdropHeightConstraint!,
        ])
    }

    private func rebuildRiveView() {
        tearDownRiveView()

        let viewModel = RiveViewModel(
            fileName: asset.fileName,
            stateMachineName: asset.stateMachineName,
            fit: .contain,
            alignment: .center,
            autoPlay: true,
            artboardName: asset.artboardName,
            loadCdn: false
        )
        let riveView = viewModel.createRiveView()
        riveView.translatesAutoresizingMaskIntoConstraints = false
        riveView.wantsLayer = true
        riveView.layer?.backgroundColor = NSColor.clear.cgColor
        riveView.layer?.isOpaque = false

        addSubview(riveView)

        riveLeadingConstraint = riveView.leadingAnchor.constraint(equalTo: leadingAnchor)
        riveTrailingConstraint = riveView.trailingAnchor.constraint(equalTo: trailingAnchor)
        riveTopConstraint = riveView.topAnchor.constraint(equalTo: topAnchor)
        riveBottomConstraint = riveView.bottomAnchor.constraint(equalTo: bottomAnchor)

        NSLayoutConstraint.activate([
            riveLeadingConstraint!,
            riveTrailingConstraint!,
            riveTopConstraint!,
            riveBottomConstraint!,
        ])

        self.viewModel = viewModel
        self.riveView = riveView

        applyLayout()
        enforceTransparentRendering()
    }

    private func tearDownRiveView() {
        NSLayoutConstraint.deactivate([
            riveLeadingConstraint,
            riveTrailingConstraint,
            riveTopConstraint,
            riveBottomConstraint,
        ].compactMap { $0 })

        if let viewModel {
            viewModel.pause()
            viewModel.deregisterView()
        }

        riveView?.removeFromSuperview()
        viewModel = nil
        riveView = nil
        riveLeadingConstraint = nil
        riveTrailingConstraint = nil
        riveTopConstraint = nil
        riveBottomConstraint = nil
    }

    private func applyLayout() {
        frame.size = asset.layout.panelSize

        backdropView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.16)
            .cgColor
        backdropView.layer?.cornerRadius = asset.layout.cornerRadius
        backdropView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.28).cgColor
        backdropView.layer?.shadowOpacity = 1
        backdropView.layer?.shadowRadius = 8
        backdropView.layer?.shadowOffset = CGSize(width: 0, height: -1)

        backdropWidthConstraint?.constant = asset.layout.backdropSize.width
        backdropHeightConstraint?.constant = asset.layout.backdropSize.height
        riveLeadingConstraint?.constant = asset.layout.riveInset.left
        riveTrailingConstraint?.constant = -asset.layout.riveInset.right
        riveTopConstraint?.constant = asset.layout.riveInset.top
        riveBottomConstraint?.constant = -asset.layout.riveInset.bottom
    }

    private func enforceTransparentRendering() {
        clearBackgroundsRecursively(in: self)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.clearBackgroundsRecursively(in: self)
        }
    }

    private func clearBackgroundsRecursively(in view: NSView) {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.layer?.isOpaque = false

        if let metalView = view as? MTKView {
            metalView.clearColor = MTLClearColor(
                red: 0,
                green: 0,
                blue: 0,
                alpha: 0
            )
            metalView.layer?.backgroundColor = NSColor.clear.cgColor
            metalView.layer?.isOpaque = false
        }

        for subview in view.subviews {
            clearBackgroundsRecursively(in: subview)
        }
    }

    private func playSyntheticInteraction(path: [CGPoint]) {
        guard !path.isEmpty else { return }

        for (index, normalizedPoint) in path.enumerated() {
            let eventType: NSEvent.EventType
            switch index {
            case 0:
                eventType = .leftMouseDown
            case path.count - 1:
                eventType = .leftMouseUp
            default:
                eventType = .leftMouseDragged
            }

            let delay = Timing.ambientStepDelay * Double(index)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                self.dispatchSyntheticMouseEvent(
                    type: eventType,
                    normalizedPoint: normalizedPoint
                )
            }
        }
    }

    private func makeMovementGuidePath(toward vector: CGVector) -> [CGPoint]? {
        guard let orbit = asset.riveBehavior?.ambientOrbit else { return nil }

        let length = max(hypot(vector.dx, vector.dy), 0.001)
        let unitX = vector.dx / length
        let unitY = vector.dy / length
        let lateralX = -unitY
        let lateralY = unitX

        let bodyCenter = orbit.bodyCenter
        let bodyEdgeDistance = ellipseRadius(
            forUnitX: unitX,
            unitY: unitY,
            halfWidth: orbit.bodyHalfWidth,
            halfHeight: orbit.bodyHalfHeight
        )
        let startDistance = bodyEdgeDistance + orbit.leadPadding
        let apexPoint = CGPoint(
            x: bodyCenter.x + unitX * startDistance,
            y: bodyCenter.y + unitY * startDistance
        )
        let forwardDistance = max(
            CGFloat.random(in: orbit.radiusX),
            CGFloat.random(in: orbit.radiusY)
        ) * orbit.leadDistanceMultiplier
        let lateralDistance = CGFloat.random(
            in: (orbit.radiusY.lowerBound * 0.18)...max(orbit.radiusY.upperBound * 0.36, orbit.radiusY.lowerBound * 0.18)
        )
        let midDistance = forwardDistance * 0.34
        let farDistance = forwardDistance * 0.68
        let endDistance = forwardDistance

        let rawPoints: [CGPoint] = [
            apexPoint,
            CGPoint(
                x: apexPoint.x + unitX * midDistance + lateralX * (lateralDistance * 0.55),
                y: apexPoint.y + unitY * midDistance + lateralY * (lateralDistance * 0.55)
            ),
            CGPoint(
                x: apexPoint.x + unitX * farDistance - lateralX * (lateralDistance * 0.35),
                y: apexPoint.y + unitY * farDistance - lateralY * (lateralDistance * 0.35)
            ),
            CGPoint(
                x: apexPoint.x + unitX * endDistance + lateralX * (lateralDistance * 0.16),
                y: apexPoint.y + unitY * endDistance + lateralY * (lateralDistance * 0.16)
            ),
            CGPoint(
                x: apexPoint.x + unitX * (endDistance * 1.12),
                y: apexPoint.y + unitY * (endDistance * 1.12)
            ),
            CGPoint(
                x: apexPoint.x + unitX * (endDistance * 1.24),
                y: apexPoint.y + unitY * (endDistance * 1.24)
            )
        ]

        return rawPoints.map { point in
            CGPoint(
                x: clamp(point.x, to: orbit.xBounds),
                y: clamp(point.y, to: orbit.yBounds)
            )
        }
    }

    private func dispatchSyntheticMouseEvent(
        type: NSEvent.EventType,
        normalizedPoint: CGPoint
    ) {
        guard
            ambientInteractionEnabled,
            !isUserInteracting,
            let window,
            window.isVisible,
            let riveView
        else {
            return
        }

        let localPoint = CGPoint(
            x: normalizedPoint.x * riveView.bounds.width,
            y: normalizedPoint.y * riveView.bounds.height
        )
        let pointInWindow = riveView.convert(localPoint, to: nil)

        guard let event = NSEvent.mouseEvent(
            with: type,
            location: pointInWindow,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: type == .leftMouseUp ? 0 : 1
        ) else {
            return
        }

        switch type {
        case .leftMouseDown:
            riveView.mouseDown(with: event)
        case .leftMouseDragged:
            riveView.mouseDragged(with: event)
        case .leftMouseUp:
            riveView.mouseUp(with: event)
        default:
            break
        }
    }

    private func clamp(
        _ value: CGFloat,
        to bounds: ClosedRange<CGFloat>
    ) -> CGFloat {
        min(max(value, bounds.lowerBound), bounds.upperBound)
    }

    private func ellipseRadius(
        forUnitX unitX: CGFloat,
        unitY: CGFloat,
        halfWidth: CGFloat,
        halfHeight: CGFloat
    ) -> CGFloat {
        let safeHalfWidth = max(halfWidth, 0.001)
        let safeHalfHeight = max(halfHeight, 0.001)
        let denominator = sqrt(
            ((unitX * unitX) / (safeHalfWidth * safeHalfWidth))
            + ((unitY * unitY) / (safeHalfHeight * safeHalfHeight))
        )

        guard denominator > 0 else {
            return max(safeHalfWidth, safeHalfHeight)
        }

        return 1 / denominator
    }

    private var interactionRect: CGRect {
        guard let riveView else { return .zero }
        return riveView.frame.expanded(by: asset.layout.interactionInset)
    }

    private var pointerCaptureRect: CGRect? {
        guard
            let riveView,
            allowsDirectPointerInteraction,
            let normalizedRect = asset.layout.pointerCaptureRect
        else {
            return nil
        }

        let expandedFrame = riveView.frame.expanded(by: asset.layout.interactionInset)
        return CGRect(
            x: expandedFrame.minX + (normalizedRect.minX * expandedFrame.width),
            y: expandedFrame.minY + (normalizedRect.minY * expandedFrame.height),
            width: normalizedRect.width * expandedFrame.width,
            height: normalizedRect.height * expandedFrame.height
        )
    }

    private func beginInteractiveDragIfPossible(with event: NSEvent) {
        guard
            ambientInteractionEnabled,
            allowsDirectPointerInteraction,
            let interaction = resolveInteractionContext(for: event)
        else {
            isDraggingInteractiveElement = false
            return
        }

        let hitResult = interaction.stateMachine.touchBegan(
            atLocation: interaction.artboardLocation
        )
        guard hitResult != .none else {
            isDraggingInteractiveElement = false
            return
        }

        isDraggingInteractiveElement = true
        noteUserInteractionActivity()
        viewModel?.play()
    }

    private func continueInteractiveDragIfNeeded(with event: NSEvent) {
        guard
            ambientInteractionEnabled,
            allowsDirectPointerInteraction,
            isDraggingInteractiveElement,
            let interaction = resolveInteractionContext(for: event)
        else {
            return
        }

        _ = interaction.stateMachine.touchMoved(atLocation: interaction.artboardLocation)
        noteUserInteractionActivity()
        viewModel?.play()
    }

    private func endInteractiveDragIfNeeded(with event: NSEvent) {
        guard
            ambientInteractionEnabled,
            allowsDirectPointerInteraction,
            isDraggingInteractiveElement,
            let interaction = resolveInteractionContext(for: event)
        else {
            isDraggingInteractiveElement = false
            return
        }

        _ = interaction.stateMachine.touchEnded(atLocation: interaction.artboardLocation)
        isDraggingInteractiveElement = false
        noteUserInteractionActivity()
        viewModel?.play()
    }

    private func cancelInteractiveDragIfNeeded(with event: NSEvent) {
        guard
            ambientInteractionEnabled,
            allowsDirectPointerInteraction,
            isDraggingInteractiveElement,
            let interaction = resolveInteractionContext(for: event)
        else {
            isDraggingInteractiveElement = false
            return
        }

        _ = interaction.stateMachine.touchCancelled(
            atLocation: interaction.artboardLocation
        )
        isDraggingInteractiveElement = false
        viewModel?.play()
    }

    private func resolveInteractionContext(
        for event: NSEvent
    ) -> (stateMachine: RiveStateMachineInstance, artboardLocation: CGPoint)? {
        guard
            allowsDirectPointerInteraction,
            let riveView,
            let artboard = viewModel?.riveModel?.artboard,
            let stateMachine = viewModel?.riveModel?.stateMachine
        else {
            return nil
        }

        let locationInRiveView = riveView.convert(event.locationInWindow, from: nil)
        let flippedLocation = CGPoint(
            x: locationInRiveView.x,
            y: riveView.bounds.height - locationInRiveView.y
        )
        let artboardLocation = riveView.artboardLocation(
            fromTouchLocation: flippedLocation,
            inArtboard: artboard.bounds(),
            fit: viewModel?.fit ?? .contain,
            alignment: viewModel?.alignment ?? .center
        )

        return (stateMachine, artboardLocation)
    }

    private func noteUserInteractionActivity() {
        ambientInteractionTimer?.invalidate()
        ambientInteractionTimer = nil
        isUserInteracting = true

        userInteractionResumeWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.ambientInteractionEnabled else { return }
            self.isUserInteracting = false
        }
        userInteractionResumeWorkItem = workItem

        DispatchQueue.main.asyncAfter(
            deadline: .now() + Timing.ambientResumeDelay,
            execute: workItem
        )
    }

    private var allowsDirectPointerInteraction: Bool {
        asset.riveBehavior?.allowsDirectPointerInteraction == true
    }

    private var allowsMovementGuide: Bool {
        asset.riveBehavior?.allowsMovementGuide == true
    }

    private var supportsAnyInteraction: Bool {
        asset.riveBehavior?.supportsAnyInteraction == true
    }
}
