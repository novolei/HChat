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
    @State private var selectedMessage: ChatMessage?
    
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
                            }
                        )
                        .id(m.id)
                    }
                }
                .listStyle(.plain)
            }
        }
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
    }
}

