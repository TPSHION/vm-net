//
//  NetworkMonitor.swift
//  vm-net
//
//  Created by chen on 2025/4/4.
//
import Cocoa

class NetworkMonitor {
    private var lastSent: UInt64 = 0
    private var lastReceived: UInt64 = 0
    private var timer: DispatchSourceTimer?

    var updateHandler: ((String, String) -> Void)?

    init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        let queue = DispatchQueue.global(qos: .utility)
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: 2.0) // 可调间隔
        timer?.setEventHandler { [self] in
            self.updateStats()
        }
        timer?.resume()
    }
    
    deinit {
        timer?.cancel()
    }

    private func getNetworkStats() -> (sent: UInt64, received: UInt64) {
        var mib = [CTL_NET, AF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0

        // 获取缓冲区长度
        guard sysctl(&mib, UInt32(mib.count), nil, &length, nil, 0) == 0 else {
            return (0, 0)
        }

        // 分配内存并读取数据
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
        defer { buffer.deallocate() }

        guard sysctl(&mib, UInt32(mib.count), buffer, &length, nil, 0) == 0
        else {
            return (0, 0)
        }

        var currentPointer = buffer
        let endPointer = buffer + length
        var totalSent: UInt64 = 0
        var totalReceived: UInt64 = 0

        // 使用明确的类型转换
        while currentPointer < endPointer {
            let header = currentPointer.withMemoryRebound(
                to: if_msghdr.self,
                capacity: 1
            ) { $0.pointee }
            if header.ifm_type == RTM_IFINFO2 {
                let info = currentPointer.withMemoryRebound(
                    to: if_msghdr2.self,
                    capacity: 1
                ) { $0.pointee }
                totalReceived += info.ifm_data.ifi_ibytes
                totalSent += info.ifm_data.ifi_obytes
            }
            currentPointer += Int(header.ifm_msglen)
        }

        return (totalSent, totalReceived)
    }

    private func updateStats() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            let (currentSent, currentReceived) = getNetworkStats()
            let sentSpeed = currentSent - lastSent
            let receivedSpeed = currentReceived - lastReceived
            
            let uploadStr = "\(format(speed: sentSpeed)) ↑"
            let downloadStr = "\(format(speed: receivedSpeed)) ↓"
            
            // 主线程更新 UI
            DispatchQueue.main.async { [self] in
                self.lastSent = currentSent
                self.lastReceived = currentReceived

                self.updateHandler?(uploadStr, downloadStr)
            }
        }
        
    }

    private func format(speed: UInt64) -> String {
        let kb = speed / 1024
        let mb = kb / 1024
        let GB = mb / 1024
        if GB > 0 {
            return "\(GB) GB/s"
        } else if mb > 0 {
            return "\(mb) MB/s"
        } else if kb > 0 {
            return "\(kb) KB/s"
        } else {
            return "\(speed) B/s"
        }
    }
}
