//
//  ChatsListView.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//  💬 聊天列表 - Channels + DMs（受现代设计启发）
//

import SwiftUI

struct ChatsListView: View {
    var client: HackChatClient
    
    @State private var searchText = ""
    @State private var showNewChat = false
    @State private var showProfile = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景渐变
                ModernTheme.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: ModernTheme.spacing5) {
                        // 在线用户横向滚动
                        OnlineUsersScrollView(client: client)
                        
                        // 搜索框
                        ModernSearchBar(text: $searchText)
                            .padding(.horizontal, ModernTheme.spacing4)
                        
                        // Pinned Chats（置顶聊天）
                        if !pinnedChats.isEmpty {
                            VStack(alignment: .leading, spacing: ModernTheme.spacing3) {
                                SectionHeader(
                                    icon: "pin.fill",
                                    title: "置顶聊天",
                                    iconColor: ModernTheme.warning
                                )
                                .padding(.horizontal, ModernTheme.spacing4)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: ModernTheme.spacing3) {
                                        ForEach(pinnedChats) { chat in
                                            PinnedChatCard(chat: chat) {
                                                selectChat(chat)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, ModernTheme.spacing4)
                                }
                            }
                        }
                        
                        // All Chats（所有聊天）
                        VStack(alignment: .leading, spacing: ModernTheme.spacing3) {
                            SectionHeader(
                                icon: "ellipsis.message.fill",
                                title: "所有聊天",
                                iconColor: ModernTheme.accent
                            )
                            .padding(.horizontal, ModernTheme.spacing4)
                            
                            VStack(spacing: ModernTheme.spacing2) {
                                ForEach(filteredChats) { chat in
                                    ChatRowCard(chat: chat, client: client) {
                                        selectChat(chat)
                                    }
                                    .padding(.horizontal, ModernTheme.spacing4)
                                }
                            }
                        }
                        
                        Spacer(minLength: 60)
                    }
                    .padding(.top, ModernTheme.spacing3)
                }
                .scrollDismissesKeyboardIfAvailable() // 滚动时隐藏键盘
            }
            .hideKeyboardOnTap() // 点击背景隐藏键盘
            .navigationTitle("消息")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showNewChat = true
                        HapticManager.impact(style: .light)
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                            .foregroundColor(ModernTheme.accent)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showProfile = true
                        HapticManager.impact(style: .light)
                    } label: {
                        Circle()
                            .fill(ModernTheme.accent.opacity(0.2))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(client.myNick.prefix(1).uppercased())
                                    .font(ModernTheme.bodyBold)
                                    .foregroundColor(ModernTheme.accent)
                            )
                    }
                }
            }
            .sheet(isPresented: $showNewChat) {
                NewChatSheet(client: client)
            }
            .sheet(isPresented: $showProfile) {
                ProfileSheet(client: client)
            }
        }
    }
    
    // MARK: - 数据处理
    
    private var allChats: [ChatItem] {
        // 合并 Channels 和 DMs
        var items: [ChatItem] = []
        
        // 添加所有频道
        for (channel, messages) in client.state.messagesByChannel {
            let lastMessage = messages.last
            items.append(ChatItem(
                id: channel,
                name: channel,
                type: channel.hasPrefix("pm-") ? .dm : .channel,
                lastMessage: lastMessage?.text ?? "",
                lastMessageTime: lastMessage?.timestamp ?? Date(),
                unreadCount: 0, // TODO: 实现未读计数
                isOnline: true,
                isPinned: false
            ))
        }
        
        return items.sorted { $0.lastMessageTime > $1.lastMessageTime }
    }
    
    private var pinnedChats: [ChatItem] {
        allChats.filter { $0.isPinned }
    }
    
    private var filteredChats: [ChatItem] {
        if searchText.isEmpty {
            return allChats.filter { !$0.isPinned }
        }
        return allChats.filter {
            !$0.isPinned && $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func selectChat(_ chat: ChatItem) {
        client.sendText("/join \(chat.name)")
        HapticManager.selection()
    }
}

// MARK: - 📊 聊天项数据模型

struct ChatItem: Identifiable {
    let id: String
    let name: String
    let type: ChatType
    let lastMessage: String
    let lastMessageTime: Date
    let unreadCount: Int
    let isOnline: Bool
    let isPinned: Bool
    
    enum ChatType {
        case channel
        case dm
    }
}

// MARK: - 👥 在线用户横向滚动

struct OnlineUsersScrollView: View {
    var client: HackChatClient
    
    private var onlineUsers: [String] {
        // 获取当前频道的在线用户
        Array(client.state.onlineByRoom[client.currentChannel] ?? [])
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ModernTheme.spacing3) {
                ForEach(onlineUsers.prefix(10), id: \.self) { user in
                    OnlineUserBubble(username: user)
                }
                
                if onlineUsers.count > 10 {
                    MoreUsersBubble(count: onlineUsers.count - 10)
                }
            }
            .padding(.horizontal, ModernTheme.spacing4)
            .padding(.vertical, ModernTheme.spacing2)
        }
    }
}

// MARK: - 👤 在线用户气泡

struct OnlineUserBubble: View {
    let username: String
    
    var body: some View {
        VStack(spacing: ModernTheme.spacing1) {
            ZStack(alignment: .topTrailing) {
                // 头像
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                colorForUsername(username),
                                colorForUsername(username).opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(username.prefix(1).uppercased())
                            .font(ModernTheme.title3)
                            .foregroundColor(.white)
                    )
                
                // 在线指示器
                Circle()
                    .fill(ModernTheme.success)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(ModernTheme.cardBackground, lineWidth: 2)
                    )
            }
            
            Text(username)
                .font(ModernTheme.caption)
                .foregroundColor(ModernTheme.secondaryText)
                .lineLimit(1)
                .frame(width: 56)
        }
    }
    
    private func colorForUsername(_ name: String) -> Color {
        let colors: [Color] = [
            ModernTheme.accent,
            ModernTheme.secondaryAccent,
            ModernTheme.success,
            ModernTheme.warning,
            Color(hex: "9B8CD1"),
            Color(hex: "7FB069")
        ]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }
}

// MARK: - ➕ 更多用户气泡

struct MoreUsersBubble: View {
    let count: Int
    
    var body: some View {
        VStack(spacing: ModernTheme.spacing1) {
            Circle()
                .fill(ModernTheme.tertiaryText.opacity(0.2))
                .frame(width: 56, height: 56)
                .overlay(
                    Text("+\(count)")
                        .font(ModernTheme.bodyBold)
                        .foregroundColor(ModernTheme.secondaryText)
                )
            
            Text("更多")
                .font(ModernTheme.caption)
                .foregroundColor(ModernTheme.secondaryText)
                .frame(width: 56)
        }
    }
}

// MARK: - 🔍 现代化搜索框

struct ModernSearchBar: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: ModernTheme.spacing3) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(isFocused ? ModernTheme.accent : ModernTheme.tertiaryText)
                .font(.system(size: 18))
            
            TextField("搜索消息或用户", text: $text)
                .font(ModernTheme.body)
                .focused($isFocused)
            
            if !text.isEmpty {
                Button {
                    text = ""
                    HapticManager.impact(style: .light)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ModernTheme.tertiaryText)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, ModernTheme.spacing4)
        .padding(.vertical, ModernTheme.spacing3)
        .background(ModernTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ModernTheme.mediumRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ModernTheme.mediumRadius, style: .continuous)
                .stroke(isFocused ? ModernTheme.accent.opacity(0.3) : ModernTheme.border, lineWidth: 1.5)
        )
        .shadow(color: ModernTheme.cardShadow, radius: 4, x: 0, y: 2)
        .animation(ModernTheme.quickAnimation, value: isFocused)
        .animation(ModernTheme.quickAnimation, value: text.isEmpty)
    }
}

// MARK: - 📌 置顶聊天卡片

struct PinnedChatCard: View {
    let chat: ChatItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: ModernTheme.spacing2) {
                // 头像和在线状态
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    ModernTheme.accent.opacity(0.3),
                                    ModernTheme.accent.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: chat.type == .channel ? "number" : "person.fill")
                                .foregroundColor(ModernTheme.accent)
                        )
                    
                    if chat.isOnline {
                        Circle()
                            .fill(ModernTheme.success)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle()
                                    .stroke(ModernTheme.cardBackground, lineWidth: 2)
                            )
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(chat.name)
                        .font(ModernTheme.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(ModernTheme.primaryText)
                        .lineLimit(1)
                    
                    Text(chat.lastMessage)
                        .font(ModernTheme.caption)
                        .foregroundColor(ModernTheme.secondaryText)
                        .lineLimit(2)
                }
            }
            .frame(width: 140)
            .padding(ModernTheme.spacing3)
            .background(ModernTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: ModernTheme.largeRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ModernTheme.largeRadius, style: .continuous)
                    .stroke(ModernTheme.border, lineWidth: 1)
            )
            .shadow(color: ModernTheme.cardShadow, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 💬 聊天行卡片

struct ChatRowCard: View {
    let chat: ChatItem
    let client: HackChatClient
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ModernTheme.spacing3) {
                // 头像
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    colorForChat(chat).opacity(0.3),
                                    colorForChat(chat).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)
                        .overlay(
                            Image(systemName: chat.type == .channel ? "number" : "person.fill")
                                .font(.title3)
                                .foregroundColor(colorForChat(chat))
                        )
                    
                    if chat.isOnline {
                        Circle()
                            .fill(ModernTheme.success)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(ModernTheme.cardBackground, lineWidth: 2.5)
                            )
                    }
                }
                
                // 内容
                VStack(alignment: .leading, spacing: ModernTheme.spacing1) {
                    HStack {
                        Text(chat.name)
                            .font(ModernTheme.bodyBold)
                            .foregroundColor(ModernTheme.primaryText)
                        
                        Spacer()
                        
                        Text(formatTime(chat.lastMessageTime))
                            .font(ModernTheme.caption)
                            .foregroundColor(ModernTheme.tertiaryText)
                    }
                    
                    HStack {
                        Text(chat.lastMessage.isEmpty ? "开始聊天..." : chat.lastMessage)
                            .font(ModernTheme.subheadline)
                            .foregroundColor(ModernTheme.secondaryText)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if chat.unreadCount > 0 {
                            Text("\(chat.unreadCount)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(ModernTheme.error)
                                )
                        }
                    }
                }
            }
            .padding(ModernTheme.spacing3)
            .background(ModernTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: ModernTheme.largeRadius, style: .continuous))
            .shadow(color: ModernTheme.cardShadow, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
    
    private func colorForChat(_ chat: ChatItem) -> Color {
        chat.type == .channel ? ModernTheme.accent : ModernTheme.secondaryAccent
    }
    
    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else {
            return DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
        }
    }
}

// MARK: - 📑 分区标题

struct SectionHeader: View {
    let icon: String
    let title: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: ModernTheme.spacing2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(iconColor)
            
            Text(title)
                .font(ModernTheme.bodyBold)
                .foregroundColor(ModernTheme.primaryText)
        }
    }
}

// MARK: - ➕ 新建聊天Sheet

struct NewChatSheet: View {
    var client: HackChatClient
    @Environment(\.dismiss) var dismiss
    @State private var channelName = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: ModernTheme.spacing5) {
            TextField("输入频道名称", text: $channelName)
                .font(ModernTheme.body)
                .padding(ModernTheme.spacing4)
                .background(ModernTheme.tertiaryText.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: ModernTheme.mediumRadius))
                .padding()
                
                Button {
                    client.sendText("/join \(channelName)")
                    dismiss()
                } label: {
                    Text("创建频道")
                        .font(ModernTheme.bodyBold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(ModernTheme.spacing4)
                        .background(ModernTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: ModernTheme.mediumRadius))
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("新建聊天")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 👤 个人资料Sheet

struct ProfileSheet: View {
    var client: HackChatClient
    @Environment(\.dismiss) var dismiss
    @State private var newNickname = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: ModernTheme.spacing5) {
                Circle()
                    .fill(ModernTheme.accent.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Text(client.myNick.prefix(1).uppercased())
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(ModernTheme.accent)
                    )
                
                Text(client.myNick)
                    .font(ModernTheme.title2)
                
                TextField("新昵称", text: $newNickname)
                    .font(ModernTheme.body)
                    .padding(ModernTheme.spacing4)
                    .background(ModernTheme.tertiaryText.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: ModernTheme.mediumRadius))
                    .padding()
                
                Button {
                    if !newNickname.isEmpty {
                        client.changeNick(newNickname)
                        dismiss()
                    }
                } label: {
                    Text("更改昵称")
                        .font(ModernTheme.bodyBold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(ModernTheme.spacing4)
                        .background(ModernTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: ModernTheme.mediumRadius))
                }
                .padding()
                
                Spacer()
            }
            .padding(.top, ModernTheme.spacing6)
            .navigationTitle("个人资料")
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

