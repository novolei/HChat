//
//  ContactsView.swift
//  HChat
//
//  Created on 2025-10-23.
//  👥 通讯录视图（在线用户）
//

import SwiftUI

struct ContactsView: View {
    let client: HackChatClient
    @State private var searchText = ""
    @State private var selectedUser: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索栏
                searchBar
                
                // 用户列表
                userList
            }
            .navigationTitle("通讯录")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $selectedUser) { userId in
                if let conversation = client.state.conversations.first(where: { $0.otherUserId == userId }) {
                    ChatView(client: client, conversation: conversation)
                }
            }
        }
    }
    
    // MARK: - 子视图
    
    /// 搜索栏
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索用户", text: $searchText)
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
    
    /// 用户列表
    private var userList: some View {
        List {
            // 在线用户
            if !onlineUsers.isEmpty {
                Section {
                    ForEach(onlineUsers, id: \.self) { userId in
                        ContactRow(
                            userId: userId,
                            isOnline: true,
                            client: client
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            startChat(with: userId)
                        }
                    }
                } header: {
                    Text("在线 (\(onlineUsers.count))")
                }
            }
            
            // 离线用户（最近联系）
            if !offlineUsers.isEmpty {
                Section {
                    ForEach(offlineUsers, id: \.self) { userId in
                        ContactRow(
                            userId: userId,
                            isOnline: false,
                            client: client
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            startChat(with: userId)
                        }
                    }
                } header: {
                    Text("最近联系")
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - 计算属性
    
    /// 在线用户列表
    private var onlineUsers: [String] {
        let allOnline = Set(client.state.onlineStatuses.values
            .filter { $0.isOnline }
            .map { $0.userId })
            .subtracting([client.myNick])  // 排除自己
        
        if searchText.isEmpty {
            return Array(allOnline).sorted()
        }
        
        return Array(allOnline)
            .filter { $0.localizedCaseInsensitiveContains(searchText) }
            .sorted()
    }
    
    /// 离线用户列表（最近联系过的）
    private var offlineUsers: [String] {
        let hasConversation = Set(client.state.conversations
            .filter { $0.type == .dm }
            .compactMap { $0.otherUserId })
        
        let offline = hasConversation.subtracting(Set(onlineUsers))
        
        if searchText.isEmpty {
            return Array(offline).sorted()
        }
        
        return Array(offline)
            .filter { $0.localizedCaseInsensitiveContains(searchText) }
            .sorted()
    }
    
    // MARK: - 方法
    
    /// 开始聊天
    private func startChat(with userId: String) {
        // 创建或获取会话
        let conversation = client.state.createOrGetDM(with: userId)
        client.state.currentConversation = conversation
        
        // 导航到聊天界面
        selectedUser = userId
    }
}

// MARK: - 联系人行视图

struct ContactRow: View {
    let userId: String
    let isOnline: Bool
    let client: HackChatClient
    
    var body: some View {
        HStack(spacing: 12) {
            // 头像 + 在线状态
            ZStack(alignment: .bottomTrailing) {
                // 头像
                Circle()
                    .fill(colorForNickname(userId))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(userId.prefix(1).uppercased())
                            .font(.title3.bold())
                            .foregroundColor(.white)
                    )
                
                // 在线状态点
                Circle()
                    .fill(isOnline ? Color.green : Color.gray)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .offset(x: 2, y: 2)
            }
            
            // 用户信息
            VStack(alignment: .leading, spacing: 4) {
                Text(userId)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 聊天按钮
            Image(systemName: "bubble.left.fill")
                .font(.title3)
                .foregroundColor(.blue.opacity(0.6))
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - 计算属性
    
    /// 状态文本
    private var statusText: String {
        if isOnline {
            return "在线"
        }
        
        // 获取最后在线时间
        if let onlineStatus = client.state.onlineStatuses[userId],
           let lastSeen = onlineStatus.lastSeen {
            return formatLastSeen(lastSeen)
        }
        
        return "离线"
    }
    
    /// 格式化最后在线时间
    private func formatLastSeen(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "刚刚在线"
        } else if interval < 3600 {
            return "\(Int(interval / 60))分钟前在线"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))小时前在线"
        } else if interval < 604800 {
            return "\(Int(interval / 86400))天前在线"
        } else {
            return "很久未在线"
        }
    }
}

