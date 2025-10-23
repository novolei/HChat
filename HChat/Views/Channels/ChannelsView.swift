//
//  ChannelsView.swift
//  HChat
//
//  Created on 2025-10-23.
//  📺 频道列表视图
//

import SwiftUI

struct ChannelsView: View {
    let client: HackChatClient
    @State private var showCreateChannel = false
    @State private var newChannelName = ""
    @State private var selectedChannel: String?
    
    var body: some View {
        NavigationStack {
            List {
                // 频道列表
                ForEach(client.state.channels) { channel in
                    ChannelRow(channel: channel, client: client)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedChannel = channel.name
                            client.sendText("/join \(channel.name)")
                            
                            // 创建或更新频道会话
                            let conversation = client.state.createOrGetChannelConversation(
                                channelId: channel.name,
                                title: channel.name
                            )
                            client.state.currentConversation = conversation
                        }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("频道")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateChannel = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showCreateChannel) {
                createChannelSheet
            }
            .navigationDestination(item: $selectedChannel) { channelName in
                if let conversation = client.state.conversations.first(where: { $0.channelId == channelName }) {
                    ChatView(client: client, conversation: conversation)
                }
            }
        }
    }
    
    // MARK: - 子视图
    
    /// 创建频道表单
    private var createChannelSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("频道名称", text: $newChannelName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("新建频道")
                } footer: {
                    Text("频道名称只能包含字母、数字、连字符")
                }
            }
            .navigationTitle("创建频道")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showCreateChannel = false
                        newChannelName = ""
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        createChannel()
                    }
                    .disabled(newChannelName.isEmpty)
                }
            }
        }
    }
    
    // MARK: - 方法
    
    /// 创建频道
    private func createChannel() {
        let channelName = newChannelName.trimmingCharacters(in: .whitespaces)
        
        guard !channelName.isEmpty else { return }
        
        // 发送加入频道命令
        client.sendText("/join \(channelName)")
        
        // 关闭表单
        showCreateChannel = false
        newChannelName = ""
        
        // 切换到新频道
        selectedChannel = channelName
    }
}

// MARK: - 频道行视图

struct ChannelRow: View {
    let channel: Channel
    let client: HackChatClient
    
    var body: some View {
        HStack(spacing: 12) {
            // 频道图标
            ZStack {
                Circle()
                    .fill(colorForNickname(channel.name))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "number")
                    .font(.title3.bold())
                    .foregroundColor(.white)
            }
            
            // 频道信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // 频道名
                    Text(channel.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // 在线人数
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                        Text("\(onlineCount)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                // 最后消息时间
                if let lastMessageAt = channel.lastMessageAt {
                    Text(formatRelativeTime(lastMessageAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 未读角标
            if channel.unreadCount > 0 {
                Text("\(channel.unreadCount)")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.red))
                    .frame(minWidth: 18)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - 计算属性
    
    /// 频道在线人数
    private var onlineCount: Int {
        client.state.onlineCountByRoom[channel.name] ?? 0
    }
    
    /// 格式化相对时间
    private func formatRelativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            return "\(Int(interval / 60))分钟前"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))小时前"
        } else {
            return "\(Int(interval / 86400))天前"
        }
    }
}

