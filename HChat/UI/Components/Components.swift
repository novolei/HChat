//
//  Components.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//

import SwiftUI
import AVKit

struct MessageRowView: View {
    let message: ChatMessage
    let myNick: String
    var onReactionTap: ((String) -> Void)? = nil           // 点击反应
    var onShowReactionPicker: (() -> Void)? = nil          // 显示反应选择器
    var onShowReactionDetail: (() -> Void)? = nil          // 显示反应详情
    var onReply: (() -> Void)? = nil                       // ✨ P1: 回复消息
    var onJumpToReply: ((String) -> Void)? = nil           // ✨ P1: 跳转到被引用的消息
    var onShowReadReceipts: (() -> Void)? = nil            // ✨ P1: 显示已读回执
    
    @State private var showQuickPicker = false
    
    // 是否是自己发送的消息
    private var isMyMessage: Bool {
        message.sender == myNick
    }
    
    // 气泡背景颜色
    private var bubbleColor: Color {
        if message.sender == "system" {
            return Color.gray.opacity(0.1)
        }
        return isMyMessage ? Color.blue : Color.gray.opacity(0.15)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 左边占位（自己的消息）
            if isMyMessage {
                Spacer(minLength: 60)
            }
            
            // 消息气泡内容
            VStack(alignment: isMyMessage ? .trailing : .leading, spacing: 6) {
                // 发送者和时间（不是自己的消息才显示发送者）
                if !isMyMessage || message.sender == "system" {
                    HStack(spacing: 8) {
                        Text(message.sender == "system" ? "•" : message.sender)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                        
                        // 时间戳和状态指示器
                        MessageTimestampWithStatus(message: message, myNick: myNick)
                    }
                    .opacity(0.9)
                } else {
                    // 自己的消息：只显示时间和状态
                    HStack(spacing: 8) {
                        MessageTimestampWithStatus(message: message, myNick: myNick)
                    }
                    .opacity(0.9)
                }
                
                // ✨ P1: 显示引用的消息
                if let reply = message.replyTo {
                    QuotedMessageView(reply: reply) {
                        onJumpToReply?(reply.messageId)
                    }
                }

                if !message.text.isEmpty {
                    RichText(message: message, myNick: myNick)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(bubbleColor)
                        .foregroundColor(isMyMessage ? .white : .primary)
                        .cornerRadius(16)
                }

                ForEach(message.attachments) { a in
                    AttachmentCard(attachment: a)
                }
                
                // ✨ P1: 表情反应气泡
                if message.hasReactions {
                    ReactionBubblesView(
                        message: message,
                        myNick: myNick,
                        onTapReaction: { emoji in
                            onReactionTap?(emoji)
                        },
                        onShowMore: {
                            onShowReactionPicker?()
                        }
                    )
                }
                
                // ✨ P1: 已读回执指示器
                if message.hasReadReceipts && message.sender == myNick {
                    Button {
                        onShowReadReceipts?()
                    } label: {
                        ReadReceiptIndicator(message: message, showDetails: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 右边占位（别人的消息）
            if !isMyMessage {
                Spacer(minLength: 60)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .contextMenu {
            // ✨ P1: 回复消息
            Button {
                onReply?()
            } label: {
                Label("回复", systemImage: "arrowshape.turn.up.left")
            }
            
            Divider()
            
            // ✨ P1: 右键菜单快捷反应
            ForEach(QuickReactions.defaults.prefix(3), id: \.self) { emoji in
                Button {
                    onReactionTap?(emoji)
                } label: {
                    Label(emoji, systemImage: "face.smiling")
                }
            }
            
            Button {
                onShowReactionPicker?()
            } label: {
                Label("更多反应...", systemImage: "face.smiling")
            }
            
            if message.hasReactions {
                Divider()
                
                Button {
                    onShowReactionDetail?()
                } label: {
                    Label("查看反应 (\(message.totalReactionCount))", systemImage: "list.bullet")
                }
            }
            
            // ✨ P1: 已读回执
            if message.hasReadReceipts && message.sender == myNick {
                Divider()
                
                Button {
                    onShowReadReceipts?()
                } label: {
                    Label("查看已读 (\(message.readCount))", systemImage: "checkmark.circle")
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            // 长按时显示快捷选择器
            if showQuickPicker {
                EmojiReactionPicker { emoji in
                    onReactionTap?(emoji)
                    showQuickPicker = false
                }
                .offset(x: 0, y: -50)
                .zIndex(100)
            }
        }
        .onLongPressGesture {
            showQuickPicker = true
        }
    }
}

import SwiftUI

struct RichText: View {
    let message: ChatMessage
    let myNick: String

    var body: some View {
        Text(buildAttributed())
            .textSelection(.enabled)
    }

    private func buildAttributed() -> AttributedString {
        var attr = AttributedString()
        let frags = MessageRenderer.splitToFragments(message.text)

        for f in frags {
            switch f {
            case .text(let s):
                attr += AttributedString(s)

            case .inlineCode(let s):
                var a = AttributedString(s)
                // 用等宽并标记为 code（系统样式）
                a.inlinePresentationIntent = .code
                attr += a

            case .codeBlock(let s):
                // 简单处理：前后加换行并标记为 code
                var a = AttributedString("\n\(s)\n")
                a.inlinePresentationIntent = .code
                attr += a

            case .link(let u):
                var a = AttributedString(u.absoluteString)
                a.link = u
                attr += a

            case .mention(let m):
                var a = AttributedString(m)
                a.foregroundColor = (m == "@\(myNick)") ? .orange : .blue
                attr += a
            }
        }
        return attr
    }
}


struct AttachmentCard: View {
    let attachment: Attachment
    var body: some View {
        Group {
            switch attachment.kind {
            case .image:
                if let url = attachment.getUrl {
                    AsyncImage(url: url) { ph in
                        switch ph {
                        case .empty: ProgressView()
                        case .success(let img): img.resizable().scaledToFit().cornerRadius(8)
                        case .failure: Label("图片加载失败", systemImage: "xmark.octagon")
                        @unknown default: EmptyView()
                        }
                    }
                    .frame(maxHeight: 240)
                }
            case .video:
                if let url = attachment.getUrl {
                    VideoPlayer(player: AVPlayer(url: url)).frame(height: 220)
                }
            case .audio:
                if let url = attachment.getUrl {
                    HStack {
                        Image(systemName: "waveform").font(.title3)
                        Link("播放音频：\(attachment.filename)", destination: url)
                        Spacer()
                    }
                    .padding(8)
                    .background(.ultraThinMaterial).cornerRadius(8)
                }
            case .file:
                if let url = attachment.getUrl {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text")
                        VStack(alignment: .leading) {
                            Text(attachment.filename)
                            if let s = attachment.sizeBytes { Text(ByteCountFormatter.string(fromByteCount: s, countStyle: .file)).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Link("打开", destination: url)
                    }
                    .padding(8).background(.ultraThinMaterial).cornerRadius(8)
                }
            }
        }
    }
}
