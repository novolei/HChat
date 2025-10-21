//
//  ChatToolbarContent.swift
//  HChat
//
//  Created by AI Assistant on 2025/10/21.
//  聊天工具栏内容
//

import SwiftUI

struct ChatToolbar: ToolbarContent {
    var client: HackChatClient
    @Binding var showNicknamePrompt: Bool
    @Binding var nicknameInput: String
    @Binding var showCallSheet: Bool
    var onCreateChannel: () -> Void
    var onStartPrivateChat: () -> Void
    
    var body: some ToolbarContent {
        // 左侧频道选择
        ToolbarItem(placement: .navigationBarLeading) {
            Menu {
                ForEach(client.channels) { ch in
                    Button("#\(ch.name)") { client.currentChannel = ch.name }
                }
                Divider()
                Button("新建频道") { onCreateChannel() }
                Button("私聊…") { onStartPrivateChat() }
            } label: {
                Label("频道", systemImage: "number")
            }
        }
        
        // 右侧功能菜单
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    nicknameInput = client.myNick
                    showNicknamePrompt = true
                } label: {
                    Label("修改昵称 (\(client.myNick))", systemImage: "person.circle")
                }
                
                Divider()
                
                Button {
                    showCallSheet = true
                } label: {
                    Label("发起语音通话", systemImage: "phone.arrow.up.right")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}

