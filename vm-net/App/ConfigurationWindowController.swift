//
//  ConfigurationWindowController.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit
import SwiftUI

@MainActor
final class ConfigurationWindowController: NSWindowController {

    private enum Layout {
        static let defaultSize = NSSize(width: 640, height: 640)
        static let minSize = NSSize(width: 620, height: 580)
    }

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
        let hostingController = NSHostingController(rootView: rootView)
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
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
