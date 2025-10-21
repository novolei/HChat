//
//  SmartNotificationManager.swift
//  HChat
//
//  Created by AI Assistant on 2025/10/21.
//  智能通知管理器 - 优先级、免打扰、分组
//

import Foundation
import UserNotifications
import Observation

/// 通知优先级
enum NotificationPriority {
    case urgent     // 紧急：@mention、私聊、关键词
    case normal     // 普通：频道消息
    case silent     // 静音：已屏蔽频道
    
    var soundName: UNNotificationSoundName {
        switch self {
        case .urgent: return .default
        case .normal: return .defaultCritical
        case .silent: return .init(rawValue: "")
        }
    }
    
    var interruptionLevel: UNNotificationInterruptionLevel {
        switch self {
        case .urgent: return .timeSensitive
        case .normal: return .active
        case .silent: return .passive
        }
    }
}

@MainActor
@Observable
final class SmartNotificationManager {
    // MARK: - 单例
    static let shared = SmartNotificationManager()
    
    // MARK: - 设置
    private let settingsKey = "notificationSettings"
    
    /// 通知设置
    struct Settings: Codable {
        var enabled: Bool = true
        var urgentOnly: Bool = false
        var keywords: [String] = []
        var mutedChannels: [String] = []
        var workingHours: WorkingHours? = WorkingHours()
        var groupByChannel: Bool = true
        
        struct WorkingHours: Codable {
            var enabled: Bool = true
            var startHour: Int = 9    // 9:00
            var endHour: Int = 18      // 18:00
            var weekdaysOnly: Bool = true
        }
    }
    
    var settings: Settings {
        get {
            guard let data = UserDefaults.standard.data(forKey: settingsKey),
                  let decoded = try? JSONDecoder().decode(Settings.self, from: data) else {
                return Settings()
            }
            return decoded
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: settingsKey)
            }
        }
    }
    
    // MARK: - 初始化
    private init() {
        Task {
            await requestPermission()
        }
    }
    
    // MARK: - 权限管理
    
    /// 请求通知权限
    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            
            if granted {
                DebugLogger.log("✅ 通知权限已授予", level: .info)
            } else {
                DebugLogger.log("⚠️ 通知权限被拒绝", level: .warning)
            }
        } catch {
            DebugLogger.log("❌ 请求通知权限失败: \(error)", level: .error)
        }
    }
    
    // MARK: - 发送通知
    
    /// 智能通知（根据优先级和设置）
    func notifyMessage(_ message: ChatMessage, myNick: String) async {
        // 检查是否启用通知
        guard settings.enabled else { return }
        
        // 确定优先级
        let priority = determinePriority(for: message, myNick: myNick)
        
        // 检查是否应该通知
        guard shouldNotify(priority: priority, channel: message.channel) else {
            DebugLogger.log("🔕 消息不通知: \(message.id)", level: .debug)
            return
        }
        
        // 构建通知内容
        let content = buildNotificationContent(for: message, priority: priority)
        
        // 发送通知
        await send(content: content, identifier: message.id)
    }
    
    /// @mention 通知（高优先级）
    func notifyMention(channel: String, from: String, text: String) async {
        guard settings.enabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "@提及 · #\(channel)"
        content.body = "\(from): \(text)"
        content.sound = NotificationPriority.urgent.soundName
        content.threadIdentifier = channel
        content.interruptionLevel = NotificationPriority.urgent.interruptionLevel
        content.badge = NSNumber(value: 1)
        
        await send(content: content, identifier: "mention-\(UUID().uuidString)")
    }
    
    // MARK: - 优先级判断
    
    /// 确定消息优先级
    func determinePriority(for message: ChatMessage, myNick: String) -> NotificationPriority {
        // 1. 私聊 = 紧急
        if message.channel.hasPrefix("pm/") {
            return .urgent
        }
        
        // 2. @提及 = 紧急
        if message.text.contains("@\(myNick)") {
            return .urgent
        }
        
        // 3. 关键词匹配 = 紧急
        if containsKeywords(message.text) {
            return .urgent
        }
        
        // 4. 静音频道 = 静音
        if settings.mutedChannels.contains(message.channel) {
            return .silent
        }
        
        // 5. 其他 = 普通
        return .normal
    }
    
    /// 检查是否应该通知
    func shouldNotify(priority: NotificationPriority, channel: String) -> Bool {
        // 静音频道不通知
        if priority == .silent {
            return false
        }
        
        // 仅紧急消息模式
        if settings.urgentOnly && priority != .urgent {
            return false
        }
        
        // 工作时间判断
        if isWorkingHours() {
            // 工作时间：只通知紧急消息
            return priority == .urgent
        } else {
            // 非工作时间：通知所有非静音消息
            return priority != .silent
        }
    }
    
    // MARK: - 工作时间判断
    
    /// 判断是否在工作时间
    func isWorkingHours() -> Bool {
        guard let workingHours = settings.workingHours, workingHours.enabled else {
            return false
        }
        
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)
        
        // 检查是否工作日（周一到周五）
        if workingHours.weekdaysOnly {
            let isWeekday = (2...6).contains(weekday) // 1=周日, 2=周一, ..., 7=周六
            if !isWeekday {
                return false
            }
        }
        
        // 检查是否在工作时间内
        return (workingHours.startHour...workingHours.endHour).contains(hour)
    }
    
    // MARK: - 私有方法
    
    /// 检查关键词匹配
    private func containsKeywords(_ text: String) -> Bool {
        let lowercasedText = text.lowercased()
        return settings.keywords.contains { keyword in
            lowercasedText.contains(keyword.lowercased())
        }
    }
    
    /// 构建通知内容
    private func buildNotificationContent(
        for message: ChatMessage,
        priority: NotificationPriority
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        
        // 标题
        if message.channel.hasPrefix("pm/") {
            content.title = "💬 私聊 · \(message.sender)"
        } else {
            content.title = "#\(message.channel) · \(message.sender)"
        }
        
        // 内容
        if !message.text.isEmpty {
            content.body = message.text
        } else if !message.attachments.isEmpty {
            let attachment = message.attachments[0]
            content.body = "[\(attachment.kind.rawValue)] \(attachment.filename)"
        }
        
        // 声音和优先级
        content.sound = priority.soundName
        content.interruptionLevel = priority.interruptionLevel
        
        // 分组（按频道）
        if settings.groupByChannel {
            content.threadIdentifier = message.channel
            content.summaryArgument = message.channel
        }
        
        // Badge
        content.badge = NSNumber(value: 1)
        
        return content
    }
    
    /// 发送通知
    private func send(content: UNMutableNotificationContent, identifier: String) async {
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil  // 立即发送
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            DebugLogger.log("🔔 通知已发送: \(identifier)", level: .info)
        } catch {
            DebugLogger.log("❌ 发送通知失败: \(error)", level: .error)
        }
    }
}

