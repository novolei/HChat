//
//  ChannelsContactsTabView.swift
//  HChat
//
//  Created on 2025-10-23.
//  📺 频道和通讯录合并视图 - 满屏沉浸式设计
//

import SwiftUI

struct ChannelsContactsTabView: View {
    let client: HackChatClient
    @State private var selectedTab = 0
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        ZStack(alignment: .top) {
            // 内容区域（满屏）
            TabView(selection: $selectedTab) {
                ChannelsView(client: client)
                    .tag(0)
                
                ContactsView(client: client)
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // 顶部浮动 Tab 切换器（极简设计）
            floatingTabSwitcher
                .padding(.top, 60)  // 贴近动态岛
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var floatingTabSwitcher: some View {
        HStack(spacing: 0) {
            tabButton(title: "频道", icon: "number", tag: 0)
            tabButton(title: "通讯录", icon: "person.2", tag: 1)
        }
        .padding(4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
        .padding(.horizontal, 20)
    }
    
    private func tabButton(title: String, icon: String, tag: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tag
                HapticManager.impact(style: .light)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: selectedTab == tag ? .semibold : .regular))
                
                Text(title)
                    .font(.system(size: 14, weight: selectedTab == tag ? .semibold : .regular))
            }
            .foregroundColor(selectedTab == tag ? .white : .white.opacity(0.6))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(selectedTab == tag ? Color.blue : Color.clear)
            )
        }
    }
}

