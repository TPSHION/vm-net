//
//  FloatingBallController.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit
import Combine

@MainActor
final class FloatingBallController: NSWindowController, NSWindowDelegate {

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

    var openWindowHandler: (() -> Void)? {
        didSet {
            contentView.openHandler = openWindowHandler
        }
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
    }

    func hide() {
        guard let window else { return }

        window.orderOut(nil)
    }

    func windowDidMove(_ notification: Notification) {
        persistWindowPlacement()
    }

    func windowDidChangeScreen(_ notification: Notification) {
        persistWindowPlacement()
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
        contentView.menu = AppControlMenuFactory.makeMenu(
            target: self,
            openSelector: #selector(handleOpenWindow)
        )
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

    private func persistWindowPlacement() {
        guard let window else { return }

        preferences.setFloatingBallPlacement(
            origin: window.frame.origin,
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
            preferences.floatingBallOrigin
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
        CGPoint(
            x: visibleFrame.maxX - size.width - Layout.screenPadding,
            y: visibleFrame.maxY - size.height - Layout.screenPadding
        )
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
}

private final class FloatingBallPanel: NSPanel {

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
