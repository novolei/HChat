//
//  MainTabView.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//  🏠 主界面 - 4个Tab导航
//

import SwiftUI

struct MainTabView: View {
    var client: HackChatClient
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 1️⃣ 聊天列表（Channels + DMs）
            ChatsListView(client: client)
                .tabItem {
                    Label("聊天", systemImage: selectedTab == 0 ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
                }
                .tag(0)
            
            // 2️⃣ 当前聊天窗口
            ChatView(client: client)
                .tabItem {
                    Label("消息", systemImage: selectedTab == 1 ? "message.fill" : "message")
                }
                .tag(1)
            
            // 3️⃣ Explorer（探索）
            ExplorerView(client: client)
                .tabItem {
                    Label("探索", systemImage: selectedTab == 2 ? "safari.fill" : "safari")
                }
                .tag(2)
            
            // 4️⃣ Social（社交）
            SocialView(client: client)
                .tabItem {
                    Label("社交", systemImage: selectedTab == 3 ? "person.2.fill" : "person.2")
                }
                .tag(3)
        }
        .tint(ModernTheme.accent)
    }
}

