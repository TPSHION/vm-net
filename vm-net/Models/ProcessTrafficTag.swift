//
//  ProcessTrafficTag.swift
//  vm-net
//
//  Created by Codex on 2026/4/19.
//

import Foundation

enum ProcessTrafficTag: String, Equatable, Hashable, CaseIterable {
    case highDownload
    case highUpload
    case backgroundActive
    case retryLike
    case burst
}
