//
//  ConfigurationWindowController.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit
import SwiftUI

private final class CenteredWindowTitleView: NSView {

    private static let titleFont: NSFont = {
        let baseFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
        guard let roundedDescriptor = baseFont.fontDescriptor.withDesign(.rounded),
              let roundedFont = NSFont(descriptor: roundedDescriptor, size: 13) else {
            return baseFont
        }
        return roundedFont
    }()

    private let label = NSTextField(labelWithString: "")

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    init(title: String) {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        setTitle(title)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setTitle(_ title: String) {
        label.attributedStringValue = NSAttributedString(
            string: title,
            attributes: [
                .font: Self.titleFont,
                .foregroundColor: NSColor.labelColor.withAlphaComponent(0.82),
                .kern: 0.18,
            ]
        )
    }
}

private final class ScrollBarHidingHostingController<Content: View>: NSHostingController<Content> {

    override func viewDidLoad() {
        super.viewDidLoad()
        hideScrollBars()
    }

    override func viewWillLayout() {
        super.viewWillLayout()
        hideScrollBars()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        hideScrollBars()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        hideScrollBars()
    }

    func hideScrollBars() {
        let rootView = view.window?.contentView ?? view
        configureScrollViews(in: rootView)
    }

    private func configureScrollViews(in rootView: NSView) {
        if let scrollView = rootView as? NSScrollView {
            scrollView.hasVerticalScroller = false
            scrollView.hasHorizontalScroller = false
            scrollView.autohidesScrollers = true
            scrollView.scrollerStyle = .overlay
        }

        for subview in rootView.subviews {
            configureScrollViews(in: subview)
        }
    }
}

@MainActor
final class ConfigurationWindowController: NSWindowController {

    private enum Layout {
        static let defaultSize = NSSize(width: 940, height: 700)
        static let minSize = NSSize(width: 820, height: 620)
    }

    private let hostingController: ScrollBarHidingHostingController<ConfigurationView>
    private let centeredTitleView: CenteredWindowTitleView

    init(
        preferences: AppPreferences,
        navigationStore: ConfigurationNavigationStore,
        desktopPetAccessStore: DesktopPetAccessStore,
        launchAtLoginManager: LaunchAtLoginManager,
        throughputStore: ThroughputStore,
        processTrafficStore: ProcessTrafficStore,
        alertStore: AlertStore,
        activityTimelineStore: ActivityTimelineStore,
        speedTestStore: SpeedTestStore,
        diagnosisStore: NetworkDiagnosisStore,
        regionScreenshotController: RegionScreenshotController,
        onFloatingBallToggle: @escaping (Bool) -> Void,
        onDesktopPetToggle: @escaping (Bool) -> Void,
        onDesktopPetRoamingToggle: @escaping (Bool) -> Void,
        onDesktopPetAssetApply: @escaping (DesktopPetAssetID) -> Void,
        onRegionScreenshotRequest: @escaping () -> Void
    ) {
        let windowTitle = "vm-net"
        let rootView = ConfigurationView(
            preferences: preferences,
            navigationStore: navigationStore,
            desktopPetAccessStore: desktopPetAccessStore,
            launchAtLoginManager: launchAtLoginManager,
            throughputStore: throughputStore,
            processTrafficStore: processTrafficStore,
            alertStore: alertStore,
            activityTimelineStore: activityTimelineStore,
            speedTestStore: speedTestStore,
            diagnosisStore: diagnosisStore,
            regionScreenshotController: regionScreenshotController,
            onFloatingBallToggle: onFloatingBallToggle,
            onDesktopPetToggle: onDesktopPetToggle,
            onDesktopPetRoamingToggle: onDesktopPetRoamingToggle,
            onDesktopPetAssetApply: onDesktopPetAssetApply,
            onRegionScreenshotRequest: onRegionScreenshotRequest
        )
        let hostingController = ScrollBarHidingHostingController(rootView: rootView)
        self.hostingController = hostingController
        self.centeredTitleView = CenteredWindowTitleView(title: windowTitle)
        let window = NSWindow(contentViewController: hostingController)

        window.title = windowTitle
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.isReleasedWhenClosed = false
        window.setContentSize(Layout.defaultSize)
        window.minSize = Layout.minSize
        window.center()
        window.collectionBehavior = [.fullScreenNone]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unifiedCompact
        window.isMovableByWindowBackground = true
        window.backgroundColor = .windowBackgroundColor

        super.init(window: window)

        installCenteredTitleIfNeeded()
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        showWindow(nil)
        hostingController.hideScrollBars()
        installCenteredTitleIfNeeded()
        window?.makeKeyAndOrderFront(nil)
        hostingController.hideScrollBars()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func installCenteredTitleIfNeeded() {
        guard let window,
              let titlebarView = window.standardWindowButton(.closeButton)?.superview else {
            return
        }

        centeredTitleView.setTitle(window.title)
        hideSystemTitleLabels(in: titlebarView, matching: window.title)

        guard centeredTitleView.superview !== titlebarView else {
            return
        }

        titlebarView.addSubview(centeredTitleView)

        NSLayoutConstraint.activate([
            centeredTitleView.centerXAnchor.constraint(equalTo: titlebarView.centerXAnchor),
            centeredTitleView.centerYAnchor.constraint(equalTo: titlebarView.centerYAnchor),
            centeredTitleView.leadingAnchor.constraint(
                greaterThanOrEqualTo: titlebarView.leadingAnchor,
                constant: 88
            ),
            centeredTitleView.trailingAnchor.constraint(
                lessThanOrEqualTo: titlebarView.trailingAnchor,
                constant: -88
            ),
        ])
    }

    private func hideSystemTitleLabels(in rootView: NSView, matching title: String) {
        for subview in rootView.subviews {
            if let textField = subview as? NSTextField,
               textField.stringValue == title,
               !textField.isDescendant(of: centeredTitleView) {
                textField.isHidden = true
                textField.alphaValue = 0
            }

            hideSystemTitleLabels(in: subview, matching: title)
        }
    }
}
