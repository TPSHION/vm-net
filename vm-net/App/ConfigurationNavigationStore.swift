//
//  ConfigurationNavigationStore.swift
//  vm-net
//
//  Created by Codex on 2026/4/17.
//

import Combine
import Foundation

enum ConfigurationPage {
    case settings
    case activity
    case speedTest
    case diagnosis
    case desktopPet
}

@MainActor
final class ConfigurationNavigationStore: ObservableObject {

    @Published var page: ConfigurationPage = .settings

    func show(_ page: ConfigurationPage) {
        self.page = page
    }
}
