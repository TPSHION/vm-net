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
            return "准备诊断"
        case .checkingPath:
            return "检查网络路径"
        case .resolvingDNS:
            return "检查 DNS"
        case .checkingHTTPS:
            return "检查 HTTPS"
        case .completed:
            return "诊断完成"
        case .failed:
            return "诊断完成"
        case .cancelled:
            return "诊断已取消"
        }
    }

    var detail: String {
        switch self {
        case .idle:
            return "检查当前网络路径、DNS 和 HTTPS 连通性。"
        case .checkingPath:
            return "确认当前网络是否可达，以及走的是哪种网络路径。"
        case .resolvingDNS:
            return "测试诊断目标的域名解析和解析耗时。"
        case .checkingHTTPS:
            return "发起 HTTPS 请求，确认连接、握手和响应是否正常。"
        case .completed:
            return "诊断已完成，可以查看每一项检查结果。"
        case .failed:
            return "诊断没有完全通过，请查看异常项。"
        case .cancelled:
            return "诊断已中止，本次结果不会写入历史。"
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
