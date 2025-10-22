//
//  MemoryMoment.swift
//  HChat
//
//  Created by AI Assistant on 2025/10/22.
//  ✨ 数据模型：Encrypted Moments 记忆流
//

import Foundation
import SwiftUI

struct MemoryMoment: Identifiable, Hashable {
    enum AccentStyle: String, CaseIterable, Identifiable {
        case dawn
        case dusk
        case twilight
        case meadow
        
        var id: String { rawValue }
        
        var gradient: LinearGradient {
            switch self {
            case .dawn: return ModernTheme.dawnGradient
            case .dusk: return ModernTheme.duskGradient
            case .twilight: return ModernTheme.twilightGradient
            case .meadow: return ModernTheme.meadowGradient
            }
        }
    }
    
    enum ContentType: String, CaseIterable, Identifiable {
        case text
        case photo
        case voice
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .text: return "文字"
            case .photo: return "照片"
            case .voice: return "语音"
            }
        }
        
        var icon: String {
            switch self {
            case .text: return "text.bubble"
            case .photo: return "photo.on.rectangle"
            case .voice: return "waveform"
            }
        }
    }
    
    let id: UUID
    let title: String
    let detail: String
    let emotion: EmotionTag
    let timestamp: Date
    let contentType: ContentType
    let artwork: String?
    let accentStyle: AccentStyle
    
    var accentGradient: LinearGradient {
        accentStyle.gradient
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        emotion: EmotionTag,
        timestamp: Date,
        contentType: ContentType,
        artwork: String? = nil,
        accentStyle: AccentStyle = .dawn
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.emotion = emotion
        self.timestamp = timestamp
        self.contentType = contentType
        self.artwork = artwork
        self.accentStyle = accentStyle
    }
}

struct FavoriteContact: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let avatar: String
    let status: String
}

struct ChatPreview: Identifiable, Hashable {
    let id = UUID()
    let channel: String
    let lastMessage: String
    let timestamp: Date
}

enum EmotionTag: String, CaseIterable, Identifiable {
    case joy = "joy"
    case calm = "calm"
    case passion = "passion"
    case nostalgia = "nostalgia"
    case gratitude = "gratitude"
    case serenity = "serenity"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .joy: return "喜悦"
        case .calm: return "宁静"
        case .passion: return "热恋"
        case .nostalgia: return "回忆"
        case .gratitude: return "感恩"
        case .serenity: return "安心"
        }
    }
    
    var color: Color {
        switch self {
        case .joy: return ModernTheme.EmotionPalette.joy
        case .calm: return ModernTheme.EmotionPalette.calm
        case .passion: return ModernTheme.EmotionPalette.passion
        case .nostalgia: return ModernTheme.EmotionPalette.nostalgia
        case .gratitude: return ModernTheme.EmotionPalette.gratitude
        case .serenity: return ModernTheme.EmotionPalette.serenity
        }
    }
    
    var icon: String {
        switch self {
        case .joy: return "sparkles"
        case .calm: return "moon.stars"
        case .passion: return "heart.fill"
        case .nostalgia: return "clock.arrow.circlepath"
        case .gratitude: return "hands.sparkles"
        case .serenity: return "leaf"
        }
    }
}

extension MemoryMoment {
    static let sampleMoments: [MemoryMoment] = [
        MemoryMoment(
            title: "清晨一起跑步",
            detail: "第一次在秋天的微风里跑五公里，回家喝热可可。",
            emotion: .joy,
            timestamp: Date().addingTimeInterval(-3600),
            contentType: .photo,
            artwork: "moment-run",
            accentStyle: .dawn
        ),
        MemoryMoment(
            title: "深夜语音",
            detail: "聊到凌晨一点，互诉最近的小烦恼。",
            emotion: .serenity,
            timestamp: Date().addingTimeInterval(-7200),
            contentType: .voice,
            accentStyle: .twilight
        ),
        MemoryMoment(
            title: "秘密计划",
            detail: "一起制定新年的旅行清单，决定去看海。",
            emotion: .passion,
            timestamp: Date().addingTimeInterval(-86400),
            contentType: .text,
            accentStyle: .dusk
        )
    ]
}

extension FavoriteContact {
    static let sampleContacts: [FavoriteContact] = [
        FavoriteContact(name: "Kiki", avatar: "person.circle.fill", status: "刚刚分享了一张照片"),
        FavoriteContact(name: "Momo", avatar: "heart.circle.fill", status: "正在听我们的歌"),
        FavoriteContact(name: "Lynn", avatar: "face.smiling.fill", status: "今天完成了待办清单"),
        FavoriteContact(name: "Nora", avatar: "moon.stars.fill", status: "夜间模式打卡")
    ]
}

extension ChatPreview {
    static let sampleChats: [ChatPreview] = [
        ChatPreview(channel: "lobby", lastMessage: "记得明天带相机📷", timestamp: Date().addingTimeInterval(-1800)),
        ChatPreview(channel: "pm-SecretGarden", lastMessage: "我们周末去海边怎么样？", timestamp: Date().addingTimeInterval(-7200)),
        ChatPreview(channel: "moments-vault", lastMessage: "已添加新的胶囊记忆。", timestamp: Date().addingTimeInterval(-10800))
    ]
}
