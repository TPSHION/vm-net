//
//  ConfigurationWindowController.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit
import SwiftUI

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
        onFloatingBallToggle: @escaping (Bool) -> Void,
        onDesktopPetToggle: @escaping (Bool) -> Void,
        onDesktopPetRoamingToggle: @escaping (Bool) -> Void,
        onDesktopPetAssetApply: @escaping (DesktopPetAssetID) -> Void
    ) {
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
            onFloatingBallToggle: onFloatingBallToggle,
            onDesktopPetToggle: onDesktopPetToggle,
            onDesktopPetRoamingToggle: onDesktopPetRoamingToggle,
            onDesktopPetAssetApply: onDesktopPetAssetApply
        )
        let hostingController = ScrollBarHidingHostingController(rootView: rootView)
        self.hostingController = hostingController
        let window = NSWindow(contentViewController: hostingController)

        window.title = "vm-net"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(Layout.defaultSize)
        window.minSize = Layout.minSize
        window.center()
        window.collectionBehavior = [.fullScreenNone]
        window.titleVisibility = .visible

        super.init(window: window)

        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        showWindow(nil)
        hostingController.hideScrollBars()
        window?.makeKeyAndOrderFront(nil)
        hostingController.hideScrollBars()
        NSApp.activate(ignoringOtherApps: true)
    }
}
