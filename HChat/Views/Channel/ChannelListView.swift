//
//  ChannelListView.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//  ✨ UI优化：美化频道列表，添加图标、色彩和视觉层次
//

import SwiftUI

struct ChannelListView: View {
    let channels: [Channel]
    let current: String
    var onSelect: (String) -> Void
    var onCreate: () -> Void
    var onStartDM: () -> Void

    var body: some View {
        List {
            // 频道列表
            Section {
                ForEach(channels) { ch in
                    ChannelRowView(
                        channel: ch,
                        isCurrent: ch.name == current,
                        onTap: {
                            HapticManager.selection()
                            onSelect(ch.name)
                        }
                    )
                }
            } header: {
                HStack {
                    Image(systemName: "number.circle.fill")
                        .font(.caption)
                    Text("频道")
                }
                .foregroundColor(HChatTheme.secondaryText)
            }

            // 操作区域
            Section {
                Button {
                    HapticManager.impact(style: .light)
                    onCreate()
                } label: {
                    Label {
                        Text("新建频道")
                            .font(HChatTheme.bodyFont)
                    } icon: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(HChatTheme.accent)
                    }
                }
                
                Button {
                    HapticManager.impact(style: .light)
                    onStartDM()
                } label: {
                    Label {
                        Text("开始私聊")
                            .font(HChatTheme.bodyFont)
                    } icon: {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .foregroundStyle(HChatTheme.secondaryAccent)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("频道")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - 📋 频道行视图

struct ChannelRowView: View {
    let channel: Channel
    let isCurrent: Bool
    let onTap: () -> Void
    
    // 频道图标
    private var channelIcon: String {
        if channel.name.hasPrefix("pm-") {
            return "person.2.fill"
        } else if channel.name == "lobby" {
            return "house.fill"
        } else {
            return "number"
        }
    }
    
    // 频道图标颜色
    private var iconColor: Color {
        if isCurrent {
            return HChatTheme.accent
        } else if channel.unreadCount > 0 {
            return HChatTheme.warning
        } else {
            return HChatTheme.tertiaryText
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: HChatTheme.mediumSpacing) {
                // 频道图标
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: channelIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                
                VStack(alignment: .leading, spacing: HChatTheme.tinySpacing) {
                    // 频道名称
                    Text("#\(channel.name)")
                        .font(isCurrent ? HChatTheme.buttonFont : HChatTheme.bodyFont)
                        .foregroundColor(isCurrent ? HChatTheme.accent : HChatTheme.primaryText)
                    
                    // 频道描述（如果有未读消息）
                    if channel.unreadCount > 0 {
                        Text("\(channel.unreadCount) 条未读消息")
                            .font(HChatTheme.captionFont)
                            .foregroundColor(HChatTheme.secondaryText)
                    }
                }
                
                Spacer()
                
                // 未读标记
                if channel.unreadCount > 0 {
                    UnreadBadgeView(count: channel.unreadCount)
                }
                
                // 当前频道指示器
                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(HChatTheme.accent)
                }
            }
            .padding(.vertical, HChatTheme.tinySpacing)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 🔴 未读标记视图

struct UnreadBadgeView: View {
    let count: Int
    
    var body: some View {
        Text("\(count)")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [HChatTheme.error, HChatTheme.error.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: HChatTheme.error.opacity(0.3), radius: 3, x: 0, y: 2)
    }
}
