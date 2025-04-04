//
//  vm_netApp.swift
//  vm-net
//
//  Created by chen on 2025/4/4.
//

import AppKit
import Cocoa
import Foundation
import SwiftUI

@main
struct vm_netApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    var body: some Scene {
        // 保留 Setting 声明以免报错
        Settings {
        }
    }
}
