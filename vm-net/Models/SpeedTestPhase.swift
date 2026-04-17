//
//  SpeedTestPhase.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Foundation

enum SpeedTestPhase: String, Equatable, Sendable {
    case idle
    case locatingServer
    case measuringDownload
    case measuringUpload
    case completed
    case failed
    case cancelled

    var isRunning: Bool {
        switch self {
        case .locatingServer, .measuringDownload, .measuringUpload:
            return true
        case .idle, .completed, .failed, .cancelled:
            return false
        }
    }

    var title: String {
        switch self {
        case .idle:
            return L10n.tr("speedTest.phase.idle.title")
        case .locatingServer:
            return L10n.tr("speedTest.phase.locatingServer.title")
        case .measuringDownload:
            return L10n.tr("speedTest.phase.measuringDownload.title")
        case .measuringUpload:
            return L10n.tr("speedTest.phase.measuringUpload.title")
        case .completed:
            return L10n.tr("speedTest.phase.completed.title")
        case .failed:
            return L10n.tr("speedTest.phase.failed.title")
        case .cancelled:
            return L10n.tr("speedTest.phase.cancelled.title")
        }
    }

    var detail: String {
        switch self {
        case .idle:
            return L10n.tr("speedTest.phase.idle.detail")
        case .locatingServer:
            return L10n.tr("speedTest.phase.locatingServer.detail")
        case .measuringDownload:
            return L10n.tr("speedTest.phase.measuringDownload.detail")
        case .measuringUpload:
            return L10n.tr("speedTest.phase.measuringUpload.detail")
        case .completed:
            return L10n.tr("speedTest.phase.completed.detail")
        case .failed:
            return L10n.tr("speedTest.phase.failed.detail")
        case .cancelled:
            return L10n.tr("speedTest.phase.cancelled.detail")
        }
    }

    var symbolName: String {
        switch self {
        case .idle:
            return "bolt.horizontal.circle"
        case .locatingServer:
            return "dot.radiowaves.left.and.right"
        case .measuringDownload:
            return "arrow.down.circle"
        case .measuringUpload:
            return "arrow.up.circle"
        case .completed:
            return "checkmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        case .cancelled:
            return "pause.circle"
        }
    }
}
