//
//  OnlineUsersView.swift
//  HChat
//
//  Created on 2025-10-21.
//  在线用户列表视图

import SwiftUI

struct OnlineUsersView: View {
    var client: HackChatClient
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if onlineUsers.isEmpty {
                    ContentUnavailableView(
                        "暂无在线用户",
                        systemImage: "person.2.slash",
                        description: Text("当前频道没有其他用户")
                    )
                } else {
                    Section {
                        ForEach(onlineUsers, id: \.id) { presence in
                            OnlineUserRow(
                                presence: presence,
                                myNick: client.myNick
                            )
                        }
                    } header: {
                        HStack {
                            Text("在线用户")
                            Spacer()
                            Text("\(onlineUsers.count) 人")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("在线状态")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .refreshable {
                // 刷新在线用户列表
                client.send(json: ["type": "who", "room": client.currentChannel])
            }
        }
    }
    
    /// 获取在线用户列表（按状态排序）
    private var onlineUsers: [UserPresence] {
        let currentChannelUsers = client.onlineByRoom[client.currentChannel] ?? []
        
        return currentChannelUsers.compactMap { nick in
            client.presenceManager.getUserPresence(nick) ?? UserPresence(id: nick, status: .online, channel: client.currentChannel)
        }
        .sorted { user1, user2 in
            // 自己排最前面
            if user1.id == client.myNick { return true }
            if user2.id == client.myNick { return false }
            
            // 按状态排序：online > away > busy > offline
            let order: [UserStatus: Int] = [.online: 0, .away: 1, .busy: 2, .offline: 3]
            let order1 = order[user1.status] ?? 4
            let order2 = order[user2.status] ?? 4
            
            if order1 != order2 {
                return order1 < order2
            }
            
            // 相同状态按昵称排序
            return user1.id < user2.id
        }
    }
}

#Preview {
    OnlineUsersView(client: HackChatClient())
}

