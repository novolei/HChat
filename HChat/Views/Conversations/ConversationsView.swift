//
//  ConversationsView.swift
//  HChat
//
//  Created on 2025-10-23.
//  💬 聊天列表视图（类似微信/WhatsApp）
//

import SwiftUI

struct ConversationsView: View {
    let client: HackChatClient
    @State private var searchText = ""
    @State private var selectedConversation: Conversation?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索栏
                searchBar
                
                // 会话列表
                conversationList
            }
            .navigationTitle("聊天")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            // TODO: 发起私聊
                        } label: {
                            Label("发起私聊", systemImage: "person.crop.circle.badge.plus")
                        }
                        
                        Button {
                            // TODO: 创建群聊
                        } label: {
                            Label("创建群聊", systemImage: "person.3.fill")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .navigationDestination(item: $selectedConversation) { conversation in
                ChatView(client: client, conversation: conversation)
            }
        }
    }
    
    // MARK: - 子视图
    
    /// 搜索栏
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    /// 会话列表
    @ViewBuilder
    private var conversationList: some View {
        if filteredConversations.isEmpty {
            emptyState
        } else {
            List {
                    ForEach(filteredConversations) { conversation in
                        ConversationRow(
                            conversation: conversation,
                            myNick: client.myNick
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedConversation = conversation
                            client.state.currentConversation = conversation
                            client.state.clearConversationUnread(conversation.id)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            // 左滑：置顶
                            Button {
                                client.state.toggleConversationPin(conversation.id)
                                HapticManager.impact(style: .medium)
                            } label: {
                                Label(
                                    conversation.isPinned ? "取消置顶" : "置顶",
                                    systemImage: conversation.isPinned ? "pin.slash" : "pin.fill"
                                )
                            }
                            .tint(conversation.isPinned ? .gray : .orange)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            // 右滑：删除
                            Button(role: .destructive) {
                                withAnimation {
                                    client.state.deleteConversation(conversation.id)
                                }
                            } label: {
                                Label("删除", systemImage: "trash.fill")
                            }
                            
                            // 右滑：免打扰
                            Button {
                                client.state.toggleConversationMute(conversation.id)
                                HapticManager.impact(style: .light)
                            } label: {
                                Label(
                                    conversation.isMuted ? "取消免打扰" : "免打扰",
                                    systemImage: conversation.isMuted ? "bell.fill" : "bell.slash.fill"
                                )
                            }
                            .tint(.purple)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
                .listStyle(.plain)
        }
    }
    
    /// 空状态
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("还没有聊天")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Text("点击右上角「+」开始聊天")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 计算属性
    
    /// 过滤后的会话列表
    private var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return client.state.conversations
        }
        
        return client.state.conversations.filter { conversation in
            conversation.title.localizedCaseInsensitiveContains(searchText) ||
            (conversation.lastMessage?.text.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
}

// MARK: - 会话行视图

struct ConversationRow: View {
    let conversation: Conversation
    let myNick: String
    
    var body: some View {
        HStack(spacing: 12) {
            // 头像 + 在线状态
            ZStack(alignment: .bottomTrailing) {
                // 头像
                Circle()
                    .fill(avatarColor)
                    .frame(width: 54, height: 54)
                    .overlay(
                        Text(avatarText)
                            .font(.title3.bold())
                            .foregroundColor(.white)
                    )
                
                // 在线状态点（仅私聊显示）
                if conversation.type == .dm && conversation.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .offset(x: 2, y: 2)
                }
                
                // 免打扰图标
                if conversation.isMuted {
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Image(systemName: "bell.slash.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                        )
                        .offset(x: 2, y: -30)
                }
            }
            
            // 会话信息
            VStack(alignment: .leading, spacing: 4) {
                // 第一行：名称 + 时间
                HStack {
                    // 置顶图标
                    if conversation.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    
                    // 名称
                    Text(conversation.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // 时间
                    if let lastMessage = conversation.lastMessage {
                        Text(formatTime(lastMessage.timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 第二行：最后消息预览
                HStack(spacing: 4) {
                    // 消息预览
                    Text(lastMessagePreview)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // 未读角标
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(conversation.isMuted ? Color.gray : Color.red)
                            )
                            .frame(minWidth: 18)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .background(conversation.isPinned ? Color(.systemGray6).opacity(0.5) : Color.clear)
        .cornerRadius(8)
    }
    
    // MARK: - 计算属性
    
    /// 头像文字
    private var avatarText: String {
        conversation.title.prefix(1).uppercased()
    }
    
    /// 头像颜色
    private var avatarColor: Color {
        colorForNickname(conversation.title)
    }
    
    /// 最后消息预览
    private var lastMessagePreview: String {
        guard let lastMessage = conversation.lastMessage else {
            return "暂无消息"
        }
        
        // 如果有附件，显示附件类型
        if !lastMessage.attachments.isEmpty {
            let attachment = lastMessage.attachments[0]
            switch attachment.kind {
            case .image: return "[图片]"
            case .video: return "[视频]"
            case .audio: return "[语音]"
            case .file: return "[文件]"
            }
        }
        
        // 显示文本消息
        let prefix = (lastMessage.sender == myNick) ? "我: " : ""
        return prefix + lastMessage.text
    }
    
    /// 格式化时间
    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            // 今天：显示时间
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            // 本周：显示星期
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            formatter.locale = Locale(identifier: "zh_CN")
            return formatter.string(from: date)
        } else if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            // 今年：显示月日
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter.string(from: date)
        } else {
            // 往年：显示年月日
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/M/d"
            return formatter.string(from: date)
        }
    }
}

