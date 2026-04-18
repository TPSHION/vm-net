//
//  ProcessTerminationService.swift
//  vm-net
//
//  Created by Codex on 2026/4/17.
//

import AppKit
import Darwin
import Foundation

enum ProcessTerminationMode {
    case graceful
    case force
}

enum ProcessTerminationError: LocalizedError {
    case invalidProcessID
    case cannotTerminateCurrentApp
    case signalFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidProcessID:
            return L10n.tr("activity.process.action.error.invalidPID")
        case .cannotTerminateCurrentApp:
            return L10n.tr("activity.process.action.error.currentApp")
        case let .signalFailed(reason):
            return reason
        }
    }
}

struct ProcessTerminationResult {
    let process: ProcessTrafficProcessRecord
    let mode: ProcessTerminationMode
}

@MainActor
final class ProcessTerminationService {

    func terminate(
        _ process: ProcessTrafficProcessRecord,
        mode: ProcessTerminationMode
    ) throws -> ProcessTerminationResult {
        guard process.pid > 1 else {
            throw ProcessTerminationError.invalidProcessID
        }

        guard process.pid != getpid() else {
            throw ProcessTerminationError.cannotTerminateCurrentApp
        }

        switch mode {
        case .graceful:
            try terminateGracefully(process.pid)
        case .force:
            try forceTerminate(process.pid)
        }

        return ProcessTerminationResult(process: process, mode: mode)
    }

    private func terminateGracefully(_ pid: Int32) throws {
        if let application = NSRunningApplication(processIdentifier: pid),
           application.terminate() {
            return
        }

        try sendSignal(SIGTERM, to: pid)
    }

    private func forceTerminate(_ pid: Int32) throws {
        if let application = NSRunningApplication(processIdentifier: pid),
           application.forceTerminate() {
            return
        }

        try sendSignal(SIGKILL, to: pid)
    }

    private func sendSignal(_ signal: Int32, to pid: Int32) throws {
        guard kill(pid, signal) == 0 else {
            let message = String(cString: strerror(errno))
            throw ProcessTerminationError.signalFailed(message)
        }
    }
}
