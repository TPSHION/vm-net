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

enum RegionCaptureTool: Equatable {
    case rectangle
    case ellipse
    case pen
    case arrow
}

enum RegionCaptureStrokeSize: CaseIterable, Equatable, Sendable {
    case small
    case medium
    case large

    var lineWidth: CGFloat {
        switch self {
        case .small:
            return 4
        case .medium:
            return 6
        case .large:
            return 8
        }
    }

    var outlineLineWidth: CGFloat {
        switch self {
        case .small:
            return 2
        case .medium:
            return 3
        case .large:
            return 4
        }
    }

    var penLineWidth: CGFloat {
        switch self {
        case .small:
            return 2
        case .medium:
            return 3
        case .large:
            return 4
        }
    }

    var headLength: CGFloat {
        switch self {
        case .small:
            return 14
        case .medium:
            return 18
        case .large:
            return 22
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .small:
            return L10n.tr("screenshot.toolbar.strokeSize.small")
        case .medium:
            return L10n.tr("screenshot.toolbar.strokeSize.medium")
        case .large:
            return L10n.tr("screenshot.toolbar.strokeSize.large")
        }
    }
}

enum RegionCaptureAnnotationColor: CaseIterable, Equatable, Sendable {
    case red
    case yellow
    case green
    case blue
    case gray

    var overlayColor: NSColor {
        switch self {
        case .red:
            return NSColor.systemRed
        case .yellow:
            return NSColor.systemYellow
        case .green:
            return NSColor.systemGreen
        case .blue:
            return NSColor.systemBlue
        case .gray:
            return NSColor.systemGray
        }
    }

    var cgColor: CGColor {
        overlayColor.cgColor
    }

    var accessibilityLabel: String {
        switch self {
        case .red:
            return L10n.tr("screenshot.toolbar.strokeColor.red")
        case .yellow:
            return L10n.tr("screenshot.toolbar.strokeColor.yellow")
        case .green:
            return L10n.tr("screenshot.toolbar.strokeColor.green")
        case .blue:
            return L10n.tr("screenshot.toolbar.strokeColor.blue")
        case .gray:
            return L10n.tr("screenshot.toolbar.strokeColor.gray")
        }
    }
}

struct RegionCaptureAnnotationStyle: Equatable, Sendable {
    var size: RegionCaptureStrokeSize
    var color: RegionCaptureAnnotationColor

    static let `default` = RegionCaptureAnnotationStyle(
        size: .medium,
        color: .blue
    )
}

struct RegionCaptureNormalizedPoint: Equatable, Sendable {
    let x: CGFloat
    let y: CGFloat

    static let zero = RegionCaptureNormalizedPoint(x: 0, y: 0)

    func point(in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + (rect.width * x),
            y: rect.minY + (rect.height * y)
        )
    }
}

struct RegionCaptureArrowAnnotation: Equatable, Sendable {
    let start: RegionCaptureNormalizedPoint
    let end: RegionCaptureNormalizedPoint
    let style: RegionCaptureAnnotationStyle

    init(
        startPoint: CGPoint,
        endPoint: CGPoint,
        in selectionRect: CGRect,
        style: RegionCaptureAnnotationStyle
    ) {
        self.start = Self.normalized(startPoint, in: selectionRect)
        self.end = Self.normalized(endPoint, in: selectionRect)
        self.style = style
    }

    func startPoint(in rect: CGRect) -> CGPoint {
        start.point(in: rect)
    }

    func endPoint(in rect: CGRect) -> CGPoint {
        end.point(in: rect)
    }

    func length(in rect: CGRect) -> CGFloat {
        let startPoint = startPoint(in: rect)
        let endPoint = endPoint(in: rect)
        return hypot(endPoint.x - startPoint.x, endPoint.y - startPoint.y)
    }

    static func normalized(
        _ point: CGPoint,
        in rect: CGRect
    ) -> RegionCaptureNormalizedPoint {
        guard rect.width > 0, rect.height > 0 else {
            return .zero
        }

        return RegionCaptureNormalizedPoint(
            x: min(max((point.x - rect.minX) / rect.width, 0), 1),
            y: min(max((point.y - rect.minY) / rect.height, 0), 1)
        )
    }
}

struct RegionCaptureRectangleAnnotation: Equatable, Sendable {
    let start: RegionCaptureNormalizedPoint
    let end: RegionCaptureNormalizedPoint
    let style: RegionCaptureAnnotationStyle

    init(
        startPoint: CGPoint,
        endPoint: CGPoint,
        in selectionRect: CGRect,
        style: RegionCaptureAnnotationStyle
    ) {
        self.start = RegionCaptureArrowAnnotation.normalized(
            startPoint,
            in: selectionRect
        )
        self.end = RegionCaptureArrowAnnotation.normalized(
            endPoint,
            in: selectionRect
        )
        self.style = style
    }

    func rect(in selectionRect: CGRect) -> CGRect {
        let startPoint = start.point(in: selectionRect)
        let endPoint = end.point(in: selectionRect)
        return CGRect(
            x: min(startPoint.x, endPoint.x),
            y: min(startPoint.y, endPoint.y),
            width: abs(endPoint.x - startPoint.x),
            height: abs(endPoint.y - startPoint.y)
        )
    }

    func smallestDimension(in selectionRect: CGRect) -> CGFloat {
        let rect = rect(in: selectionRect)
        return min(rect.width, rect.height)
    }
}

struct RegionCaptureEllipseAnnotation: Equatable, Sendable {
    let start: RegionCaptureNormalizedPoint
    let end: RegionCaptureNormalizedPoint
    let style: RegionCaptureAnnotationStyle

    init(
        startPoint: CGPoint,
        endPoint: CGPoint,
        in selectionRect: CGRect,
        style: RegionCaptureAnnotationStyle
    ) {
        self.start = RegionCaptureArrowAnnotation.normalized(
            startPoint,
            in: selectionRect
        )
        self.end = RegionCaptureArrowAnnotation.normalized(
            endPoint,
            in: selectionRect
        )
        self.style = style
    }

    func rect(in selectionRect: CGRect) -> CGRect {
        let startPoint = start.point(in: selectionRect)
        let endPoint = end.point(in: selectionRect)
        return CGRect(
            x: min(startPoint.x, endPoint.x),
            y: min(startPoint.y, endPoint.y),
            width: abs(endPoint.x - startPoint.x),
            height: abs(endPoint.y - startPoint.y)
        )
    }

    func smallestDimension(in selectionRect: CGRect) -> CGFloat {
        let rect = rect(in: selectionRect)
        return min(rect.width, rect.height)
    }
}

struct RegionCapturePenAnnotation: Equatable, Sendable {
    let points: [RegionCaptureNormalizedPoint]
    let style: RegionCaptureAnnotationStyle

    init(
        points: [CGPoint],
        in selectionRect: CGRect,
        style: RegionCaptureAnnotationStyle
    ) {
        self.points = points.map {
            RegionCaptureArrowAnnotation.normalized($0, in: selectionRect)
        }
        self.style = style
    }

    func points(in rect: CGRect) -> [CGPoint] {
        points.map { $0.point(in: rect) }
    }

    func length(in rect: CGRect) -> CGFloat {
        let resolvedPoints = points(in: rect)
        guard resolvedPoints.count > 1 else { return 0 }

        return zip(resolvedPoints, resolvedPoints.dropFirst()).reduce(0) {
            partialResult,
            pair in
            partialResult + hypot(
                pair.1.x - pair.0.x,
                pair.1.y - pair.0.y
            )
        }
    }
}

enum RegionCaptureAnnotation: Equatable, Sendable {
    case rectangle(RegionCaptureRectangleAnnotation)
    case ellipse(RegionCaptureEllipseAnnotation)
    case pen(RegionCapturePenAnnotation)
    case arrow(RegionCaptureArrowAnnotation)
}

// Overlay architecture adapted from ScrollSnap (MIT):
// https://github.com/Brkgng/ScrollSnap
@MainActor
final class RegionCaptureOverlaySession {

    private enum Layout {
        static let minimumSelectionSize: CGFloat = 8
        static let minimumShapeDimension: CGFloat = 8
        static let minimumPenStrokeLength: CGFloat = 6
        static let minimumPenPointDistance: CGFloat = 1.5
        static let minimumArrowLength: CGFloat = 10
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
        case drawingRectangle(
            anchor: CGPoint,
            screen: NSScreen
        )
        case drawingEllipse(
            anchor: CGPoint,
            screen: NSScreen
        )
        case drawingPen(
            screen: NSScreen
        )
        case drawingArrow(
            anchor: CGPoint,
            screen: NSScreen
        )
    }

    private let overlayControllers: [RegionCaptureOverlayController]
    private let toolbarController = RegionCaptureToolbarController()
    private let onCommit: (
        RegionSelection,
        [RegionCaptureAnnotation],
        RegionCaptureCommitAction
    ) -> Void
    private let onCancel: () -> Void

    private var keyboardMonitor: Any?
    private var currentSelection: RegionSelection?
    private var interaction: Interaction?
    private var isDefaultFullscreenSelection = false
    private var activeTool: RegionCaptureTool?
    private var annotationStyle = RegionCaptureAnnotationStyle.default
    private var annotations: [RegionCaptureAnnotation] = []
    private var draftAnnotation: RegionCaptureAnnotation?

    private var draftArrowAnnotation: RegionCaptureArrowAnnotation? {
        guard case let .arrow(annotation)? = draftAnnotation else {
            return nil
        }
        return annotation
    }

    private var draftRectangleAnnotation: RegionCaptureRectangleAnnotation? {
        guard case let .rectangle(annotation)? = draftAnnotation else {
            return nil
        }
        return annotation
    }

    private var draftEllipseAnnotation: RegionCaptureEllipseAnnotation? {
        guard case let .ellipse(annotation)? = draftAnnotation else {
            return nil
        }
        return annotation
    }

    private var draftPenAnnotation: RegionCapturePenAnnotation? {
        guard case let .pen(annotation)? = draftAnnotation else {
            return nil
        }
        return annotation
    }

    private var draftPenPoints: [CGPoint] = []

    init(
        screens: [NSScreen],
        onCommit: @escaping (
            RegionSelection,
            [RegionCaptureAnnotation],
            RegionCaptureCommitAction
        ) -> Void,
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
        toolbarController.rectangleToolHandler = { [weak self] in
            self?.toggleRectangleTool()
        }
        toolbarController.ellipseToolHandler = { [weak self] in
            self?.toggleEllipseTool()
        }
        toolbarController.penToolHandler = { [weak self] in
            self?.togglePenTool()
        }
        toolbarController.arrowToolHandler = { [weak self] in
            self?.toggleArrowTool()
        }
        toolbarController.strokeSizeHandler = { [weak self] size in
            self?.setStrokeSize(size)
        }
        toolbarController.strokeColorHandler = { [weak self] color in
            self?.setStrokeColor(color)
        }
        toolbarController.undoHandler = { [weak self] in
            self?.undoLastAnnotation()
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
            activeTool == .rectangle,
            let selection = currentSelection,
            selection.originScreen == screen,
            selection.rect.contains(clampedPoint),
            !isDefaultFullscreenSelection
        {
            let anchor = clamp(clampedPoint, to: selection.rect)
            interaction = .drawingRectangle(
                anchor: anchor,
                screen: screen
            )
            draftAnnotation = .rectangle(
                makeRectangleAnnotation(
                from: anchor,
                to: anchor,
                in: selection.rect
                )
            )
            renderSelectionUI()
            return
        }

        if
            activeTool == .ellipse,
            let selection = currentSelection,
            selection.originScreen == screen,
            selection.rect.contains(clampedPoint),
            !isDefaultFullscreenSelection
        {
            let anchor = clamp(clampedPoint, to: selection.rect)
            interaction = .drawingEllipse(
                anchor: anchor,
                screen: screen
            )
            draftAnnotation = .ellipse(
                makeEllipseAnnotation(
                    from: anchor,
                    to: anchor,
                    in: selection.rect
                )
            )
            renderSelectionUI()
            return
        }

        if
            activeTool == .pen,
            let selection = currentSelection,
            selection.originScreen == screen,
            selection.rect.contains(clampedPoint),
            !isDefaultFullscreenSelection
        {
            let anchor = clamp(clampedPoint, to: selection.rect)
            interaction = .drawingPen(screen: screen)
            draftPenPoints = [anchor]
            draftAnnotation = .pen(
                makePenAnnotation(
                    points: draftPenPoints,
                    in: selection.rect
                )
            )
            renderSelectionUI()
            return
        }

        if
            activeTool == .arrow,
            let selection = currentSelection,
            selection.originScreen == screen,
            selection.rect.contains(clampedPoint),
            !isDefaultFullscreenSelection
        {
            let anchor = clamp(clampedPoint, to: selection.rect)
            interaction = .drawingArrow(
                anchor: anchor,
                screen: screen
            )
            draftAnnotation = .arrow(
                makeArrowAnnotation(
                from: anchor,
                to: anchor,
                in: selection.rect
                )
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

        case let .drawingRectangle(anchor, screen):
            guard
                let selection = currentSelection,
                selection.originScreen == screen
            else {
                return
            }

            let endPoint = clamp(point, to: selection.rect)
            draftAnnotation = .rectangle(
                makeRectangleAnnotation(
                from: anchor,
                to: endPoint,
                in: selection.rect
                )
            )
            renderSelectionUI()

        case let .drawingEllipse(anchor, screen):
            guard
                let selection = currentSelection,
                selection.originScreen == screen
            else {
                return
            }

            let endPoint = clamp(point, to: selection.rect)
            draftAnnotation = .ellipse(
                makeEllipseAnnotation(
                    from: anchor,
                    to: endPoint,
                    in: selection.rect
                )
            )
            renderSelectionUI()

        case let .drawingPen(screen):
            guard
                let selection = currentSelection,
                selection.originScreen == screen
            else {
                return
            }

            let clampedPoint = clamp(point, to: selection.rect)
            appendDraftPenPoint(clampedPoint)
            draftAnnotation = .pen(
                makePenAnnotation(
                    points: draftPenPoints,
                    in: selection.rect
                )
            )
            renderSelectionUI()

        case let .drawingArrow(anchor, screen):
            guard
                let selection = currentSelection,
                selection.originScreen == screen
            else {
                return
            }

            let endPoint = clamp(point, to: selection.rect)
            draftAnnotation = .arrow(
                makeArrowAnnotation(
                from: anchor,
                to: endPoint,
                in: selection.rect
                )
            )
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

        case .drawingRectangle:
            if
                let currentSelection,
                let rectangle = draftRectangleAnnotation,
                rectangle.smallestDimension(in: currentSelection.rect)
                    >= Layout.minimumShapeDimension
            {
                annotations.append(.rectangle(rectangle))
            }
            self.draftAnnotation = nil
            renderSelectionUI()

        case .drawingEllipse:
            if
                let currentSelection,
                let ellipse = draftEllipseAnnotation,
                ellipse.smallestDimension(in: currentSelection.rect)
                    >= Layout.minimumShapeDimension
            {
                annotations.append(.ellipse(ellipse))
            }
            self.draftAnnotation = nil
            self.draftPenPoints.removeAll()
            renderSelectionUI()

        case .drawingPen:
            if
                let currentSelection,
                let pen = draftPenAnnotation,
                pen.length(in: currentSelection.rect)
                    >= Layout.minimumPenStrokeLength
            {
                annotations.append(.pen(pen))
            }
            self.draftAnnotation = nil
            self.draftPenPoints.removeAll()
            renderSelectionUI()

        case .drawingArrow:
            if
                let currentSelection,
                let arrow = draftArrowAnnotation,
                arrow.length(in: currentSelection.rect)
                    >= Layout.minimumArrowLength
            {
                annotations.append(.arrow(arrow))
            }
            self.draftAnnotation = nil
            self.draftPenPoints.removeAll()
            renderSelectionUI()
        }
    }

    private func commit(_ action: RegionCaptureCommitAction) {
        guard
            let currentSelection,
            isValid(selection: currentSelection)
        else {
            return
        }

        let committedAnnotations = self.annotations
        teardown()
        onCommit(currentSelection, committedAnnotations, action)
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

        if selection == nil || isDefaultFullscreen {
            activeTool = nil
            annotations.removeAll()
            draftAnnotation = nil
            draftPenPoints.removeAll()
        }

        renderSelectionUI()
    }

    private func renderSelectionUI() {
        let rect = currentSelection?.rect ?? .zero
        let hasEditableSelection =
            (currentSelection.map(isValid(selection:)) ?? false)
            && !isDefaultFullscreenSelection
        let isAnnotationInteraction: Bool
        switch interaction {
        case .drawingRectangle?, .drawingEllipse?, .drawingPen?, .drawingArrow?:
            isAnnotationInteraction = true
        default:
            isAnnotationInteraction = false
        }
        let activeAnnotationTool = activeTool
        let isRectangleToolActive = activeAnnotationTool == .rectangle
        let isEllipseToolActive = activeAnnotationTool == .ellipse
        let isPenToolActive = activeAnnotationTool == .pen
        let isArrowToolActive = activeAnnotationTool == .arrow
        let canUndo = !annotations.isEmpty
        let secondaryToolVisible = activeAnnotationTool != nil
        let selectedRectangle = isRectangleToolActive
        let selectedEllipse = isEllipseToolActive
        let selectedPen = isPenToolActive
        let selectedArrow = isArrowToolActive

        let canShowEditingControls =
            hasEditableSelection
            && interaction == nil
        let showsHandles = hasEditableSelection && !isAnnotationInteraction
        let showsSelectionMask =
            currentSelection != nil
            && !isDefaultFullscreenSelection
        let usesCrosshairCursor =
            !(currentSelection.map(isValid(selection:)) ?? false)
            || isDefaultFullscreenSelection
        let allowsOverlayKeyFocus = true

        overlayControllers.forEach { controller in
            controller.selectionRect = rect
            controller.showsHandles = showsHandles
            controller.showsSelectionMask = showsSelectionMask
            controller.usesCrosshairCursor = usesCrosshairCursor
            controller.allowsKeyFocus = allowsOverlayKeyFocus
            controller.usesAnnotationToolCursor =
                activeAnnotationTool != nil
                && currentSelection?.originScreen == controller.screen
            controller.annotations =
                currentSelection?.originScreen == controller.screen
                ? annotations
                : []
            controller.draftAnnotation =
                currentSelection?.originScreen == controller.screen
                ? draftAnnotation
                : nil
        }

        toolbarController.update(
            state: .init(
                isRectangleToolSelected: selectedRectangle,
                isEllipseToolSelected: selectedEllipse,
                isPenToolSelected: selectedPen,
                isArrowToolSelected: selectedArrow,
                selectedStrokeSize: annotationStyle.size,
                selectedStrokeColor: annotationStyle.color,
                canUndo: canUndo,
                showsSecondaryToolbar: secondaryToolVisible,
                highlightedTool: activeAnnotationTool
            )
        )

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

    private func toggleArrowTool() {
        guard (currentSelection.map(isValid(selection:)) ?? false) else {
            return
        }

        activeTool = activeTool == .arrow ? nil : .arrow
        draftAnnotation = nil
        draftPenPoints.removeAll()
        renderSelectionUI()
    }

    private func toggleRectangleTool() {
        guard (currentSelection.map(isValid(selection:)) ?? false) else {
            return
        }

        activeTool = activeTool == .rectangle ? nil : .rectangle
        draftAnnotation = nil
        draftPenPoints.removeAll()
        renderSelectionUI()
    }

    private func toggleEllipseTool() {
        guard (currentSelection.map(isValid(selection:)) ?? false) else {
            return
        }

        activeTool = activeTool == .ellipse ? nil : .ellipse
        draftAnnotation = nil
        draftPenPoints.removeAll()
        renderSelectionUI()
    }

    private func togglePenTool() {
        guard (currentSelection.map(isValid(selection:)) ?? false) else {
            return
        }

        activeTool = activeTool == .pen ? nil : .pen
        draftAnnotation = nil
        draftPenPoints.removeAll()
        renderSelectionUI()
    }

    private func setStrokeSize(_ size: RegionCaptureStrokeSize) {
        annotationStyle.size = size
        renderSelectionUI()
    }

    private func setStrokeColor(_ color: RegionCaptureAnnotationColor) {
        annotationStyle.color = color
        renderSelectionUI()
    }

    private func undoLastAnnotation() {
        guard !annotations.isEmpty else { return }
        annotations.removeLast()
        renderSelectionUI()
    }

    private func makeArrowAnnotation(
        from startPoint: CGPoint,
        to endPoint: CGPoint,
        in selectionRect: CGRect
    ) -> RegionCaptureArrowAnnotation {
        RegionCaptureArrowAnnotation(
            startPoint: startPoint,
            endPoint: endPoint,
            in: selectionRect,
            style: annotationStyle
        )
    }

    private func makeRectangleAnnotation(
        from startPoint: CGPoint,
        to endPoint: CGPoint,
        in selectionRect: CGRect
    ) -> RegionCaptureRectangleAnnotation {
        RegionCaptureRectangleAnnotation(
            startPoint: startPoint,
            endPoint: endPoint,
            in: selectionRect,
            style: annotationStyle
        )
    }

    private func makeEllipseAnnotation(
        from startPoint: CGPoint,
        to endPoint: CGPoint,
        in selectionRect: CGRect
    ) -> RegionCaptureEllipseAnnotation {
        RegionCaptureEllipseAnnotation(
            startPoint: startPoint,
            endPoint: endPoint,
            in: selectionRect,
            style: annotationStyle
        )
    }

    private func makePenAnnotation(
        points: [CGPoint],
        in selectionRect: CGRect
    ) -> RegionCapturePenAnnotation {
        RegionCapturePenAnnotation(
            points: points,
            in: selectionRect,
            style: annotationStyle
        )
    }

    private func appendDraftPenPoint(_ point: CGPoint) {
        guard let lastPoint = draftPenPoints.last else {
            draftPenPoints = [point]
            return
        }

        let distance = hypot(point.x - lastPoint.x, point.y - lastPoint.y)
        guard distance >= Layout.minimumPenPointDistance else {
            draftPenPoints[draftPenPoints.count - 1] = point
            return
        }

        draftPenPoints.append(point)
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
            window?.invalidateCursorRects(for: overlayView)
        }
    }

    var allowsKeyFocus = true {
        didSet {
            (window as? RegionCaptureOverlayWindow)?.allowsKeyFocus = allowsKeyFocus
        }
    }

    var usesAnnotationToolCursor = false {
        didSet {
            overlayView.usesAnnotationToolCursor = usesAnnotationToolCursor
            window?.invalidateCursorRects(for: overlayView)
        }
    }

    var annotations: [RegionCaptureAnnotation] = [] {
        didSet {
            overlayView.annotations = annotations
        }
    }

    var draftAnnotation: RegionCaptureAnnotation? {
        didSet {
            overlayView.draftAnnotation = draftAnnotation
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
        static let selectionInteractionFillColor = NSColor.white.withAlphaComponent(0.001)
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

    var usesAnnotationToolCursor = false {
        didSet {
            window?.invalidateCursorRects(for: self)
        }
    }

    var annotations: [RegionCaptureAnnotation] = [] {
        didSet {
            needsDisplay = true
        }
    }

    var draftAnnotation: RegionCaptureAnnotation? {
        didSet {
            needsDisplay = true
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

        guard !selectionRect.isEmpty else { return }

        let localRect = selectionRect.offsetBy(
            dx: -screenFrame.minX,
            dy: -screenFrame.minY
        )

        guard localRect.intersects(bounds) else { return }

        if usesAnnotationToolCursor {
            addCursorRect(localRect, cursor: .crosshair)
        }

        guard showsHandles else {
            return
        }

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

        drawInteractionCaptureFill(in: localRect)
        drawAnnotations(in: localRect)

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

    private func drawInteractionCaptureFill(in localRect: CGRect) {
        guard showsSelectionMask else { return }

        let visibleSelectionRect = localRect.intersection(bounds)
        guard !visibleSelectionRect.isNull, !visibleSelectionRect.isEmpty else {
            return
        }

        Appearance.selectionInteractionFillColor.setFill()
        visibleSelectionRect.fill()
    }

    private func drawAnnotations(in localRect: CGRect) {
        guard !annotations.isEmpty || draftAnnotation != nil else {
            return
        }

        NSGraphicsContext.saveGraphicsState()
        let clipPath = NSBezierPath(rect: localRect)
        clipPath.addClip()

        for annotation in annotations {
            draw(annotation, in: localRect, alpha: 1)
        }

        if let draftAnnotation {
            draw(draftAnnotation, in: localRect, alpha: 1)
        }

        NSGraphicsContext.restoreGraphicsState()
    }

    private func draw(
        _ annotation: RegionCaptureAnnotation,
        in rect: CGRect,
        alpha: CGFloat
    ) {
        switch annotation {
        case let .rectangle(rectangle):
            drawRectangle(rectangle, in: rect, alpha: alpha)
        case let .ellipse(ellipse):
            drawEllipse(ellipse, in: rect, alpha: alpha)
        case let .pen(pen):
            drawPen(pen, in: rect, alpha: alpha)
        case let .arrow(arrow):
            drawArrow(arrow, in: rect, alpha: alpha)
        }
    }

    private func drawRectangle(
        _ annotation: RegionCaptureRectangleAnnotation,
        in rect: CGRect,
        alpha: CGFloat
    ) {
        let boxRect = annotation.rect(in: rect)
        guard boxRect.width > 1, boxRect.height > 1 else { return }

        let lineWidth = annotation.style.size.outlineLineWidth
        let halfStroke = lineWidth * 0.5
        let strokeRect = boxRect.insetBy(dx: halfStroke, dy: halfStroke)
        guard strokeRect.width > 0, strokeRect.height > 0 else { return }

        let color = annotation.style.color.overlayColor.withAlphaComponent(alpha)
        let boxPath = NSBezierPath(rect: strokeRect)
        boxPath.lineWidth = lineWidth
        color.setStroke()
        boxPath.stroke()
    }

    private func drawEllipse(
        _ annotation: RegionCaptureEllipseAnnotation,
        in rect: CGRect,
        alpha: CGFloat
    ) {
        let ellipseRect = annotation.rect(in: rect)
        guard ellipseRect.width > 1, ellipseRect.height > 1 else { return }

        let lineWidth = annotation.style.size.outlineLineWidth
        let halfStroke = lineWidth * 0.5
        let strokeRect = ellipseRect.insetBy(dx: halfStroke, dy: halfStroke)
        guard strokeRect.width > 0, strokeRect.height > 0 else { return }

        let color = annotation.style.color.overlayColor.withAlphaComponent(alpha)
        let ellipsePath = NSBezierPath(ovalIn: strokeRect)
        ellipsePath.lineWidth = lineWidth
        color.setStroke()
        ellipsePath.stroke()
    }

    private func drawPen(
        _ annotation: RegionCapturePenAnnotation,
        in rect: CGRect,
        alpha: CGFloat
    ) {
        let points = annotation.points(in: rect)
        guard points.count > 1 else { return }

        let color = annotation.style.color.overlayColor.withAlphaComponent(alpha)
        let penPath = NSBezierPath()
        penPath.lineCapStyle = .round
        penPath.lineJoinStyle = .round
        penPath.lineWidth = annotation.style.size.penLineWidth
        penPath.move(to: points[0])
        points.dropFirst().forEach { penPath.line(to: $0) }
        color.setStroke()
        penPath.stroke()
    }

    private func drawArrow(
        _ annotation: RegionCaptureArrowAnnotation,
        in rect: CGRect,
        alpha: CGFloat
    ) {
        let startPoint = annotation.startPoint(in: rect)
        let endPoint = annotation.endPoint(in: rect)
        let deltaX = endPoint.x - startPoint.x
        let deltaY = endPoint.y - startPoint.y
        let length = hypot(deltaX, deltaY)
        guard length > 1 else { return }

        let unitX = deltaX / length
        let unitY = deltaY / length
        let bodyWidth = annotation.style.size.lineWidth
        let tailWidth = max(bodyWidth * 0.42, 2)
        let halfTailWidth = tailWidth * 0.5
        let halfBodyWidth = bodyWidth * 0.5
        let headLength = min(
            max(annotation.style.size.headLength, bodyWidth * 2.8),
            length * 0.58
        )
        let headWidth = max(headLength * 1.06, bodyWidth * 3.2)
        let shaftEnd = CGPoint(
            x: endPoint.x - (unitX * headLength),
            y: endPoint.y - (unitY * headLength)
        )
        let perpendicular = CGPoint(x: -unitY, y: unitX)
        let startLeft = CGPoint(
            x: startPoint.x + (perpendicular.x * halfTailWidth),
            y: startPoint.y + (perpendicular.y * halfTailWidth)
        )
        let startRight = CGPoint(
            x: startPoint.x - (perpendicular.x * halfTailWidth),
            y: startPoint.y - (perpendicular.y * halfTailWidth)
        )
        let shaftLeft = CGPoint(
            x: shaftEnd.x + (perpendicular.x * halfBodyWidth),
            y: shaftEnd.y + (perpendicular.y * halfBodyWidth)
        )
        let shaftRight = CGPoint(
            x: shaftEnd.x - (perpendicular.x * halfBodyWidth),
            y: shaftEnd.y - (perpendicular.y * halfBodyWidth)
        )
        let leftHeadPoint = CGPoint(
            x: shaftEnd.x + (perpendicular.x * headWidth * 0.5),
            y: shaftEnd.y + (perpendicular.y * headWidth * 0.5)
        )
        let rightHeadPoint = CGPoint(
            x: shaftEnd.x - (perpendicular.x * headWidth * 0.5),
            y: shaftEnd.y - (perpendicular.y * headWidth * 0.5)
        )

        let color = annotation.style.color.overlayColor.withAlphaComponent(alpha)

        let arrowPath = NSBezierPath()
        arrowPath.move(to: startLeft)
        arrowPath.line(to: shaftLeft)
        arrowPath.line(to: leftHeadPoint)
        arrowPath.line(to: endPoint)
        arrowPath.line(to: rightHeadPoint)
        arrowPath.line(to: shaftRight)
        arrowPath.line(to: startRight)
        arrowPath.close()
        color.setFill()
        arrowPath.fill()
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

struct RegionSelection {
    let rect: CGRect
    let originScreen: NSScreen
}
