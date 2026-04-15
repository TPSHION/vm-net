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
            return "准备测速"
        case .locatingServer:
            return "选择节点"
        case .measuringDownload:
            return "下载测速"
        case .measuringUpload:
            return "上传测速"
        case .completed:
            return "测速完成"
        case .failed:
            return "测速失败"
        case .cancelled:
            return "测速已取消"
        }
    }

    var detail: String {
        switch self {
        case .idle:
            return "手动发起一次完整的网络测速。"
        case .locatingServer:
            return "正在选择距离更近、状态更好的 M-Lab 节点。"
        case .measuringDownload:
            return "正在持续拉取测试流量，测量当前下载带宽。"
        case .measuringUpload:
            return "正在持续发送测试流量，测量当前上传带宽。"
        case .completed:
            return "本次测速已经完成，可以查看结果或再次开始。"
        case .failed:
            return "本次测速没有成功完成，可以稍后重试。"
        case .cancelled:
            return "测速已手动中止，当前结果不会写入历史。"
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
