//
//  SystemNetworkCountersReader.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Foundation
import SystemConfiguration

protocol NetworkCountersReading {
    func readSnapshot() -> NetworkCountersSnapshot?
}

final class SystemNetworkCountersReader: NetworkCountersReading {

    private let interfaceProvider: ActiveNetworkInterfaceProviding

    init(
        interfaceProvider: ActiveNetworkInterfaceProviding
            = PrimaryNetworkInterfaceProvider()
    ) {
        self.interfaceProvider = interfaceProvider
    }

    func readSnapshot() -> NetworkCountersSnapshot? {
        let preferredInterfaces = Set(interfaceProvider.currentInterfaceNames())

        return preferredSnapshot(for: preferredInterfaces) ?? fallbackSnapshot()
    }

    private func preferredSnapshot(
        for preferredInterfaces: Set<String>
    ) -> NetworkCountersSnapshot? {
        guard !preferredInterfaces.isEmpty else { return nil }

        return loadCounters { interfaceName, _ in
            preferredInterfaces.contains(interfaceName)
        }
    }

    private func fallbackSnapshot() -> NetworkCountersSnapshot? {
        loadCounters { interfaceName, _ in
            Self.isFallbackInterface(interfaceName)
        }
    }

    private func loadCounters(
        where shouldInclude: (String, Int32) -> Bool
    ) -> NetworkCountersSnapshot? {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else {
            return nil
        }
        defer { freeifaddrs(pointer) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        var visitedNames = Set<String>()
        var interfaceNames: [String] = []
        var interfaceCounters: [String: NetworkCountersSnapshot.InterfaceCounters] =
            [:]

        while let current = cursor {
            let interface = current.pointee
            cursor = interface.ifa_next

            guard
                let namePointer = interface.ifa_name,
                let address = interface.ifa_addr,
                address.pointee.sa_family == UInt8(AF_LINK),
                let data = interface.ifa_data
            else {
                continue
            }

            let name = String(cString: namePointer)
            let flags = Int32(interface.ifa_flags)

            guard
                Self.isUsableInterface(name, flags: flags),
                shouldInclude(name, flags),
                visitedNames.insert(name).inserted
            else {
                continue
            }

            let counters = data.assumingMemoryBound(to: if_data.self).pointee
            interfaceNames.append(name)
            interfaceCounters[name] = NetworkCountersSnapshot.InterfaceCounters(
                sentBytes: UInt64(counters.ifi_obytes),
                receivedBytes: UInt64(counters.ifi_ibytes)
            )
        }

        guard !interfaceNames.isEmpty else { return nil }

        return NetworkCountersSnapshot(
            interfaceNames: interfaceNames.sorted(),
            interfaceCounters: interfaceCounters,
            timestamp: Date()
        )
    }

    private static func isUsableInterface(_ name: String, flags: Int32) -> Bool {
        (flags & IFF_UP) != 0
            && (flags & IFF_RUNNING) != 0
            && (flags & IFF_LOOPBACK) == 0
            && !name.isEmpty
    }

    private static func isFallbackInterface(_ name: String) -> Bool {
        let preferredPrefixes = ["en", "bridge", "pdp_ip", "utun", "ipsec", "ppp"]

        return preferredPrefixes.contains { name.hasPrefix($0) }
    }
}

protocol ActiveNetworkInterfaceProviding {
    func currentInterfaceNames() -> [String]
}

final class PrimaryNetworkInterfaceProvider: ActiveNetworkInterfaceProviding {

    private let store: SCDynamicStore?

    init() {
        self.store = SCDynamicStoreCreate(
            nil,
            "cn.tpshion.vm-net.primary-interface-provider" as CFString,
            nil,
            nil
        )
    }

    func currentInterfaceNames() -> [String] {
        guard let store else { return [] }

        let keys = [
            "State:/Network/Global/IPv4",
            "State:/Network/Global/IPv6",
        ]
        var names: [String] = []

        for key in keys {
            guard
                let dictionary = SCDynamicStoreCopyValue(store, key as CFString)
                    as? [String: Any],
                let primaryInterface = dictionary["PrimaryInterface"] as? String,
                !primaryInterface.isEmpty
            else {
                continue
            }

            names.append(primaryInterface)
        }

        return Array(Set(names)).sorted()
    }
}
