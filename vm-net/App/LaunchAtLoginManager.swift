//
//  LaunchAtLoginManager.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit
import Combine
import Carbon.HIToolbox
import ServiceManagement

@MainActor
final class LaunchAtLoginManager: ObservableObject {

    private let service: SMAppService

    @Published private(set) var isEnabled = false
    @Published private(set) var requiresApproval = false
    @Published private(set) var lastErrorMessage: String?

    init(service: SMAppService = .mainApp) {
        self.service = service
        refresh()
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }

            lastErrorMessage = nil
            refresh()
        } catch {
            lastErrorMessage = error.localizedDescription
            refresh()
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func refresh() {
        switch service.status {
        case .enabled:
            isEnabled = true
            requiresApproval = false
        case .requiresApproval:
            isEnabled = false
            requiresApproval = true
        case .notRegistered, .notFound:
            isEnabled = false
            requiresApproval = false
        @unknown default:
            isEnabled = false
            requiresApproval = false
        }
    }

    static var wasLaunchedAtLogin: Bool {
        NSAppleEventManager.shared()
            .currentAppleEvent?
            .paramDescriptor(
                forKeyword: AEKeyword(keyAELaunchedAsLogInItem)
            ) != nil
    }
}
