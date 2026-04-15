//
//  ByteRateFormatter.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Foundation

struct ByteRateFormatter {

    enum Style {
        case compact
        case detailed
    }

    func string(
        for bytesPerSecond: Double,
        style: Style = .compact
    ) -> String {
        let rate = max(bytesPerSecond, 0)

        switch style {
        case .compact:
            return compactString(for: rate)
        case .detailed:
            return detailedString(for: rate)
        }
    }

    private func compactString(for rate: Double) -> String {
        let kilobyte = 1024.0
        let megabyte = kilobyte * 1024
        let gigabyte = megabyte * 1024

        switch rate {
        case 0..<kilobyte:
            return "\(Int(rate.rounded(.down)))B/s"
        case kilobyte..<(10 * kilobyte):
            return compactScaled(rate / kilobyte, unit: "K", allowsDecimal: true)
        case (10 * kilobyte)..<megabyte:
            return compactScaled(rate / kilobyte, unit: "K", allowsDecimal: false)
        case megabyte..<(10 * megabyte):
            return compactScaled(rate / megabyte, unit: "M", allowsDecimal: true)
        case (10 * megabyte)..<gigabyte:
            return compactScaled(rate / megabyte, unit: "M", allowsDecimal: false)
        case gigabyte..<(10 * gigabyte):
            return compactScaled(rate / gigabyte, unit: "G", allowsDecimal: true)
        case (10 * gigabyte)..<(1000 * gigabyte):
            return compactScaled(rate / gigabyte, unit: "G", allowsDecimal: false)
        default:
            return "999G/s+"
        }
    }

    private func detailedString(for rate: Double) -> String {
        let kilobyte = 1024.0
        let megabyte = kilobyte * 1024
        let gigabyte = megabyte * 1024

        switch rate {
        case gigabyte...:
            return detailedScaled(rate / gigabyte, unit: "G")
        case megabyte...:
            return detailedScaled(rate / megabyte, unit: "M")
        case kilobyte...:
            return detailedScaled(rate / kilobyte, unit: "K")
        default:
            return "\(Int(rate.rounded())) B/s"
        }
    }

    private func compactScaled(
        _ value: Double,
        unit: String,
        allowsDecimal: Bool
    ) -> String {
        let displayValue =
            allowsDecimal
            ? (value * 10).rounded(.down) / 10
            : value.rounded(.down)
        let format = allowsDecimal ? "%.1f" : "%.0f"
        let number = String(
            format: format,
            locale: Locale.current,
            displayValue
        )

        return "\(number)\(unit)/s"
    }

    private func detailedScaled(
        _ value: Double,
        unit: String
    ) -> String {
        let decimals = value < 10 ? 1 : 0
        let format = decimals == 1 ? "%.1f" : "%.0f"
        let number = String(format: format, locale: Locale.current, value)

        return "\(number) \(unit)B/s"
    }
}
