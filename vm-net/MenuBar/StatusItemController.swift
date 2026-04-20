//
//  StatusItemController.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit
import Combine

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {

    private enum Layout {
        static let minimumRenderInterval: TimeInterval = 2
    }

    private struct RenderState: Equatable {
        let uploadText: String
        let downloadText: String
        let toolTip: String
    }

    private let statusItem: NSStatusItem
    private let formatter = ByteRateFormatter()
    private let store: ThroughputStore
    private let preferences: AppPreferences
    private let contentView = StatusItemContentView()
    private var cancellables: Set<AnyCancellable> = []
    private var lastRenderState: RenderState?
    private var lastRenderDate: Date?

    var openWindowHandler: (() -> Void)?
    var openNetworkActivityHandler: (() -> Void)?
    var captureRegionHandler: (() -> Void)?

    init(
        store: ThroughputStore,
        preferences: AppPreferences
    ) {
        self.statusItem = NSStatusBar.system.statusItem(
            withLength: StatusItemContentView.preferredWidth
        )
        self.store = store
        self.preferences = preferences

        super.init()

        configureMenu()
        configureButton()
        bind()
        render(.idle, force: true)
    }

    private func configureMenu() {
        let menu =
            statusItem.menu
            ?? AppControlMenuFactory.makeMenu(
                target: self,
                openWindowSelector: #selector(handleOpenWindow),
                openActivitySelector: #selector(handleOpenNetworkActivity),
                screenshotSelector: #selector(handleCaptureRegion),
                screenshotShortcut: preferences.screenshotShortcut
            )
        AppControlMenuFactory.populateMenu(
            menu,
            target: self,
            openWindowSelector: #selector(handleOpenWindow),
            openActivitySelector: #selector(handleOpenNetworkActivity),
            screenshotSelector: #selector(handleCaptureRegion),
            screenshotShortcut: preferences.screenshotShortcut
        )
        menu.delegate = self
        statusItem.menu = menu
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }

        statusItem.length = StatusItemContentView.preferredWidth
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.image = nil
        button.subviews.forEach { $0.removeFromSuperview() }
        button.imagePosition = .imageLeft
        button.lineBreakMode = .byClipping

        contentView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: button.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])
    }

    private func bind() {
        Publishers.CombineLatest(store.$snapshot, preferences.$displayMode)
            .sink { [weak self] snapshot, _ in
                self?.render(snapshot)
            }
            .store(in: &cancellables)

        preferences.$appLanguage
            .dropFirst()
            .sink { [weak self] _ in
                self?.configureMenu()
                if let snapshot = self?.store.snapshot {
                    self?.render(snapshot, force: true)
                }
            }
            .store(in: &cancellables)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        AppControlMenuFactory.populateMenu(
            menu,
            target: self,
            openWindowSelector: #selector(handleOpenWindow),
            openActivitySelector: #selector(handleOpenNetworkActivity),
            screenshotSelector: #selector(handleCaptureRegion),
            screenshotShortcut: preferences.screenshotShortcut
        )
    }

    private func render(
        _ snapshot: NetworkMonitorSnapshot,
        force: Bool = false
    ) {
        let displayed = preferences.displayMode.throughput(from: snapshot)
        let toolTip = snapshot.monitoredInterfaceName.map {
            L10n.tr("statusItem.tooltip.monitoringInterface", $0)
        } ?? L10n.tr("statusItem.tooltip.monitoringThroughput")
        let renderState = RenderState(
            uploadText: "\(formatter.string(for: displayed.uploadBytesPerSecond)) ↑",
            downloadText: "\(formatter.string(for: displayed.downloadBytesPerSecond)) ↓",
            toolTip: toolTip
        )

        guard shouldRender(renderState, force: force) else { return }

        contentView.render(
            uploadText: renderState.uploadText,
            downloadText: renderState.downloadText
        )
        statusItem.button?.toolTip = renderState.toolTip
        lastRenderState = renderState
        lastRenderDate = Date()
    }

    private func shouldRender(
        _ renderState: RenderState,
        force: Bool
    ) -> Bool {
        if force {
            return true
        }

        guard let lastRenderState else {
            return true
        }

        guard renderState != lastRenderState else {
            return false
        }

        if renderState.toolTip != lastRenderState.toolTip {
            return true
        }

        guard let lastRenderDate else {
            return true
        }

        return Date().timeIntervalSince(lastRenderDate)
            >= Layout.minimumRenderInterval
    }

    @objc
    private func handleOpenWindow() {
        openWindowHandler?()
    }

    @objc
    private func handleOpenNetworkActivity() {
        openNetworkActivityHandler?()
    }

    @objc
    private func handleCaptureRegion() {
        captureRegionHandler?()
    }

    func invalidate() {
        NSStatusBar.system.removeStatusItem(statusItem)
    }
}
