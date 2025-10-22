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
    @State private var showChatView = false
    @State private var selectedChannel: String?
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                // 1️⃣ Moments Hub（记忆流）
                MomentsHomeView(client: client)
                    .tabItem {
                        Label("记忆", systemImage: selectedTab == 0 ? "sparkles.rectangle.fill" : "sparkles.rectangle")
                    }
                    .tag(0)
                
                // 2️⃣ Explorer（探索）
                ExplorerView(client: client)
                    .tabItem {
                        Label("探索", systemImage: selectedTab == 1 ? "safari.fill" : "safari")
                    }
                    .tag(1)
                
                // 3️⃣ Personalization（私感）
                PersonalizationView(client: client)
                    .tabItem {
                        Label("私感", systemImage: selectedTab == 2 ? "slider.horizontal.3" : "slider.horizontal.3")
                    }
                    .tag(2)
            }
            .tint(ModernTheme.accent)
            .navigationDestination(isPresented: $showChatView) {
                ChatView(client: client)
                    .navigationBarBackButtonHidden(false)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToChatView"))) { notification in
            if let channel = notification.object as? String {
                selectedChannel = channel
                client.sendText("/join \(channel)")
                showChatView = true
            }
        }
    }
}

