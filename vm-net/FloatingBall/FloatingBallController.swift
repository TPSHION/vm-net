//
//  FloatingBallController.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit
import Combine

@MainActor
final class FloatingBallController: NSWindowController, NSWindowDelegate, NSMenuDelegate {

    private enum Layout {
        static let panelSize = NSSize(width: 88, height: 46)
        static let screenPadding: CGFloat = 24
    }

    private let store: ThroughputStore
    private let preferences: AppPreferences
    private let formatter = ByteRateFormatter()
    private let contentView = FloatingBallContentView(
        frame: NSRect(origin: .zero, size: Layout.panelSize)
    )
    private var cancellables: Set<AnyCancellable> = []

    var openWindowHandler: (() -> Void)?
    var frameChangeHandler: ((CGRect, NSScreen?) -> Void)?

    var currentFrame: CGRect? {
        window?.frame
    }

    var currentScreen: NSScreen? {
        window?.screen
    }

    init(
        store: ThroughputStore,
        preferences: AppPreferences
    ) {
        self.store = store
        self.preferences = preferences

        let panel = FloatingBallPanel(
            contentRect: NSRect(origin: .zero, size: Layout.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        super.init(window: panel)

        configurePanel(panel)
        applyAppearance()
        bind()
        render(.idle)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else { return }

        if !window.isVisible {
            window.setFrameOrigin(restoredOrigin(for: window.frame.size))
            showWindow(nil)
        }

        window.orderFrontRegardless()
        notifyFrameChange()
    }

    func hide() {
        guard let window else { return }

        window.orderOut(nil)
    }

    func windowDidMove(_ notification: Notification) {
        persistWindowPlacement()
        notifyFrameChange()
    }

    func windowDidChangeScreen(_ notification: Notification) {
        persistWindowPlacement()
        notifyFrameChange()
    }

    private func configurePanel(_ panel: FloatingBallPanel) {
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow
        panel.delegate = self

        let hostingView = NSView(frame: NSRect(origin: .zero, size: Layout.panelSize))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        contentView.frame = hostingView.bounds
        contentView.translatesAutoresizingMaskIntoConstraints = false
        let menu = AppControlMenuFactory.makeMenu(
            target: self,
            openSelector: #selector(handleOpenWindow)
        )
        menu.delegate = self
        contentView.menu = menu
        hostingView.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: hostingView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: hostingView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: hostingView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: hostingView.bottomAnchor),
        ])

        panel.contentView = hostingView
    }

    private func bind() {
        Publishers.CombineLatest(store.$snapshot, preferences.$displayMode)
            .sink { [weak self] snapshot, _ in
                self?.render(snapshot)
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3(
            preferences.$floatingBallBackgroundColor,
            preferences.$floatingBallTextColor,
            preferences.$floatingBallBackgroundTransparency
        )
        .sink { [weak self] _, _, _ in
            self?.applyAppearance()
        }
        .store(in: &cancellables)

        preferences.$appLanguage
            .dropFirst()
            .sink { [weak self] _ in
                self?.refreshMenuLocalization()
            }
            .store(in: &cancellables)
    }

    private func render(_ snapshot: NetworkMonitorSnapshot) {
        let displayed = preferences.displayMode.throughput(from: snapshot)

        contentView.render(
            uploadText: formatter.string(for: displayed.uploadBytesPerSecond),
            downloadText: formatter.string(for: displayed.downloadBytesPerSecond)
        )
    }

    private func applyAppearance() {
        contentView.applyAppearance(
            backgroundColor: preferences.floatingBallBackgroundColor,
            textColor: preferences.floatingBallTextColor,
            backgroundTransparency: preferences.floatingBallBackgroundTransparency
        )
    }

    @objc
    private func handleOpenWindow() {
        openWindowHandler?()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        AppControlMenuFactory.populateMenu(
            menu,
            target: self,
            openSelector: #selector(handleOpenWindow)
        )
    }

    private func refreshMenuLocalization() {
        guard let menu = contentView.menu else { return }
        AppControlMenuFactory.populateMenu(
            menu,
            target: self,
            openSelector: #selector(handleOpenWindow)
        )
    }

    private func persistWindowPlacement() {
        guard let window else { return }

        preferences.setFloatingBallPlacement(
            origin: window.frame.origin,
            normalizedOrigin: normalizedOrigin(
                for: window.frame.origin,
                size: window.frame.size,
                in: window.screen?.visibleFrame
            ),
            screenIdentifier: window.screen?.displayIdentifier
        )
    }

    private func restoredOrigin(for size: NSSize) -> CGPoint {
        let targetScreen =
            savedScreen
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let targetScreen else {
            return .zero
        }

        let proposedOrigin =
            restoredPersistedOrigin(
                for: size,
                in: targetScreen.visibleFrame
            )
            ?? defaultOrigin(in: targetScreen.visibleFrame, size: size)

        return clampedOrigin(
            proposedOrigin,
            in: targetScreen.visibleFrame,
            size: size
        )
    }

    private var savedScreen: NSScreen? {
        guard let identifier = preferences.floatingBallScreenIdentifier else {
            return nil
        }

        return NSScreen.screens.first {
            $0.displayIdentifier == identifier
        }
    }

    private func defaultOrigin(in visibleFrame: CGRect, size: NSSize) -> CGPoint {
        let compositionFrame = defaultCompositionFrame(
            for: size,
            asset: preferences.showDesktopPet ? preferences.desktopPetAsset : nil
        )

        return CGPoint(
            x: visibleFrame.maxX - compositionFrame.maxX - Layout.screenPadding,
            y: visibleFrame.maxY - compositionFrame.maxY - Layout.screenPadding
        )
    }

    private func restoredPersistedOrigin(
        for size: NSSize,
        in visibleFrame: CGRect
    ) -> CGPoint? {
        if let normalizedOrigin = preferences.floatingBallNormalizedOrigin {
            return origin(
                fromNormalizedOrigin: normalizedOrigin,
                size: size,
                in: visibleFrame
            )
        }

        return preferences.floatingBallOrigin
    }

    private func defaultCompositionFrame(
        for floatingBallSize: NSSize,
        asset: DesktopPetAsset?
    ) -> CGRect {
        guard let asset else {
            return CGRect(origin: .zero, size: floatingBallSize)
        }

        let petOrigin = defaultPetOrigin(
            relativeToFloatingBallOfSize: floatingBallSize,
            asset: asset
        )
        let floatingBallFrame = CGRect(origin: .zero, size: floatingBallSize)
        let petFrame = CGRect(origin: petOrigin, size: asset.layout.panelSize)

        return floatingBallFrame.union(petFrame)
    }

    private func defaultPetOrigin(
        relativeToFloatingBallOfSize floatingBallSize: NSSize,
        asset: DesktopPetAsset
    ) -> CGPoint {
        let attachment = asset.layout.attachment
        let petSize = asset.layout.panelSize
        let sharedY =
            (floatingBallSize.height / 2)
            - (petSize.height / 2)
            + attachment.verticalOffset

        let leftOrigin = CGPoint(
            x: -petSize.width + attachment.overlap + attachment.horizontalOffset,
            y: sharedY
        )
        let rightOrigin = CGPoint(
            x: floatingBallSize.width - attachment.overlap + attachment.horizontalOffset,
            y: sharedY
        )

        switch attachment.preferredSide {
        case .left:
            return leftOrigin
        case .right:
            return rightOrigin
        case .automatic:
            return leftOrigin
        }
    }

    private func clampedOrigin(
        _ origin: CGPoint,
        in visibleFrame: CGRect,
        size: NSSize
    ) -> CGPoint {
        let minX = visibleFrame.minX + Layout.screenPadding
        let maxX = visibleFrame.maxX - size.width - Layout.screenPadding
        let minY = visibleFrame.minY + Layout.screenPadding
        let maxY = visibleFrame.maxY - size.height - Layout.screenPadding

        return CGPoint(
            x: min(max(origin.x, minX), maxX),
            y: min(max(origin.y, minY), maxY)
        )
    }

    private func normalizedOrigin(
        for origin: CGPoint,
        size: NSSize,
        in visibleFrame: CGRect?
    ) -> CGPoint? {
        guard let visibleFrame else { return nil }

        let minX = visibleFrame.minX + Layout.screenPadding
        let maxX = visibleFrame.maxX - size.width - Layout.screenPadding
        let minY = visibleFrame.minY + Layout.screenPadding
        let maxY = visibleFrame.maxY - size.height - Layout.screenPadding

        let normalizedX = normalizedComponent(
            origin.x,
            min: minX,
            max: maxX
        )
        let normalizedY = normalizedComponent(
            origin.y,
            min: minY,
            max: maxY
        )

        return CGPoint(x: normalizedX, y: normalizedY)
    }

    private func origin(
        fromNormalizedOrigin normalizedOrigin: CGPoint,
        size: NSSize,
        in visibleFrame: CGRect
    ) -> CGPoint {
        let minX = visibleFrame.minX + Layout.screenPadding
        let maxX = visibleFrame.maxX - size.width - Layout.screenPadding
        let minY = visibleFrame.minY + Layout.screenPadding
        let maxY = visibleFrame.maxY - size.height - Layout.screenPadding

        return CGPoint(
            x: denormalizedComponent(normalizedOrigin.x, min: minX, max: maxX),
            y: denormalizedComponent(normalizedOrigin.y, min: minY, max: maxY)
        )
    }

    private func normalizedComponent(
        _ value: CGFloat,
        min lowerBound: CGFloat,
        max upperBound: CGFloat
    ) -> CGFloat {
        guard upperBound > lowerBound else { return 0 }
        return Swift.min(
            Swift.max((value - lowerBound) / (upperBound - lowerBound), 0),
            1
        )
    }

    private func denormalizedComponent(
        _ value: CGFloat,
        min lowerBound: CGFloat,
        max upperBound: CGFloat
    ) -> CGFloat {
        guard upperBound > lowerBound else { return lowerBound }
        let clampedValue = Swift.min(Swift.max(value, 0), 1)
        return lowerBound + (clampedValue * (upperBound - lowerBound))
    }

    private func notifyFrameChange() {
        guard let window else { return }
        frameChangeHandler?(window.frame, window.screen)
    }
}

private final class FloatingBallPanel: NSPanel {

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
