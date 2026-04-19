//
//  ConfigurationNavigationStore.swift
//  vm-net
//
//  Created by Codex on 2026/4/17.
//

import Combine
import Foundation

enum ConfigurationPageGroup: Int, CaseIterable, Identifiable {
    case workspace
    case tools
    case desktop
    case preferences

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .workspace:
            return L10n.tr("navigation.group.workspace")
        case .tools:
            return L10n.tr("navigation.group.tools")
        case .desktop:
            return L10n.tr("navigation.group.desktop")
        case .preferences:
            return L10n.tr("navigation.group.preferences")
        }
    }

    var pages: [ConfigurationPage] {
        ConfigurationPage.allCases.filter { $0.group == self }
    }
}

enum ConfigurationPage: String, CaseIterable, Hashable, Identifiable {
    case overview
    case activity
    case diagnosis
    case speedTest
    case desktopPet
    case preferences

    var id: String { rawValue }

    var group: ConfigurationPageGroup {
        switch self {
        case .overview:
            return .workspace
        case .activity, .diagnosis, .speedTest:
            return .tools
        case .desktopPet:
            return .desktop
        case .preferences:
            return .preferences
        }
    }

    var title: String {
        switch self {
        case .overview:
            return L10n.tr("navigation.overview.title")
        case .activity:
            return L10n.tr("navigation.activity.title")
        case .diagnosis:
            return L10n.tr("navigation.diagnosis.title")
        case .speedTest:
            return L10n.tr("navigation.speedTest.title")
        case .desktopPet:
            return L10n.tr("navigation.desktopPet.title")
        case .preferences:
            return L10n.tr("navigation.preferences.title")
        }
    }

    var subtitle: String {
        switch self {
        case .overview:
            return L10n.tr("navigation.overview.subtitle")
        case .activity:
            return L10n.tr("navigation.activity.subtitle")
        case .diagnosis:
            return L10n.tr("navigation.diagnosis.subtitle")
        case .speedTest:
            return L10n.tr("navigation.speedTest.subtitle")
        case .desktopPet:
            return L10n.tr("navigation.desktopPet.subtitle")
        case .preferences:
            return L10n.tr("navigation.preferences.subtitle")
        }
    }

    var symbolName: String {
        switch self {
        case .overview:
            return "square.grid.2x2"
        case .activity:
            return "waveform.badge.magnifyingglass"
        case .diagnosis:
            return "stethoscope"
        case .speedTest:
            return "gauge.with.dots.needle.33percent"
        case .desktopPet:
            return "pawprint"
        case .preferences:
            return "slider.horizontal.3"
        }
    }
}

@MainActor
final class ConfigurationNavigationStore: ObservableObject {

    @Published var page: ConfigurationPage = .overview

    func show(_ page: ConfigurationPage) {
        self.page = page
    }
}
