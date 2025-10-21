//
//  ChatInputView.swift
//  HChat
//
//  Created by AI Assistant on 2025/10/21.
//  聊天输入框视图
//

import SwiftUI

struct ChatInputView: View {
    var client: HackChatClient
    @Binding var inputText: String
    var onSend: () -> Void
    var onAttachment: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Button {
                onAttachment()
            } label: {
                Image(systemName: "paperclip")
            }
            .buttonStyle(.borderless)
            
            TextField("消息（支持 /join /nick /me /clear /help）", text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .onSubmit {
                    onSend()
                }
            
            Button("发送") {
                onSend()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.bar)
    }
}

