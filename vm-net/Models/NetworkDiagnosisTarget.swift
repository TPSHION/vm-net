//
//  NetworkDiagnosisTarget.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Foundation

enum NetworkDiagnosisTarget: String, CaseIterable, Identifiable, Sendable {
    case cloudflare = "www.cloudflare.com"
    case baidu = "www.baidu.com"
    case google = "www.google.com"
    case apple = "www.apple.com"

    var id: String { rawValue }

    var host: String { rawValue }

    var title: String { rawValue }
}
