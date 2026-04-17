//
//  ProcessTrafficHelperBridge.swift
//  vm-net
//
//  Created by Codex on 2026/4/17.
//

import Foundation

final class ProcessTrafficHelperBridge {

    private var updateHandler: ((ProcessTrafficSnapshot) -> Void)?
    private var hasStarted = false

    func start(updateHandler: @escaping (ProcessTrafficSnapshot) -> Void) {
        guard !hasStarted else { return }

        hasStarted = true
        self.updateHandler = updateHandler

        DispatchQueue.main.async { [weak self] in
            self?.updateHandler?(ProcessTrafficSnapshot.unavailable())
        }
    }

    func stop() {
        updateHandler = nil
        hasStarted = false
    }
}
