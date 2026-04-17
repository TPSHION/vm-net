//
//  NetworkDiagnosisPhase.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Foundation

enum NetworkDiagnosisPhase: String, Equatable, Sendable {
    case idle
    case checkingPath
    case resolvingDNS
    case checkingHTTPS
    case completed
    case failed
    case cancelled

    var isRunning: Bool {
        switch self {
        case .checkingPath, .resolvingDNS, .checkingHTTPS:
            return true
        case .idle, .completed, .failed, .cancelled:
            return false
        }
    }

    var title: String {
        switch self {
        case .idle:
            return L10n.tr("diagnosis.phase.idle.title")
        case .checkingPath:
            return L10n.tr("diagnosis.phase.checkingPath.title")
        case .resolvingDNS:
            return L10n.tr("diagnosis.phase.resolvingDNS.title")
        case .checkingHTTPS:
            return L10n.tr("diagnosis.phase.checkingHTTPS.title")
        case .completed:
            return L10n.tr("diagnosis.phase.completed.title")
        case .failed:
            return L10n.tr("diagnosis.phase.failed.title")
        case .cancelled:
            return L10n.tr("diagnosis.phase.cancelled.title")
        }
    }

    var detail: String {
        switch self {
        case .idle:
            return L10n.tr("diagnosis.phase.idle.detail")
        case .checkingPath:
            return L10n.tr("diagnosis.phase.checkingPath.detail")
        case .resolvingDNS:
            return L10n.tr("diagnosis.phase.resolvingDNS.detail")
        case .checkingHTTPS:
            return L10n.tr("diagnosis.phase.checkingHTTPS.detail")
        case .completed:
            return L10n.tr("diagnosis.phase.completed.detail")
        case .failed:
            return L10n.tr("diagnosis.phase.failed.detail")
        case .cancelled:
            return L10n.tr("diagnosis.phase.cancelled.detail")
        }
    }

    var symbolName: String {
        switch self {
        case .idle:
            return "stethoscope.circle"
        case .checkingPath:
            return "point.3.connected.trianglepath.dotted"
        case .resolvingDNS:
            return "globe"
        case .checkingHTTPS:
            return "lock.shield"
        case .completed:
            return "checkmark.shield"
        case .failed:
            return "exclamationmark.triangle"
        case .cancelled:
            return "pause.circle"
        }
    }
}
