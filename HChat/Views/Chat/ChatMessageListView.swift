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
    
    // 计算过滤后的消息
    private var filteredMessages: [ChatMessage] {
        let channel = client.currentChannel
        let messages = client.messagesByChannel[channel] ?? []
        
        if searchText.isEmpty {
            return messages
        } else {
            let query = searchText.lowercased()
            return messages.filter { msg in
                msg.text.lowercased().contains(query) || 
                msg.sender.lowercased().contains(query)
            }
        }
    }
    
    // 正在输入的用户列表
    private var typingUsers: [String] {
        client.typingIndicatorManager.typingNicknames(in: client.currentChannel)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchBarView
            messageListSection
        }
        .interactiveDismissKeyboard()
        .toast($toastMessage)
        .sheet(isPresented: $showFullPicker) {
            if let message = selectedMessage {
                FullEmojiReactionPicker { emoji in
                    client.reactionManager.toggleReaction(
                        emoji: emoji,
                        messageId: message.id,
                        channel: message.channel
                    )
                }
            }
        }
        .sheet(isPresented: $showReactionDetail) {
            if let message = selectedMessage {
                ReactionDetailView(message: message)
            }
        }
        .sheet(isPresented: $showReadReceiptDetail) {
            if let message = selectedMessage {
                ReadReceiptDetailView(message: message)
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var searchBarView: some View {
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
        .padding(.horizontal, HChatTheme.mediumSpacing)
        .padding(.vertical, HChatTheme.smallSpacing)
        .background(
            RoundedRectangle(cornerRadius: HChatTheme.mediumCornerRadius, style: .continuous)
                .fill(HChatTheme.tertiaryBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HChatTheme.mediumCornerRadius, style: .continuous)
                .stroke(isSearchFocused ? HChatTheme.accent.opacity(0.3) : HChatTheme.border, lineWidth: 1)
        )
        .padding(.horizontal, ModernTheme.spacing4)
        .padding(.top, ModernTheme.spacing1)
        .padding(.bottom, ModernTheme.spacing2)
        .animation(HChatTheme.quickAnimation, value: isSearchFocused)
        .animation(HChatTheme.quickAnimation, value: searchText.isEmpty)
    }
    
    @ViewBuilder
    private var messageListSection: some View {
        ScrollViewReader { proxy in
            MessageOverlayContainer(client: client, onShowFullPicker: { message in
                selectedMessage = message
                showFullPicker = true
            }) { overlayState in
                MessageListContent(
                    filteredMessages: filteredMessages,
                    typingUsers: typingUsers,
                    client: client,
                    shouldAutoScroll: shouldAutoScroll,
                    hasMarkedRead: $hasMarkedRead,
                    selectedMessage: $selectedMessage,
                    showFullPicker: $showFullPicker,
                    showReactionDetail: $showReactionDetail,
                    showReadReceiptDetail: $showReadReceiptDetail,
                    overlayState: overlayState,
                    proxy: proxy
                )
            }
        }
    }
    
}

// MARK: - Nested Content Builders

private struct MessageListContent: View {
    let filteredMessages: [ChatMessage]
    let typingUsers: [String]
    let client: HackChatClient
    let shouldAutoScroll: Bool
    @Binding var hasMarkedRead: Set<String>
    @Binding var selectedMessage: ChatMessage?
    @Binding var showFullPicker: Bool
    @Binding var showReactionDetail: Bool
    @Binding var showReadReceiptDetail: Bool
    let overlayState: MessageOverlayState
    let proxy: ScrollViewProxy
    
    var body: some View {
        VStack(spacing: 0) {
            contentList
            typingIndicator
        }
    }
    
    @ViewBuilder
    private var contentList: some View {
        if filteredMessages.isEmpty {
            EmptyChatStateView(
                isSearching: !searchTextActive,
                channelName: client.currentChannel
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredMessages) { message in
                        row(for: message)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottom_anchor")
                }
            }
            .coordinateSpace(name: "chatScroll")
            .background(scrollFrameReporter)
            .onPreferenceChange(MessageFramePreferenceKey.self) { overlayState.updateAnchors($0) }
            .onPreferenceChange(ScrollViewFramePreferenceKey.self) { overlayState.updateScrollFrame($0) }
            .scrollDismissesKeyboardIfAvailable()
            .onChange(of: filteredMessages.count) { oldCount, newCount in
                guard shouldAutoScroll, newCount > oldCount else { return }
                scrollToBottom(animatedDuration: 0.3)
            }
            .onAppear {
                scrollToBottom(animatedDuration: 0.0, delay: 0.1)
            }
        }
    }
    
    @ViewBuilder
    private var typingIndicator: some View {
        if !typingUsers.isEmpty {
            TypingIndicatorView(typingUsers: typingUsers)
                .padding(.horizontal, ModernTheme.spacing4)
                .padding(.top, ModernTheme.spacing2)
                .padding(.bottom, ModernTheme.spacing1)
        }
    }
    
    private var searchTextActive: Bool { filteredMessages.isEmpty == false }
    
    @ViewBuilder
    private var scrollFrameReporter: some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: ScrollViewFramePreferenceKey.self,
                value: geo.frame(in: .global)
            )
        }
    }
    
    private func row(for message: ChatMessage) -> some View {
        MessageRowView(
            message: message,
            myNick: client.myNick,
            client: client,
            isHighlighted: overlayState.highlightedMessageID == message.id,
            onLongPress: { overlayState.presentOverlay(for: $0.id) },
            onShowReactionDetail: {
                selectedMessage = message
                showReactionDetail = true
            },
            onReply: {
                client.replyManager.setReplyTarget(message)
            },
            onJumpToReply: { messageId in
                withAnimation {
                    proxy.scrollTo(messageId, anchor: .center)
                }
            },
            onShowReadReceipts: {
                selectedMessage = message
                showReadReceiptDetail = true
            }
        )
        .id(message.id)
        .background(rowGeometryReporter(for: message))
        .onAppear {
            if message.sender != client.myNick && !hasMarkedRead.contains(message.id) {
                hasMarkedRead.insert(message.id)
                client.readReceiptManager.markAsRead(messageId: message.id, channel: message.channel)
            }
        }
    }
    
    private func rowGeometryReporter(for message: ChatMessage) -> some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: MessageFramePreferenceKey.self,
                value: [
                    message.id: MessageAnchorInfo(
                        frameInScroll: geo.frame(in: .named("chatScroll")),
                        globalFrame: geo.frame(in: .global),
                        isMine: message.sender == client.myNick
                    )
                ]
            )
        }
    }
    
    private func scrollToBottom(animatedDuration: Double, delay: Double = 0.05) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeOut(duration: animatedDuration)) {
                proxy.scrollTo("bottom_anchor", anchor: .bottom)
            }
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

