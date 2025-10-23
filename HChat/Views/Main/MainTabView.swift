//
//  MainTabView.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//  Updated on 2025-10-23
//  🏠 主界面 - 4个Tab导航（微信/WhatsApp风格）
//

import SwiftUI

/// Tab 类型定义
enum AppTab: Int {
    case chats = 0      // 聊天（私聊 + 会话列表）
    case channels = 1   // 频道（群组频道）
    case contacts = 2   // 通讯录（在线用户）
    case me = 3         // 我（设置）
}

struct MainTabView: View {
    var client: HackChatClient
    @State private var selectedTab: AppTab = .chats
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 1️⃣ 聊天 Tab（私聊 + 会话列表）
            ConversationsView(client: client)
                .tabItem {
                    Label("聊天", systemImage: selectedTab == .chats ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
                }
                .tag(AppTab.chats)
                .badge(totalUnreadCount)
            
            // 2️⃣ 频道 Tab（群组频道）
            ChannelsView(client: client)
                .tabItem {
                    Label("频道", systemImage: selectedTab == .channels ? "number.square.fill" : "number.square")
                }
                .tag(AppTab.channels)
            
            // 3️⃣ 通讯录 Tab（在线用户）
            ContactsView(client: client)
                .tabItem {
                    Label("通讯录", systemImage: selectedTab == .contacts ? "person.2.fill" : "person.2")
                }
                .tag(AppTab.contacts)
                .badge(onlineCount)
            
            // 4️⃣ 我 Tab（设置）
            SettingsView(client: client)
                .tabItem {
                    Label("我", systemImage: selectedTab == .me ? "person.fill" : "person")
                }
                .tag(AppTab.me)
        }
        .tint(ModernTheme.accent)
    }
    
    // MARK: - 计算属性
    
    /// 总未读消息数（聊天 Tab 角标）
    private var totalUnreadCount: Int {
        client.state.conversations
            .filter { !$0.isMuted }  // 免打扰的会话不计入
            .reduce(0) { $0 + $1.unreadCount }
    }
    
    /// 在线用户数（通讯录 Tab 角标）
    private var onlineCount: Int {
        client.state.onlineStatuses.values
            .filter { $0.isOnline }
            .count
    }
}

