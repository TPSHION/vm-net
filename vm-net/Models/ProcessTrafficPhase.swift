//
//  ProcessTrafficPhase.swift
//  vm-net
//
//  Created by Codex on 2026/4/17.
//

import Foundation

enum ProcessTrafficPhase: Equatable {
    case idle
    case streaming
    case unavailable
    case failed
}
