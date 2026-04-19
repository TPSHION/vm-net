//
//  NSScreen+DisplayIdentifier.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit
import CoreGraphics

extension NSScreen {

    var cgDisplayID: CGDirectDisplayID? {
        guard
            let screenNumber = deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? NSNumber
        else {
            return nil
        }

        return CGDirectDisplayID(screenNumber.uint32Value)
    }

    var displayIdentifier: String? {
        cgDisplayID.map { String($0) }
    }
}
