//
//  MessageReplyComponents.swift
//  HChat
//
//  Created on 2025-10-21.
//  消息引用/回复 UI 组件

import SwiftUI

/// 回复预览条（显示在输入框上方）
struct ReplyPreviewBar: View {
    let replyTo: ChatMessage
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 引用线
            Rectangle()
                .fill(Color.blue)
                .frame(width: 3)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("回复 \(replyTo.sender)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                Text(replyTo.text.isEmpty ? "[附件消息]" : replyTo.text)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

/// 引用消息显示（在消息气泡内）
struct QuotedMessageView: View {
    let reply: MessageReply
    let onTap: (() -> Void)?
    
    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(reply.sender)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    Text(reply.displayText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(8)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 预览

#Preview("回复预览条") {
    VStack {
        ReplyPreviewBar(
            replyTo: ChatMessage(
                id: "1",
                channel: "lobby",
                sender: "Alice",
                text: "这是一条测试消息，用来演示回复预览条的效果。"
            ),
            onCancel: {}
        )
        
        Spacer()
    }
}

#Preview("引用消息显示") {
    VStack(spacing: 16) {
        QuotedMessageView(
            reply: MessageReply(
                messageId: "1",
                sender: "Alice",
                text: "这是被引用的消息内容。"
            ),
            onTap: {}
        )
        
        QuotedMessageView(
            reply: MessageReply(
                messageId: "2",
                sender: "Bob",
                text: "这是一条很长很长很长很长很长很长很长很长很长很长很长很长的消息，会被截断显示。"
            ),
            onTap: {}
        )
        
        QuotedMessageView(
            reply: MessageReply(
                messageId: "3",
                sender: "Charlie",
                text: ""  // 空文本（附件消息）
            ),
            onTap: {}
        )
    }
    .padding()
}

