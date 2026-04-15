//
//  StatusItemController.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit
import Combine

@MainActor
final class StatusItemController {

    private enum Layout {
        static let statusItemWidth: CGFloat = 68
    }

    private let statusItem: NSStatusItem
    private let contentView = StatusItemContentView()
    private let formatter = ByteRateFormatter()
    private let store: ThroughputStore
    private let preferences: AppPreferences
    private var cancellables: Set<AnyCancellable> = []

    var openWindowHandler: (() -> Void)?

    init(
        store: ThroughputStore,
        preferences: AppPreferences
    ) {
        self.statusItem = NSStatusBar.system.statusItem(
            withLength: Layout.statusItemWidth
        )
        self.store = store
        self.preferences = preferences

        configureMenu()
        configureButton()
        bind()
        render(.idle)
    }

    private func configureMenu() {
        statusItem.menu = AppControlMenuFactory.makeMenu(
            target: self,
            openSelector: #selector(handleOpenWindow)
        )
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }

        button.title = ""
        button.image = nil
        button.subviews.forEach { $0.removeFromSuperview() }
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
    }

    private func render(_ snapshot: NetworkMonitorSnapshot) {
        let displayed = preferences.displayMode.throughput(from: snapshot)

        contentView.render(
            uploadText:
                "\(formatter.string(for: displayed.uploadBytesPerSecond)) ↑",
            downloadText:
                "\(formatter.string(for: displayed.downloadBytesPerSecond)) ↓",
            isActive: displayed.isActive
        )

        statusItem.button?.toolTip = snapshot.monitoredInterfaceName.map {
            "Monitoring \($0)"
        } ?? "Monitoring network throughput"
    }

    @objc
    private func handleOpenWindow() {
        openWindowHandler?()
    }

    func invalidate() {
        NSStatusBar.system.removeStatusItem(statusItem)
    }
}
