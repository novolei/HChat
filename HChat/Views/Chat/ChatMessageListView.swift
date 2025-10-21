//
//  ChatMessageListView.swift
//  HChat
//
//  Created by AI Assistant on 2025/10/21.
//  聊天消息列表视图
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
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索/过滤
            TextField("搜索消息 / 过滤 @ 提及", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding([.top, .horizontal])
            
            // 消息列表
            ScrollViewReader { proxy in
                List {
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
                                // ✨ P1: 跳转到被引用的消息（TODO: 实现滚动）
                                DebugLogger.log("💬 跳转到消息: \(messageId)", level: .debug)
                            },
                            onShowReadReceipts: { // ✨ P1: 显示已读回执详情
                                selectedMessage = m
                                showReadReceiptDetail = true
                            }
                        )
                        .id(m.id)
                        .onAppear {
                            // ✨ P1: 消息可见时自动发送已读回执
                            if m.sender != client.myNick {
                                client.readReceiptManager.markAsRead(messageId: m.id, channel: m.channel)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .onChange(of: filteredMessages.count) { oldCount, newCount in
                    // 当有新消息时自动滚动到底部
                    if shouldAutoScroll, newCount > oldCount, let lastMsg = filteredMessages.last {
                        withAnimation {
                            proxy.scrollTo(lastMsg.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    // 初次加载时滚动到底部
                    if let lastMsg = filteredMessages.last {
                        proxy.scrollTo(lastMsg.id, anchor: .bottom)
                    }
                }
            }
        }
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
    
    private var filteredMessages: [ChatMessage] {
        let all = client.messagesByChannel[client.currentChannel] ?? []
        guard !searchText.isEmpty else { return all }
        let key = searchText.lowercased()
        return all.filter { $0.text.lowercased().contains(key) || $0.sender.lowercased().contains(key) }
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

