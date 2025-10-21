//
//  Notifications+Haptics.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//

import Foundation
import UserNotifications
import UIKit
import AudioToolbox

enum Notify {
    static func requestAuth() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }
    static func fire(title: String, body: String) {
        let c = UNMutableNotificationContent()
        c.title = title; c.body = body; c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }
    static func hapticTap() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
    }
    static func vibrate() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}
