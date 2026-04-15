//
//  NetworkThroughput.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Foundation

struct NetworkThroughput: Equatable {
    let uploadBytesPerSecond: Double
    let downloadBytesPerSecond: Double

    static let zero = NetworkThroughput(
        uploadBytesPerSecond: 0,
        downloadBytesPerSecond: 0
    )
}
