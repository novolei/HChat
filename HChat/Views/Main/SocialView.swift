//
//  SocialView.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//  👥 Social - 社交和设置
//

import SwiftUI

struct SocialView: View {
    var client: HackChatClient
    
    @State private var selectedTab: SocialTab = .friends
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                ModernTheme.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: ModernTheme.spacing5) {
                        // 个人卡片
                        ProfileCard(client: client)
                            .padding(.horizontal, ModernTheme.spacing4)
                        
                        // Tab选择器
                        SocialTabPicker(selectedTab: $selectedTab)
                            .padding(.horizontal, ModernTheme.spacing4)
                        
                        // 内容区域
                        switch selectedTab {
                        case .friends:
                            FriendsSection(client: client)
                        case .activity:
                            ActivitySection(client: client)
                        case .settings:
                            SettingsSection(client: client)
                        }
                        
                        Spacer(minLength: 60)
                    }
                    .padding(.top, ModernTheme.spacing3)
                }
            }
            .navigationTitle("社交")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                        HapticManager.impact(style: .light)
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(ModernTheme.accent)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(client: client)
            }
        }
    }
}

// MARK: - 🎯 Social Tab

enum SocialTab: String, CaseIterable {
    case friends = "好友"
    case activity = "动态"
    case settings = "设置"
    
    var icon: String {
        switch self {
        case .friends: return "person.2.fill"
        case .activity: return "bell.fill"
        case .settings: return "slider.horizontal.3"
        }
    }
}

// MARK: - 👤 个人卡片

struct ProfileCard: View {
    var client: HackChatClient
    
    var body: some View {
        HStack(spacing: ModernTheme.spacing4) {
            // 头像
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            ModernTheme.accent,
                            ModernTheme.accent.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 70, height: 70)
                .overlay(
                    Text(client.myNick.prefix(1).uppercased())
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                )
                .shadow(color: ModernTheme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
            
            VStack(alignment: .leading, spacing: ModernTheme.spacing1) {
                Text(client.myNick)
                    .font(ModernTheme.title2)
                    .foregroundColor(ModernTheme.primaryText)
                
                HStack(spacing: ModernTheme.spacing2) {
                    Circle()
                        .fill(ModernTheme.success)
                        .frame(width: 10, height: 10)
                    
                    Text(client.presenceManager.myStatus.displayName)
                        .font(ModernTheme.subheadline)
                        .foregroundColor(ModernTheme.secondaryText)
                }
                
                Text("在 \(client.currentChannel)")
                    .font(ModernTheme.caption)
                    .foregroundColor(ModernTheme.tertiaryText)
            }
            
            Spacer()
        }
        .padding(ModernTheme.spacing4)
        .background(
            LinearGradient(
                colors: [
                    ModernTheme.cardBackground,
                    ModernTheme.secondaryBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: ModernTheme.largeRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ModernTheme.largeRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            ModernTheme.accent.opacity(0.2),
                            ModernTheme.accent.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: ModernTheme.cardShadow, radius: 12, x: 0, y: 6)
    }
}

// MARK: - 🎯 Social Tab选择器

struct SocialTabPicker: View {
    @Binding var selectedTab: SocialTab
    
    var body: some View {
        HStack(spacing: ModernTheme.spacing2) {
            ForEach(SocialTab.allCases, id: \.self) { tab in
                SocialTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab
                ) {
                    withAnimation(ModernTheme.standardSpring) {
                        selectedTab = tab
                    }
                    HapticManager.selection()
                }
            }
        }
        .padding(ModernTheme.spacing1)
        .background(ModernTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ModernTheme.mediumRadius, style: .continuous))
        .shadow(color: ModernTheme.cardShadow, radius: 4, x: 0, y: 2)
    }
}

struct SocialTabButton: View {
    let tab: SocialTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: ModernTheme.spacing2) {
                Image(systemName: tab.icon)
                    .font(.caption)
                Text(tab.rawValue)
                    .font(ModernTheme.subheadline)
            }
            .foregroundColor(isSelected ? .white : ModernTheme.secondaryText)
            .padding(.horizontal, ModernTheme.spacing4)
            .padding(.vertical, ModernTheme.spacing2)
            .background(
                isSelected ? ModernTheme.accent : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: ModernTheme.smallRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 👥 好友区域

struct FriendsSection: View {
    var client: HackChatClient
    
    private var onlineUsers: [String] {
        Array(client.state.onlineByRoom[client.currentChannel] ?? [])
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernTheme.spacing4) {
            SectionHeader(
                icon: "person.2.fill",
                title: "在线好友 (\(onlineUsers.count))",
                iconColor: ModernTheme.success
            )
            .padding(.horizontal, ModernTheme.spacing4)
            
            VStack(spacing: ModernTheme.spacing2) {
                ForEach(onlineUsers, id: \.self) { user in
                    FriendRow(username: user, isOnline: true)
                        .padding(.horizontal, ModernTheme.spacing4)
                }
            }
            
            if onlineUsers.isEmpty {
                EmptyStateCard(
                    icon: "person.2.slash",
                    message: "暂无在线好友"
                )
                .padding(.horizontal, ModernTheme.spacing4)
            }
        }
    }
}

// MARK: - 🔔 动态区域

struct ActivitySection: View {
    var client: HackChatClient
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernTheme.spacing4) {
            SectionHeader(
                icon: "bell.fill",
                title: "最近动态",
                iconColor: ModernTheme.warning
            )
            .padding(.horizontal, ModernTheme.spacing4)
            
            VStack(spacing: ModernTheme.spacing2) {
                ActivityCard(
                    icon: "message.fill",
                    title: "新消息",
                    description: "收到来自 lobby 的消息",
                    time: "2分钟前",
                    color: ModernTheme.accent
                )
                .padding(.horizontal, ModernTheme.spacing4)
                
                ActivityCard(
                    icon: "person.badge.plus",
                    title: "新用户加入",
                    description: "有人加入了 #lobby",
                    time: "10分钟前",
                    color: ModernTheme.success
                )
                .padding(.horizontal, ModernTheme.spacing4)
                
                ActivityCard(
                    icon: "at",
                    title: "提及你",
                    description: "@\(client.myNick) 在消息中提到了你",
                    time: "1小时前",
                    color: ModernTheme.warning
                )
                .padding(.horizontal, ModernTheme.spacing4)
            }
        }
    }
}

// MARK: - ⚙️ 设置区域

struct SettingsSection: View {
    var client: HackChatClient
    
    var body: some View {
        VStack(spacing: ModernTheme.spacing2) {
            SettingRow(
                icon: "bell.fill",
                title: "通知设置",
                color: ModernTheme.warning
            ) {
                // TODO: 打开通知设置
            }
            .padding(.horizontal, ModernTheme.spacing4)
            
            SettingRow(
                icon: "moon.fill",
                title: "外观设置",
                color: ModernTheme.secondaryAccent
            ) {
                // TODO: 打开外观设置
            }
            .padding(.horizontal, ModernTheme.spacing4)
            
            SettingRow(
                icon: "lock.fill",
                title: "隐私设置",
                color: ModernTheme.accent
            ) {
                // TODO: 打开隐私设置
            }
            .padding(.horizontal, ModernTheme.spacing4)
            
            SettingRow(
                icon: "info.circle.fill",
                title: "关于 HChat",
                color: ModernTheme.tertiaryText
            ) {
                // TODO: 打开关于页面
            }
            .padding(.horizontal, ModernTheme.spacing4)
        }
    }
}

// MARK: - 👤 好友行

struct FriendRow: View {
    let username: String
    let isOnline: Bool
    
    private var userColor: Color {
        let colors: [Color] = [
            ModernTheme.accent,
            ModernTheme.secondaryAccent,
            ModernTheme.success,
            ModernTheme.warning
        ]
        let index = abs(username.hashValue) % colors.count
        return colors[index]
    }
    
    var body: some View {
        HStack(spacing: ModernTheme.spacing3) {
            // 头像
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                userColor.opacity(0.3),
                                userColor.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(username.prefix(1).uppercased())
                            .font(ModernTheme.title3)
                            .foregroundColor(userColor)
                    )
                
                if isOnline {
                    Circle()
                        .fill(ModernTheme.success)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(ModernTheme.cardBackground, lineWidth: 2.5)
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: ModernTheme.spacing1) {
                Text(username)
                    .font(ModernTheme.bodyBold)
                    .foregroundColor(ModernTheme.primaryText)
                
                Text(isOnline ? "在线" : "离线")
                    .font(ModernTheme.caption)
                    .foregroundColor(ModernTheme.secondaryText)
            }
            
            Spacer()
            
            Button {
                HapticManager.impact(style: .light)
            } label: {
                Image(systemName: "message.fill")
                    .foregroundColor(ModernTheme.accent)
            }
        }
        .padding(ModernTheme.spacing3)
        .background(ModernTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ModernTheme.mediumRadius, style: .continuous))
        .shadow(color: ModernTheme.cardShadow, radius: 4, x: 0, y: 2)
    }
}

// MARK: - 🔔 动态卡片

struct ActivityCard: View {
    let icon: String
    let title: String
    let description: String
    let time: String
    let color: Color
    
    var body: some View {
        HStack(spacing: ModernTheme.spacing3) {
            // 图标
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: icon)
                        .foregroundColor(color)
                )
            
            VStack(alignment: .leading, spacing: ModernTheme.spacing1) {
                Text(title)
                    .font(ModernTheme.bodyBold)
                    .foregroundColor(ModernTheme.primaryText)
                
                Text(description)
                    .font(ModernTheme.caption)
                    .foregroundColor(ModernTheme.secondaryText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(time)
                .font(ModernTheme.caption)
                .foregroundColor(ModernTheme.tertiaryText)
        }
        .padding(ModernTheme.spacing3)
        .background(ModernTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ModernTheme.mediumRadius, style: .continuous))
        .shadow(color: ModernTheme.cardShadow, radius: 4, x: 0, y: 2)
    }
}

// MARK: - ⚙️ 设置行

struct SettingRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: ModernTheme.spacing3) {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundColor(color)
                    )
                
                Text(title)
                    .font(ModernTheme.body)
                    .foregroundColor(ModernTheme.primaryText)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(ModernTheme.tertiaryText)
            }
            .padding(ModernTheme.spacing3)
            .background(ModernTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: ModernTheme.mediumRadius, style: .continuous))
            .shadow(color: ModernTheme.cardShadow, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 📭 空状态卡片

struct EmptyStateCard: View {
    let icon: String
    let message: String
    
    var body: some View {
        VStack(spacing: ModernTheme.spacing3) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(ModernTheme.tertiaryText)
            
            Text(message)
                .font(ModernTheme.body)
                .foregroundColor(ModernTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(ModernTheme.spacing6)
        .background(ModernTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ModernTheme.largeRadius, style: .continuous))
        .shadow(color: ModernTheme.cardShadow, radius: 6, x: 0, y: 3)
    }
}

// MARK: - ⚙️ 设置Sheet

struct SettingsSheet: View {
    var client: HackChatClient
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("账户") {
                    HStack {
                        Text("昵称")
                        Spacer()
                        Text(client.myNick)
                            .foregroundColor(ModernTheme.secondaryText)
                    }
                }
                
                Section("通知") {
                    Toggle("接收消息通知", isOn: .constant(true))
                    Toggle("声音提示", isOn: .constant(true))
                    Toggle("震动反馈", isOn: .constant(true))
                }
                
                Section("外观") {
                    Picker("主题", selection: .constant(0)) {
                        Text("跟随系统").tag(0)
                        Text("浅色模式").tag(1)
                        Text("深色模式").tag(2)
                    }
                }
                
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(ModernTheme.secondaryText)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

