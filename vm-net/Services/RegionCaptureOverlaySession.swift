//
//  RegionCaptureOverlaySession.swift
//  vm-net
//
//  Created by Codex on 2026/4/19.
//

import AppKit
import Carbon.HIToolbox

enum RegionCaptureCommitAction: Sendable {
    case copyToClipboard
    case saveToFile
}

// Overlay architecture adapted from ScrollSnap (MIT):
// https://github.com/Brkgng/ScrollSnap
@MainActor
final class RegionCaptureOverlaySession {

    private enum Layout {
        static let minimumSelectionSize: CGFloat = 8
    }

    private enum Interaction {
        case drawing(
            anchor: CGPoint,
            originalSelection: RegionSelection?,
            originalWasDefaultFullscreen: Bool,
            screen: NSScreen
        )
        case moving(
            startPoint: CGPoint,
            initialRect: CGRect,
            screen: NSScreen
        )
        case resizing(
            handle: RegionSelectionHandle,
            startPoint: CGPoint,
            initialRect: CGRect,
            screen: NSScreen
        )
    }

    private let overlayControllers: [RegionCaptureOverlayController]
    private let toolbarController = RegionCaptureToolbarController()
    private let onCommit: (RegionSelection, RegionCaptureCommitAction) -> Void
    private let onCancel: () -> Void

    private var keyboardMonitor: Any?
    private var currentSelection: RegionSelection?
    private var interaction: Interaction?
    private var isDefaultFullscreenSelection = false

    init(
        screens: [NSScreen],
        onCommit: @escaping (RegionSelection, RegionCaptureCommitAction) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.overlayControllers = screens.map {
            RegionCaptureOverlayController(screen: $0)
        }
        self.onCommit = onCommit
        self.onCancel = onCancel

        toolbarController.saveToFileHandler = { [weak self] in
            self?.commit(.saveToFile)
        }
        toolbarController.copyToClipboardHandler = { [weak self] in
            self?.commit(.copyToClipboard)
        }
        toolbarController.cancelHandler = { [weak self] in
            self?.cancel()
        }

        for controller in overlayControllers {
            controller.onPointerDown = { [weak self] point, screen in
                self?.beginInteraction(at: point, on: screen)
            }
            controller.onPointerDragged = { [weak self] point in
                self?.updateInteraction(to: point)
            }
            controller.onPointerUp = { [weak self] point in
                self?.finishInteraction(at: point)
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
        let initialScreen = keyController?.screen ?? overlayControllers.first?.screen

        if let initialScreen {
            setSelection(
                RegionSelection(
                    rect: initialScreen.frame.integral,
                    originScreen: initialScreen
                ),
                isDefaultFullscreen: true
            )
        }

        for controller in overlayControllers {
            let shouldMakeKey = keyController.map { controller === $0 } ?? false
            controller.show(makeKey: shouldMakeKey)
        }

        NSApp.activate(ignoringOtherApps: true)
        installKeyboardMonitor()
    }

    private func installKeyboardMonitor() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown]
        ) { [weak self] event in
            guard let self else { return event }

            if event.keyCode == UInt16(kVK_Escape) {
                self.cancel()
                return nil
            }

            if event.keyCode == UInt16(kVK_Return)
                || event.keyCode == UInt16(kVK_ANSI_KeypadEnter)
            {
                self.commit(.copyToClipboard)
                return nil
            }

            if
                event.keyCode == UInt16(kVK_ANSI_S),
                event.modifierFlags.contains(.command)
            {
                self.commit(.saveToFile)
                return nil
            }

            return event
        }
    }

    private func beginInteraction(
        at point: CGPoint,
        on screen: NSScreen
    ) {
        let clampedPoint = clamp(point, to: screen.frame)

        if
            let selection = currentSelection,
            selection.originScreen == screen,
            let handle = RegionSelectionHandle.hitTest(
                point: clampedPoint,
                in: selection.rect
            )
        {
            interaction = .resizing(
                handle: handle,
                startPoint: clampedPoint,
                initialRect: selection.rect,
                screen: screen
            )
            renderSelectionUI()
            return
        }

        if
            let selection = currentSelection,
            selection.originScreen == screen,
            selection.rect.contains(clampedPoint),
            !isDefaultFullscreenSelection
        {
            interaction = .moving(
                startPoint: clampedPoint,
                initialRect: selection.rect,
                screen: screen
            )
            renderSelectionUI()
            return
        }

        if (currentSelection.map(isValid(selection:)) ?? false)
            && !isDefaultFullscreenSelection
        {
            return
        }

        interaction = .drawing(
            anchor: clampedPoint,
            originalSelection: currentSelection,
            originalWasDefaultFullscreen: isDefaultFullscreenSelection,
            screen: screen
        )

        setSelection(
            RegionSelection(
                rect: CGRect(origin: clampedPoint, size: .zero),
                originScreen: screen
            ),
            isDefaultFullscreen: false
        )
    }

    private func updateInteraction(to point: CGPoint) {
        guard let interaction else { return }

        switch interaction {
        case let .drawing(anchor, _, _, screen):
            let rect = drawingRect(
                from: anchor,
                to: point,
                within: screen.frame
            )
            currentSelection = RegionSelection(rect: rect, originScreen: screen)
            renderSelectionUI()

        case let .moving(startPoint, initialRect, screen):
            let delta = CGPoint(
                x: point.x - startPoint.x,
                y: point.y - startPoint.y
            )
            let rect = moveRect(
                initialRect,
                delta: delta,
                within: screen.frame
            )
            currentSelection = RegionSelection(rect: rect, originScreen: screen)
            renderSelectionUI()

        case let .resizing(handle, startPoint, initialRect, screen):
            let rect = resizeRect(
                initialRect,
                using: handle,
                startPoint: startPoint,
                currentPoint: point,
                within: screen.frame
            )
            currentSelection = RegionSelection(rect: rect, originScreen: screen)
            renderSelectionUI()
        }
    }

    private func finishInteraction(at point: CGPoint) {
        guard let interaction else { return }

        updateInteraction(to: point)
        self.interaction = nil

        switch interaction {
        case let .drawing(_, originalSelection, originalWasDefaultFullscreen, _):
            guard let currentSelection, isValid(selection: currentSelection) else {
                setSelection(
                    originalSelection,
                    isDefaultFullscreen: originalWasDefaultFullscreen
                )
                return
            }

            setSelection(
                RegionSelection(
                    rect: currentSelection.rect.integral,
                    originScreen: currentSelection.originScreen
                ),
                isDefaultFullscreen: false
            )

        case .moving, .resizing:
            guard let currentSelection else { return }
            setSelection(
                RegionSelection(
                    rect: currentSelection.rect.integral,
                    originScreen: currentSelection.originScreen
                ),
                isDefaultFullscreen: false
            )
        }
    }

    private func commit(_ action: RegionCaptureCommitAction) {
        guard
            let currentSelection,
            isValid(selection: currentSelection)
        else {
            return
        }

        teardown()
        onCommit(currentSelection, action)
    }

    private func cancel() {
        teardown()
        onCancel()
    }

    private func setSelection(
        _ selection: RegionSelection?,
        isDefaultFullscreen: Bool
    ) {
        currentSelection = selection
        self.isDefaultFullscreenSelection = isDefaultFullscreen
        renderSelectionUI()
    }

    private func renderSelectionUI() {
        let rect = currentSelection?.rect ?? .zero
        let hasEditableSelection =
            (currentSelection.map(isValid(selection:)) ?? false)
            && !isDefaultFullscreenSelection
        let isDrawingInteraction: Bool
        if case .drawing = interaction {
            isDrawingInteraction = true
        } else {
            isDrawingInteraction = false
        }
        let canShowEditingControls =
            hasEditableSelection
            && interaction == nil
        let showsHandles = hasEditableSelection && !isDrawingInteraction
        let showsSelectionMask =
            currentSelection != nil
            && !isDefaultFullscreenSelection
        let usesCrosshairCursor =
            !(currentSelection.map(isValid(selection:)) ?? false)
            || isDefaultFullscreenSelection
        let allowsOverlayKeyFocus = !hasEditableSelection

        overlayControllers.forEach { controller in
            controller.selectionRect = rect
            controller.showsHandles = showsHandles
            controller.showsSelectionMask = showsSelectionMask
            controller.usesCrosshairCursor = usesCrosshairCursor
            controller.allowsKeyFocus = allowsOverlayKeyFocus
        }

        if let currentSelection, canShowEditingControls {
            toolbarController.show(for: currentSelection)
        } else {
            toolbarController.hide()
        }
    }

    private func teardown() {
        if let keyboardMonitor {
            NSEvent.removeMonitor(keyboardMonitor)
            self.keyboardMonitor = nil
        }

        toolbarController.hide()
        overlayControllers.forEach { controller in
            controller.close()
        }
    }

    private func isValid(selection: RegionSelection) -> Bool {
        selection.rect.width >= Layout.minimumSelectionSize
            && selection.rect.height >= Layout.minimumSelectionSize
    }

    private func drawingRect(
        from anchor: CGPoint,
        to point: CGPoint,
        within bounds: CGRect
    ) -> CGRect {
        let clampedAnchor = clamp(anchor, to: bounds)
        let clampedPoint = clamp(point, to: bounds)

        return CGRect(
            x: min(clampedAnchor.x, clampedPoint.x),
            y: min(clampedAnchor.y, clampedPoint.y),
            width: abs(clampedPoint.x - clampedAnchor.x),
            height: abs(clampedPoint.y - clampedAnchor.y)
        ).integral
    }

    private func moveRect(
        _ rect: CGRect,
        delta: CGPoint,
        within bounds: CGRect
    ) -> CGRect {
        let width = rect.width
        let height = rect.height

        let x = min(
            max(rect.minX + delta.x, bounds.minX),
            bounds.maxX - width
        )
        let y = min(
            max(rect.minY + delta.y, bounds.minY),
            bounds.maxY - height
        )

        return CGRect(x: x, y: y, width: width, height: height).integral
    }

    private func resizeRect(
        _ rect: CGRect,
        using handle: RegionSelectionHandle,
        startPoint: CGPoint,
        currentPoint: CGPoint,
        within bounds: CGRect
    ) -> CGRect {
        let clampedPoint = clamp(currentPoint, to: bounds)
        let deltaX = clampedPoint.x - startPoint.x
        let deltaY = clampedPoint.y - startPoint.y

        var minX = rect.minX
        var maxX = rect.maxX
        var minY = rect.minY
        var maxY = rect.maxY

        if handle.affectsMinX {
            minX = min(
                max(rect.minX + deltaX, bounds.minX),
                maxX - Layout.minimumSelectionSize
            )
        }

        if handle.affectsMaxX {
            maxX = max(
                min(rect.maxX + deltaX, bounds.maxX),
                minX + Layout.minimumSelectionSize
            )
        }

        if handle.affectsMinY {
            minY = min(
                max(rect.minY + deltaY, bounds.minY),
                maxY - Layout.minimumSelectionSize
            )
        }

        if handle.affectsMaxY {
            maxY = max(
                min(rect.maxY + deltaY, bounds.maxY),
                minY + Layout.minimumSelectionSize
            )
        }

        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        ).integral
    }

    private func clamp(
        _ point: CGPoint,
        to bounds: CGRect
    ) -> CGPoint {
        CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }
}

private enum RegionSelectionHandle: CaseIterable {
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left

    private static let hitRadius: CGFloat = 10

    var affectsMinX: Bool {
        switch self {
        case .topLeft, .left, .bottomLeft:
            return true
        default:
            return false
        }
    }

    var affectsMaxX: Bool {
        switch self {
        case .topRight, .right, .bottomRight:
            return true
        default:
            return false
        }
    }

    var affectsMinY: Bool {
        switch self {
        case .bottomLeft, .bottom, .bottomRight:
            return true
        default:
            return false
        }
    }

    var affectsMaxY: Bool {
        switch self {
        case .topLeft, .top, .topRight:
            return true
        default:
            return false
        }
    }

    func center(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft:
            return CGPoint(x: rect.minX, y: rect.maxY)
        case .top:
            return CGPoint(x: rect.midX, y: rect.maxY)
        case .topRight:
            return CGPoint(x: rect.maxX, y: rect.maxY)
        case .right:
            return CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight:
            return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottom:
            return CGPoint(x: rect.midX, y: rect.minY)
        case .bottomLeft:
            return CGPoint(x: rect.minX, y: rect.minY)
        case .left:
            return CGPoint(x: rect.minX, y: rect.midY)
        }
    }

    static func hitTest(
        point: CGPoint,
        in rect: CGRect
    ) -> RegionSelectionHandle? {
        allCases.first { handle in
            let center = handle.center(in: rect)
            return hypot(center.x - point.x, center.y - point.y) <= hitRadius
        }
    }

    func hitRect(in rect: CGRect) -> CGRect {
        let center = center(in: rect)
        return CGRect(
            x: center.x - Self.hitRadius,
            y: center.y - Self.hitRadius,
            width: Self.hitRadius * 2,
            height: Self.hitRadius * 2
        )
    }
}

@MainActor
private final class RegionCaptureOverlayController: NSWindowController {

    let screen: NSScreen
    private let overlayView: RegionCaptureOverlayView

    var onPointerDown: ((CGPoint, NSScreen) -> Void)?
    var onPointerDragged: ((CGPoint) -> Void)?
    var onPointerUp: ((CGPoint) -> Void)?
    var onCancel: (() -> Void)?

    var selectionRect: CGRect = .zero {
        didSet {
            overlayView.selectionRect = selectionRect
            window?.invalidateCursorRects(for: overlayView)
        }
    }

    var showsHandles = false {
        didSet {
            overlayView.showsHandles = showsHandles
            window?.invalidateCursorRects(for: overlayView)
        }
    }

    var showsSelectionMask = false {
        didSet {
            overlayView.showsSelectionMask = showsSelectionMask
        }
    }

    var usesCrosshairCursor = true {
        didSet {
            overlayView.usesCrosshairCursor = usesCrosshairCursor
        }
    }

    var allowsKeyFocus = true {
        didSet {
            (window as? RegionCaptureOverlayWindow)?.allowsKeyFocus = allowsKeyFocus
        }
    }

    init(screen: NSScreen) {
        self.screen = screen
        self.overlayView = RegionCaptureOverlayView(screenFrame: screen.frame)

        let window = RegionCaptureOverlayWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
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
        overlayView.pointerDown = { [weak self] point in
            guard let self else { return }
            self.onPointerDown?(point, self.screen)
        }
        overlayView.pointerDragged = { [weak self] point in
            self?.onPointerDragged?(point)
        }
        overlayView.pointerUp = { [weak self] point in
            self?.onPointerUp?(point)
        }
        overlayView.cancelRequested = { [weak self] in
            self?.onCancel?()
        }
        window.contentView = overlayView
    }
}

private final class RegionCaptureOverlayWindow: NSWindow {

    var allowsKeyFocus = true

    override var canBecomeKey: Bool { allowsKeyFocus }
    override var canBecomeMain: Bool { false }
}

private final class RegionCaptureOverlayView: NSView {

    private enum Appearance {
        static let strokeColor = NSColor.systemBlue
        static let strokeWidth: CGFloat = 2
        static let selectionMaskColor = NSColor.black.withAlphaComponent(0.38)
        static let handleDiameter: CGFloat = 6
        static let handleBorderWidth: CGFloat = 2
        static let labelInset: CGFloat = 8
        static let labelHorizontalPadding: CGFloat = 14
        static let labelVerticalPadding: CGFloat = 8
        static let labelCornerRadius: CGFloat = 10
        static let labelSpacing: CGFloat = 8
        static let labelBackground = NSColor.black.withAlphaComponent(0.8)
        static let labelFont = NSFont.monospacedDigitSystemFont(
            ofSize: 11,
            weight: .semibold
        )
    }

    let screenFrame: CGRect

    var pointerDown: ((CGPoint) -> Void)?
    var pointerDragged: ((CGPoint) -> Void)?
    var pointerUp: ((CGPoint) -> Void)?
    var cancelRequested: (() -> Void)?

    var selectionRect: CGRect = .zero {
        didSet {
            needsDisplay = true
        }
    }

    var showsHandles = false {
        didSet {
            needsDisplay = true
        }
    }

    var showsSelectionMask = false {
        didSet {
            needsDisplay = true
        }
    }

    var usesCrosshairCursor = true {
        didSet {
            window?.invalidateCursorRects(for: self)
        }
    }

    private var isDragging = false

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
        addCursorRect(
            bounds,
            cursor: usesCrosshairCursor ? .crosshair : .arrow
        )

        guard
            showsHandles,
            !selectionRect.isEmpty
        else {
            return
        }

        let localRect = selectionRect.offsetBy(
            dx: -screenFrame.minX,
            dy: -screenFrame.minY
        )

        guard localRect.intersects(bounds) else { return }

        for handle in RegionSelectionHandle.allCases {
            addCursorRect(
                handle.hitRect(in: localRect),
                cursor: cursor(for: handle)
            )
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !selectionRect.isEmpty else { return }

        let localRect = selectionRect.offsetBy(
            dx: -screenFrame.minX,
            dy: -screenFrame.minY
        )

        drawSelectionMask(excluding: localRect)

        guard localRect.intersects(bounds) else { return }

        let strokePath = NSBezierPath(rect: localRect)
        strokePath.lineWidth = Appearance.strokeWidth
        Appearance.strokeColor.setStroke()
        strokePath.stroke()

        if showsHandles {
            drawHandles(for: localRect)
        }

        drawMeasurementLabel(for: localRect)
    }

    private func drawSelectionMask(excluding localRect: CGRect) {
        guard showsSelectionMask else { return }

        let visibleSelectionRect = localRect.intersection(bounds)
        if visibleSelectionRect.isNull || visibleSelectionRect.isEmpty {
            Appearance.selectionMaskColor.setFill()
            bounds.fill()
            return
        }

        let path = NSBezierPath(rect: bounds)
        path.appendRect(visibleSelectionRect)
        path.windingRule = .evenOdd
        Appearance.selectionMaskColor.setFill()
        path.fill()
    }

    override func mouseDown(with event: NSEvent) {
        if window?.canBecomeKey == true {
            window?.makeKey()
            window?.makeFirstResponder(self)
        }
        isDragging = true
        pointerDown?(convertToGlobal(point: event.locationInWindow))
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        pointerDragged?(convertToGlobal(point: event.locationInWindow))
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false
        pointerUp?(convertToGlobal(point: event.locationInWindow))
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

    private func cursor(for handle: RegionSelectionHandle) -> NSCursor {
        if #available(macOS 15.0, *) {
            return NSCursor.frameResize(
                position: frameResizePosition(for: handle),
                directions: .all
            )
        }

        switch handle {
        case .top, .bottom:
            return .resizeUpDown
        case .left, .right:
            return .resizeLeftRight
        case .topLeft, .bottomRight:
            return .resizeLeftRight
        case .topRight, .bottomLeft:
            return .resizeUpDown
        }
    }

    @available(macOS 15.0, *)
    private func frameResizePosition(
        for handle: RegionSelectionHandle
    ) -> NSCursor.FrameResizePosition {
        switch handle {
        case .topLeft:
            return .topLeft
        case .top:
            return .top
        case .topRight:
            return .topRight
        case .right:
            return .right
        case .bottomRight:
            return .bottomRight
        case .bottom:
            return .bottom
        case .bottomLeft:
            return .bottomLeft
        case .left:
            return .left
        }
    }

    private func drawHandles(for localRect: CGRect) {
        for handle in RegionSelectionHandle.allCases {
            let center = handle.center(in: localRect)
            let handleRect = CGRect(
                x: center.x - (Appearance.handleDiameter / 2),
                y: center.y - (Appearance.handleDiameter / 2),
                width: Appearance.handleDiameter,
                height: Appearance.handleDiameter
            )

            let path = NSBezierPath(ovalIn: handleRect)
            NSColor.white.setFill()
            path.fill()

            path.lineWidth = Appearance.handleBorderWidth
            Appearance.strokeColor.setStroke()
            path.stroke()
        }
    }

    private func drawMeasurementLabel(for localRect: CGRect) {
        let text = "\(Int(localRect.width)) × \(Int(localRect.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Appearance.labelFont,
            .foregroundColor: NSColor.white,
        ]
        let textSize = text.size(withAttributes: attributes)
        let labelSize = NSSize(
            width: textSize.width + (Appearance.labelHorizontalPadding * 2),
            height: textSize.height + (Appearance.labelVerticalPadding * 2)
        )

        let labelRect = measurementLabelRect(
            for: localRect,
            labelSize: labelSize
        )

        let textRect = NSRect(
            x: labelRect.minX + Appearance.labelHorizontalPadding,
            y: labelRect.minY + Appearance.labelVerticalPadding,
            width: textSize.width,
            height: textSize.height
        )

        let backgroundPath = NSBezierPath(
            roundedRect: labelRect,
            xRadius: Appearance.labelCornerRadius,
            yRadius: Appearance.labelCornerRadius
        )
        Appearance.labelBackground.setFill()
        backgroundPath.fill()

        text.draw(in: textRect, withAttributes: attributes)
    }

    private func measurementLabelRect(
        for localRect: CGRect,
        labelSize: NSSize
    ) -> NSRect {
        let x = min(
            max(localRect.minX, bounds.minX + Appearance.labelInset),
            bounds.maxX - labelSize.width - Appearance.labelInset
        )

        let preferredAboveY = localRect.maxY + Appearance.labelSpacing
        if preferredAboveY + labelSize.height <= bounds.maxY - Appearance.labelInset {
            return NSRect(
                x: x,
                y: preferredAboveY,
                width: labelSize.width,
                height: labelSize.height
            )
        }

        let preferredBelowY =
            localRect.minY - labelSize.height - Appearance.labelSpacing
        if preferredBelowY >= bounds.minY + Appearance.labelInset {
            return NSRect(
                x: x,
                y: preferredBelowY,
                width: labelSize.width,
                height: labelSize.height
            )
        }

        return NSRect(
            x: x,
            y: max(
                bounds.minY + Appearance.labelInset,
                min(
                    localRect.maxY - labelSize.height - Appearance.labelInset,
                    bounds.maxY - labelSize.height - Appearance.labelInset
                )
            ),
            width: labelSize.width,
            height: labelSize.height
        )
    }
}
