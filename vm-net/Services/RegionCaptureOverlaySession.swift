//
//  RegionCaptureOverlaySession.swift
//  vm-net
//
//  Created by Codex on 2026/4/19.
//

import AppKit
import Carbon.HIToolbox

// Overlay architecture adapted from ScrollSnap (MIT):
// https://github.com/Brkgng/ScrollSnap
@MainActor
final class RegionCaptureOverlaySession {

    private enum Layout {
        static let minimumSelectionSize: CGFloat = 8
    }

    private let overlayControllers: [RegionCaptureOverlayController]
    private let onComplete: (RegionSelection) -> Void
    private let onCancel: () -> Void

    private var keyboardMonitor: Any?
    private var anchorPoint: CGPoint?
    private var originScreen: NSScreen?

    init(
        screens: [NSScreen],
        onComplete: @escaping (RegionSelection) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.overlayControllers = screens.map {
            RegionCaptureOverlayController(screen: $0)
        }
        self.onComplete = onComplete
        self.onCancel = onCancel

        for controller in overlayControllers {
            controller.onSelectionBegan = { [weak self] point, screen in
                self?.beginSelection(at: point, on: screen)
            }
            controller.onSelectionChanged = { [weak self] point in
                self?.updateSelection(to: point)
            }
            controller.onSelectionEnded = { [weak self] point in
                self?.finishSelection(at: point)
            }
            controller.onCancel = { [weak self] in
                self?.cancel()
            }
        }
    }

    func begin() {
        let mouseLocation = NSEvent.mouseLocation
        let keyController = overlayControllers.first(where: {
            $0.screen.frame.contains(mouseLocation)
        })

        for controller in overlayControllers {
            let shouldMakeKey = keyController.map { controller === $0 } ?? false
            controller.show(makeKey: shouldMakeKey)
        }

        NSApp.activate(ignoringOtherApps: true)

        keyboardMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown]
        ) { [weak self] event in
            guard let self else { return event }

            if event.keyCode == UInt16(kVK_Escape) {
                self.cancel()
                return nil
            }

            return event
        }
    }

    private func beginSelection(
        at point: CGPoint,
        on screen: NSScreen
    ) {
        anchorPoint = point
        originScreen = screen
        renderSelectionRect(CGRect(origin: point, size: .zero))
    }

    private func updateSelection(to point: CGPoint) {
        guard let anchorPoint else { return }

        renderSelectionRect(
            CGRect(
                x: min(anchorPoint.x, point.x),
                y: min(anchorPoint.y, point.y),
                width: abs(point.x - anchorPoint.x),
                height: abs(point.y - anchorPoint.y)
            )
        )
    }

    private func finishSelection(at point: CGPoint) {
        guard
            let anchorPoint,
            let originScreen
        else {
            cancel()
            return
        }

        let rect = CGRect(
            x: min(anchorPoint.x, point.x),
            y: min(anchorPoint.y, point.y),
            width: abs(point.x - anchorPoint.x),
            height: abs(point.y - anchorPoint.y)
        ).integral

        teardown()

        guard
            rect.width >= Layout.minimumSelectionSize,
            rect.height >= Layout.minimumSelectionSize
        else {
            onCancel()
            return
        }

        onComplete(
            RegionSelection(
                rect: rect,
                originScreen: originScreen
            )
        )
    }

    private func cancel() {
        teardown()
        onCancel()
    }

    private func renderSelectionRect(_ rect: CGRect) {
        overlayControllers.forEach { controller in
            controller.selectionRect = rect
        }
    }

    private func teardown() {
        if let keyboardMonitor {
            NSEvent.removeMonitor(keyboardMonitor)
            self.keyboardMonitor = nil
        }

        overlayControllers.forEach { controller in
            controller.close()
        }
    }
}

@MainActor
private final class RegionCaptureOverlayController: NSWindowController {

    let screen: NSScreen
    private let overlayView: RegionCaptureOverlayView

    var onSelectionBegan: ((CGPoint, NSScreen) -> Void)?
    var onSelectionChanged: ((CGPoint) -> Void)?
    var onSelectionEnded: ((CGPoint) -> Void)?
    var onCancel: (() -> Void)?

    var selectionRect: CGRect = .zero {
        didSet {
            overlayView.selectionRect = selectionRect
        }
    }

    init(screen: NSScreen) {
        self.screen = screen
        self.overlayView = RegionCaptureOverlayView(screenFrame: screen.frame)

        let window = RegionCaptureOverlayWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        super.init(window: window)
        configureWindow(window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(makeKey: Bool) {
        guard let window else { return }

        if makeKey {
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(overlayView)
        } else {
            window.orderFront(nil)
        }
    }

    private func configureWindow(_ window: RegionCaptureOverlayWindow) {
        window.level = .statusBar
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovable = false
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false

        overlayView.frame = CGRect(origin: .zero, size: screen.frame.size)
        overlayView.autoresizingMask = [.width, .height]
        overlayView.selectionStarted = { [weak self] point in
            guard let self else { return }
            self.onSelectionBegan?(point, self.screen)
        }
        overlayView.selectionChanged = { [weak self] point in
            self?.onSelectionChanged?(point)
        }
        overlayView.selectionEnded = { [weak self] point in
            self?.onSelectionEnded?(point)
        }
        overlayView.cancelRequested = { [weak self] in
            self?.onCancel?()
        }
        window.contentView = overlayView
    }
}

private final class RegionCaptureOverlayWindow: NSWindow {

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class RegionCaptureOverlayView: NSView {

    let screenFrame: CGRect

    var selectionStarted: ((CGPoint) -> Void)?
    var selectionChanged: ((CGPoint) -> Void)?
    var selectionEnded: ((CGPoint) -> Void)?
    var cancelRequested: (() -> Void)?

    var selectionRect: CGRect = .zero {
        didSet {
            needsDisplay = true
        }
    }

    private var isDraggingSelection = false

    init(screenFrame: CGRect) {
        self.screenFrame = screenFrame
        super.init(frame: CGRect(origin: .zero, size: screenFrame.size))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.3).setFill()
        dirtyRect.fill()

        guard !selectionRect.isEmpty else { return }

        let localRect = selectionRect.offsetBy(
            dx: -screenFrame.minX,
            dy: -screenFrame.minY
        )

        guard localRect.intersects(bounds) else { return }

        if let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            context.setBlendMode(.clear)
            context.fill(localRect)
            context.restoreGState()
        }

        let fillPath = NSBezierPath(rect: localRect)
        NSColor.white.withAlphaComponent(0.16).setFill()
        fillPath.fill()

        let strokePath = NSBezierPath(rect: localRect)
        strokePath.lineWidth = 1.5
        NSColor.white.withAlphaComponent(0.96).setStroke()
        strokePath.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        isDraggingSelection = true
        selectionStarted?(convertToGlobal(point: event.locationInWindow))
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDraggingSelection else { return }
        selectionChanged?(convertToGlobal(point: event.locationInWindow))
    }

    override func mouseUp(with event: NSEvent) {
        guard isDraggingSelection else { return }
        isDraggingSelection = false
        selectionEnded?(convertToGlobal(point: event.locationInWindow))
    }

    override func rightMouseDown(with event: NSEvent) {
        cancelRequested?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            cancelRequested?()
            return
        }

        super.keyDown(with: event)
    }

    private func convertToGlobal(point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x + screenFrame.minX,
            y: point.y + screenFrame.minY
        )
    }
}
