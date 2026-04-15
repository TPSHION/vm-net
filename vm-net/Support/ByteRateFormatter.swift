//
//  ByteRateFormatter.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Foundation

struct ByteRateFormatter {

    private static let valueFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    func string(for bytesPerSecond: Double) -> String {
        let rate = max(bytesPerSecond, 0)
        let kilobyte = 1024.0
        let megabyte = kilobyte * 1024
        let gigabyte = megabyte * 1024

        switch rate {
        case gigabyte...:
            return formatted(rate / gigabyte, unit: "GB")
        case megabyte...:
            return formatted(rate / megabyte, unit: "MB")
        case kilobyte...:
            return formatted(rate / kilobyte, unit: "KB")
        default:
            return "\(Int(rate.rounded())) B/s"
        }
    }

    private func formatted(_ value: Double, unit: String) -> String {
        let number = Self.valueFormatter.string(from: NSNumber(value: value))
            ?? String(value)

        return "\(number) \(unit)/s"
    }
}
