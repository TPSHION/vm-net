//
//  NetworkDiagnosisCheck.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Foundation

enum NetworkDiagnosisCheckKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case path
    case dns
    case https

    var id: String { rawValue }

    var title: String {
        switch self {
        case .path:
            return "网络路径"
        case .dns:
            return "DNS 解析"
        case .https:
            return "HTTPS 连通性"
        }
    }
}

enum NetworkDiagnosisCheckStatus: String, Codable, Equatable, Sendable {
    case success
    case warning
    case failure
    case skipped

    var title: String {
        switch self {
        case .success:
            return "正常"
        case .warning:
            return "注意"
        case .failure:
            return "异常"
        case .skipped:
            return "已跳过"
        }
    }
}

struct NetworkDiagnosisCheck: Codable, Equatable, Identifiable, Sendable {
    var id: NetworkDiagnosisCheckKind { kind }

    let kind: NetworkDiagnosisCheckKind
    let status: NetworkDiagnosisCheckStatus
    let summary: String
    let detail: String?
}
