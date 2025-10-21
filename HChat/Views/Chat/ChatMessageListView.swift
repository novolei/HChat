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
                        MessageRowView(message: m, myNick: client.myNick)
                            .id(m.id)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    private var filteredMessages: [ChatMessage] {
        let all = client.messagesByChannel[client.currentChannel] ?? []
        guard !searchText.isEmpty else { return all }
        let key = searchText.lowercased()
        return all.filter { $0.text.lowercased().contains(key) || $0.sender.lowercased().contains(key) }
    }
}

