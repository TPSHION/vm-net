//
//  DesktopPetContentView.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit
import MetalKit
import RiveRuntime

enum DesktopPetMetrics {
    static let size = NSSize(width: 184, height: 184)
    static let backdropSize = NSSize(width: 128, height: 128)
    static let cornerRadius: CGFloat = 64
}

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

    static let petSize = DesktopPetMetrics.size

    private enum Layout {
        static let backdropSize = DesktopPetMetrics.backdropSize
        static let riveInset = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        static let cornerRadius = DesktopPetMetrics.cornerRadius
        static let ambientInitialDelay: ClosedRange<TimeInterval> = 1.5...3.0
        static let ambientDelay: ClosedRange<TimeInterval> = 4.0...7.5
        static let ambientStepDelay: TimeInterval = 0.08
        static let ambientResumeDelay: TimeInterval = 2.4
        static let interactionInset = NSEdgeInsets(top: -10, left: -12, bottom: -8, right: -12)
    }

    private enum AmbientPath {
        static let center = CGPoint(x: 0.50, y: 0.82)
        static let centerJitterX: ClosedRange<CGFloat> = -0.06...0.06
        static let centerJitterY: ClosedRange<CGFloat> = -0.04...0.04
        static let radiusX: ClosedRange<CGFloat> = 0.16...0.30
        static let radiusY: ClosedRange<CGFloat> = 0.10...0.20
        static let sweep: ClosedRange<CGFloat> = (.pi * 0.65)...(.pi * 1.2)
        static let pointCount = 6
        static let xBounds: ClosedRange<CGFloat> = 0.18...0.82
        static let yBounds: ClosedRange<CGFloat> = 0.66...0.99
    }

    private enum Asset {
        static let fileName = "blobby-cat"
        static let artboardName = "Cat Artboard"
        static let stateMachineName: String? = nil
    }

    private let viewModel = RiveViewModel(
        fileName: Asset.fileName,
        stateMachineName: Asset.stateMachineName,
        fit: .contain,
        alignment: .center,
        autoPlay: true,
        artboardName: Asset.artboardName,
        loadCdn: false
    )
    private let riveView: RiveView
    private let backdropView = NSView()
    private var ambientInteractionTimer: Timer?
    private var ambientInteractionEnabled = false
    private var trackingArea: NSTrackingArea?
    private var userInteractionResumeWorkItem: DispatchWorkItem?
    private var isUserInteracting = false

    override var intrinsicContentSize: NSSize {
        Self.petSize
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        enforceTransparency()
    }

    override func layout() {
        super.layout()
        enforceTransparency()
    }

    override init(frame frameRect: NSRect) {
        self.riveView = viewModel.createRiveView()
        super.init(frame: frameRect)

        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        ambientInteractionTimer?.invalidate()
        userInteractionResumeWorkItem?.cancel()
        viewModel.pause()
        viewModel.deregisterView()
    }

    func setAmbientInteractionEnabled(_ isEnabled: Bool) {
        ambientInteractionEnabled = isEnabled

        if isEnabled {
            isUserInteracting = false
            scheduleAmbientInteraction(
                after: TimeInterval.random(in: Layout.ambientInitialDelay)
            )
        } else {
            ambientInteractionTimer?.invalidate()
            ambientInteractionTimer = nil
            userInteractionResumeWorkItem?.cancel()
            userInteractionResumeWorkItem = nil
            isUserInteracting = false
        }
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
        interactionRect.contains(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        handleUserMouseEvent(event) {
            riveView.mouseDown(with: $0)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        handleUserMouseEvent(event) {
            riveView.mouseDragged(with: $0)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        handleUserMouseEvent(event) {
            riveView.mouseMoved(with: $0)
        }
    }

    override func mouseUp(with event: NSEvent) {
        handleUserMouseEvent(event) {
            riveView.mouseUp(with: $0)
        }
    }

    override func mouseExited(with event: NSEvent) {
        handleUserMouseEvent(event) {
            riveView.mouseExited(with: $0)
        }
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false

        backdropView.translatesAutoresizingMaskIntoConstraints = false
        backdropView.wantsLayer = true
        backdropView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.16)
            .cgColor
        backdropView.layer?.cornerRadius = Layout.cornerRadius
        backdropView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.28).cgColor
        backdropView.layer?.shadowOpacity = 1
        backdropView.layer?.shadowRadius = 8
        backdropView.layer?.shadowOffset = CGSize(width: 0, height: -1)

        riveView.translatesAutoresizingMaskIntoConstraints = false
        riveView.wantsLayer = true
        riveView.layer?.backgroundColor = NSColor.clear.cgColor
        riveView.layer?.isOpaque = false

        addSubview(backdropView)
        addSubview(riveView)

        NSLayoutConstraint.activate([
            backdropView.centerXAnchor.constraint(equalTo: centerXAnchor),
            backdropView.centerYAnchor.constraint(equalTo: centerYAnchor),
            backdropView.widthAnchor.constraint(equalToConstant: Layout.backdropSize.width),
            backdropView.heightAnchor.constraint(equalToConstant: Layout.backdropSize.height),

            riveView.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: Layout.riveInset.left
            ),
            riveView.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -Layout.riveInset.right
            ),
            riveView.topAnchor.constraint(
                equalTo: topAnchor,
                constant: Layout.riveInset.top
            ),
            riveView.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -Layout.riveInset.bottom
            ),
        ])
    }

    private func enforceTransparency() {
        window?.isOpaque = false
        window?.backgroundColor = .clear

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

    private func scheduleAmbientInteraction(after delay: TimeInterval) {
        ambientInteractionTimer?.invalidate()

        guard ambientInteractionEnabled, !isUserInteracting else { return }

        ambientInteractionTimer = Timer.scheduledTimer(
            withTimeInterval: delay,
            repeats: false
        ) { [weak self] _ in
            self?.performAmbientInteractionIfPossible()
        }
    }

    private func performAmbientInteractionIfPossible() {
        defer {
            scheduleAmbientInteraction(
                after: TimeInterval.random(in: Layout.ambientDelay)
            )
        }

        guard
            ambientInteractionEnabled,
            !isUserInteracting,
            window?.isVisible == true,
            let path = makeAmbientPath()
        else {
            return
        }

        playSyntheticInteraction(path: path)
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

            let delay = Layout.ambientStepDelay * Double(index)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                self.dispatchSyntheticMouseEvent(
                    type: eventType,
                    normalizedPoint: normalizedPoint
                )
            }
        }
    }

    private func makeAmbientPath() -> [CGPoint]? {
        let direction: CGFloat = Bool.random() ? 1 : -1
        let startAngle = CGFloat.random(in: 0...(2 * .pi))
        let sweep = CGFloat.random(in: AmbientPath.sweep) * direction
        let center = CGPoint(
            x: AmbientPath.center.x + CGFloat.random(in: AmbientPath.centerJitterX),
            y: AmbientPath.center.y + CGFloat.random(in: AmbientPath.centerJitterY)
        )
        let radiusX = CGFloat.random(in: AmbientPath.radiusX)
        let radiusY = CGFloat.random(in: AmbientPath.radiusY)

        return (0..<AmbientPath.pointCount).map { index in
            let progress = CGFloat(index) / CGFloat(AmbientPath.pointCount - 1)
            let angle = startAngle + (sweep * progress)

            return CGPoint(
                x: clamp(
                    center.x + cos(angle) * radiusX,
                    to: AmbientPath.xBounds
                ),
                y: clamp(
                    center.y + sin(angle) * radiusY,
                    to: AmbientPath.yBounds
                )
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
            window.isVisible
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

    private var interactionRect: CGRect {
        riveView.frame.expanded(by: Layout.interactionInset)
    }

    private func handleUserMouseEvent(
        _ event: NSEvent,
        forward: (NSEvent) -> Void
    ) {
        guard ambientInteractionEnabled else { return }

        noteUserInteractionActivity()
        forward(event)
    }

    private func noteUserInteractionActivity() {
        ambientInteractionTimer?.invalidate()
        ambientInteractionTimer = nil
        isUserInteracting = true

        userInteractionResumeWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.ambientInteractionEnabled else { return }
            self.isUserInteracting = false
            self.scheduleAmbientInteraction(
                after: TimeInterval.random(in: Layout.ambientDelay)
            )
        }
        userInteractionResumeWorkItem = workItem

        DispatchQueue.main.asyncAfter(
            deadline: .now() + Layout.ambientResumeDelay,
            execute: workItem
        )
    }
}
