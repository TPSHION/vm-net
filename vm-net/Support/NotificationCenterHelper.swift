//
//  NotificationCenterHelper.swift
//  vm-net
//
//  Created by Codex on 2026/4/17.
//

import Foundation
import UserNotifications

final class NotificationCenterHelper {

    private let center = UNUserNotificationCenter.current()

    func requestAuthorizationIfNeeded() {
        center.getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .notDetermined else { return }

            self?.center.requestAuthorization(options: [.alert, .sound]) { _, _ in
            }
        }
    }

    func postNetworkAnomaly(_ anomaly: NetworkAnomaly) {
        let content = UNMutableNotificationContent()
        content.title = anomaly.headline
        content.body = anomaly.summary
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "network-anomaly-\(anomaly.id.uuidString)",
            content: content,
            trigger: nil
        )

        center.add(request)
    }
}
