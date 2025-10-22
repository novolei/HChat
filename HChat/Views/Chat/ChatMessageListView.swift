//
//  ChatMessageListView.swift
//  HChat
//
//  Created by AI Assistant on 2025/10/21.
//  ✨ UI优化：现代化消息列表，添加空状态和优雅布局
//

import SwiftUI

struct ChatMessageListView: View {
    var client: HackChatClient
    @Binding var searchText: String
    
    // ✨ P1: 表情反应状态
    @State private var showFullPicker = false
    @State private var showReactionDetail = false
    @State private var showReadReceiptDetail = false // ✨ P1: 已读回执详情
    @State private var selectedMessage: ChatMessage?
    
    // ✨ Toast 通知
    @State private var toastMessage: ToastMessage?
    
    // 滚动控制
    @State private var shouldAutoScroll = true  // 是否自动滚动到底部
    @State private var hasMarkedRead: Set<String> = []  // 已标记为已读的消息ID
    
    @FocusState private var isSearchFocused: Bool
    
    // 缓存过滤结果以提升性能
    private var filteredMessages: [ChatMessage] {
        let channel = client.currentChannel
        let messages = client.messagesByChannel[channel] ?? []
        
        guard !searchText.isEmpty else { return messages }
        
        let query = searchText.lowercased()
        return messages.filter { msg in
            msg.text.lowercased().contains(query) || 
            msg.sender.lowercased().contains(query)
        }
    }
    
    // 监听最后一条消息的 reaction 和已读回执变化
    private var lastMessageHash: Int {
        guard let lastMsg = filteredMessages.last else { return 0 }
        var hasher = Hasher()
        hasher.combine(lastMsg.id)
        hasher.combine(lastMsg.reactions.count)
        hasher.combine(lastMsg.readReceipts.count)
        return hasher.finalize()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索/过滤（现代化设计）
            HStack(spacing: HChatTheme.mediumSpacing) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(isSearchFocused ? HChatTheme.accent : HChatTheme.tertiaryText)
                    .font(.system(size: 16))
                
                TextField("搜索消息或用户", text: $searchText)
                    .font(HChatTheme.bodyFont)
                    .focused($isSearchFocused)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        HapticManager.impact(style: .light)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(HChatTheme.tertiaryText)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, HChatTheme.largeSpacing)
            .padding(.vertical, HChatTheme.smallSpacing)
            .background(
                RoundedRectangle(cornerRadius: HChatTheme.mediumCornerRadius, style: .continuous)
                    .fill(HChatTheme.tertiaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HChatTheme.mediumCornerRadius, style: .continuous)
                    .stroke(isSearchFocused ? HChatTheme.accent.opacity(0.3) : HChatTheme.border, lineWidth: 1)
            )
            .padding(.horizontal, HChatTheme.largeSpacing)
            .padding(.top, HChatTheme.mediumSpacing)
            .padding(.bottom, HChatTheme.smallSpacing)
            .animation(HChatTheme.quickAnimation, value: isSearchFocused)
            .animation(HChatTheme.quickAnimation, value: searchText.isEmpty)
            
            // 消息列表（优化性能：使用 ScrollView + LazyVStack 替代 List）
            ScrollViewReader { proxy in
                if filteredMessages.isEmpty {
                    // 空状态视图
                    EmptyChatStateView(
                        isSearching: !searchText.isEmpty,
                        channelName: client.currentChannel
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredMessages, id: \.id) { m in
                                MessageRowView(
                                    message: m,
                                    myNick: client.myNick,
                                    onReactionTap: { emoji in
                                        handleReactionTap(emoji: emoji, message: m)
                                    },
                                    onShowReactionPicker: {
                                        selectedMessage = m
                                        showFullPicker = true
                                    },
                                    onShowReactionDetail: {
                                        selectedMessage = m
                                        showReactionDetail = true
                                    },
                                    onReply: {
                                        // ✨ P1: 设置回复目标
                                        client.replyManager.setReplyTarget(m)
                                    },
                                    onJumpToReply: { messageId in
                                        // ✨ P1: 跳转到被引用的消息
                                        withAnimation {
                                            proxy.scrollTo(messageId, anchor: .center)
                                        }
                                    },
                                    onShowReadReceipts: {
                                        selectedMessage = m
                                        showReadReceiptDetail = true
                                    }
                                )
                                .id(m.id)
                                .onAppear {
                                    // ✨ 优化：只标记一次已读，避免重复触发
                                    if m.sender != client.myNick && !hasMarkedRead.contains(m.id) {
                                        hasMarkedRead.insert(m.id)
                                        client.readReceiptManager.markAsRead(messageId: m.id, channel: m.channel)
                                    }
                                }
                            }
                            
                            // ✨ 底部锚点，确保滚动时完整显示最后一条消息（包括 reaction 和已读回执）
                            Color.clear
                                .frame(height: 1)
                                .id("bottom_anchor")
                        }
                    }
                    .scrollDismissesKeyboardIfAvailable()
                    .onChange(of: filteredMessages.count) { oldCount, newCount in
                        // 当有新消息时自动滚动到底部，使用延迟确保 reaction 和已读回执已渲染
                        if shouldAutoScroll, newCount > oldCount {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo("bottom_anchor", anchor: .bottom)
                                }
                            }
                        }
                    }
                    .onChange(of: lastMessageHash) { _, _ in
                        // 当最后一条消息的 reaction 或已读回执更新时，确保完整显示
                        if shouldAutoScroll {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo("bottom_anchor", anchor: .bottom)
                                }
                            }
                        }
                    }
                    .onAppear {
                        // 初次加载时滚动到底部
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            proxy.scrollTo("bottom_anchor", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .interactiveDismissKeyboard()
        .toast($toastMessage)
        .sheet(isPresented: $showFullPicker) {
            if let message = selectedMessage {
                FullEmojiReactionPicker { emoji in
                    handleReactionTap(emoji: emoji, message: message)
                }
            }
        }
        .sheet(isPresented: $showReactionDetail) {
            if let message = selectedMessage {
                ReactionDetailView(message: message)
            }
        }
        .sheet(isPresented: $showReadReceiptDetail) { // ✨ P1: 已读回执详情
            if let message = selectedMessage {
                ReadReceiptDetailView(message: message)
            }
        }
    }
    
    
    // ✨ P1: 处理反应点击
    private func handleReactionTap(emoji: String, message: ChatMessage) {
        client.reactionManager.toggleReaction(
            emoji: emoji,
            messageId: message.id,
            channel: message.channel
        )
        
        // 如果不是最近的消息，显示 Toast 提示
        let isRecentMessage = filteredMessages.suffix(5).contains(where: { $0.id == message.id })
        if !isRecentMessage {
            toastMessage = ToastMessage(
                text: "已对 \(message.sender) 的消息添加反应 \(emoji)",
                icon: "hand.thumbsup.fill",
                duration: 2.0
            )
        }
    }
}

// MARK: - 📭 空状态视图

struct EmptyChatStateView: View {
    let isSearching: Bool
    let channelName: String
    
    var body: some View {
        VStack(spacing: HChatTheme.extraLargeSpacing) {
            // 图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [HChatTheme.accent.opacity(0.1), HChatTheme.accent.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: isSearching ? "magnifyingglass" : "message.fill")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(HChatTheme.accent.opacity(0.6))
            }
            
            VStack(spacing: HChatTheme.smallSpacing) {
                Text(isSearching ? "没有找到消息" : "欢迎来到 #\(channelName)")
                    .font(HChatTheme.smallTitleFont)
                    .foregroundColor(HChatTheme.primaryText)
                
                Text(isSearching ? "尝试使用其他关键词搜索" : "发送第一条消息开始聊天吧！")
                    .font(HChatTheme.bodyFont)
                    .foregroundColor(HChatTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            // 提示卡片（仅在非搜索时显示）
            if !isSearching {
                VStack(alignment: .leading, spacing: HChatTheme.mediumSpacing) {
                    HStack(spacing: HChatTheme.smallSpacing) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(HChatTheme.warning)
                        Text("快速提示")
                            .font(HChatTheme.buttonFont)
                    }
                    
                    VStack(alignment: .leading, spacing: HChatTheme.smallSpacing) {
                        TipRow(icon: "arrow.turn.down.left", text: "/join 频道名", description: "加入或创建频道")
                        TipRow(icon: "person.circle", text: "/nick 昵称", description: "更改你的昵称")
                        TipRow(icon: "face.smiling", text: "长按消息", description: "添加表情反应")
                    }
                }
                .padding(HChatTheme.largeSpacing)
                .background(
                    RoundedRectangle(cornerRadius: HChatTheme.mediumCornerRadius, style: .continuous)
                        .fill(HChatTheme.secondaryBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: HChatTheme.mediumCornerRadius, style: .continuous)
                        .stroke(HChatTheme.border, lineWidth: 1)
                )
                .padding(.horizontal, HChatTheme.extraLargeSpacing)
            }
        }
        .padding(HChatTheme.extraLargeSpacing)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 💡 提示行

struct TipRow: View {
    let icon: String
    let text: String
    let description: String
    
    var body: some View {
        HStack(spacing: HChatTheme.mediumSpacing) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(HChatTheme.accent)
                .frame(width: 20)
            
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(HChatTheme.primaryText)
            
            Text("—")
                .foregroundColor(HChatTheme.tertiaryText)
            
            Text(description)
                .font(HChatTheme.captionFont)
                .foregroundColor(HChatTheme.secondaryText)
        }
    }
}

