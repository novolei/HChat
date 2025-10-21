//
//  NotificationManager.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//

import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func notifyMention(channel: String, from: String, text: String) {
        let content = UNMutableNotificationContent()
        content.title = "@\(from) in \(channel)"
        content.body = text
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
