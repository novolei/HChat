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
    let client: HackChatClient  // 添加 client 参数用于音频播放
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
    
    // 气泡背景样式（支持渐变）
    @ViewBuilder
    private var bubbleBackground: some View {
        if message.sender == "system" {
            HChatTheme.systemMessageBubble
        } else if isMyMessage {
            HChatTheme.myMessageBubble
        } else {
            HChatTheme.otherMessageBubble
        }
    }
    
    // 气泡文字颜色
    private var bubbleTextColor: Color {
        if message.sender == "system" {
            return HChatTheme.secondaryText
        }
        return isMyMessage ? HChatTheme.myMessageText : HChatTheme.otherMessageText
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
                        .padding(.horizontal, HChatTheme.mediumSpacing)
                        .padding(.vertical, HChatTheme.smallSpacing + 2)
                        .foregroundColor(bubbleTextColor)
                        .background(
                            bubbleBackground
                                .clipShape(RoundedRectangle(cornerRadius: HChatTheme.largeCornerRadius, style: .continuous))
                        )
                        .shadow(color: isMyMessage ? HChatTheme.mediumShadow : HChatTheme.lightShadow, radius: 4, x: 0, y: 2)
                }

                ForEach(message.attachments) { a in
                    AttachmentCard(attachment: a, client: client)
                }
                
                // ✨ P1: 表情反应气泡（显示在消息下方，对齐方式跟随消息）
                if message.hasReactions {
                    ReactionBubblesView(
                        message: message,
                        myNick: myNick,
                        alignment: isMyMessage ? .trailing : .leading,
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
        .padding(.horizontal, ModernTheme.spacing4)
        .padding(.vertical, 4)
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


// MARK: - 📎 附件卡片（优化版）

struct AttachmentCard: View {
    let attachment: Attachment
    let client: HackChatClient  // 添加 client 参数
    
    var body: some View {
        Group {
            switch attachment.kind {
            case .image:
                ImageAttachmentView(attachment: attachment)
            case .video:
                VideoAttachmentView(attachment: attachment)
            case .audio:
                AudioAttachmentView(attachment: attachment, client: client)
            case .file:
                FileAttachmentView(attachment: attachment)
            }
        }
    }
}

// MARK: - 🖼️ 图片附件

struct ImageAttachmentView: View {
    let attachment: Attachment
    
    var body: some View {
        if let url = attachment.getUrl {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: HChatTheme.mediumCornerRadius, style: .continuous)
                            .fill(HChatTheme.tertiaryBackground)
                        ProgressView()
                            .tint(HChatTheme.accent)
                    }
                    .frame(height: 200)
                    
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: HChatTheme.mediumCornerRadius, style: .continuous))
                        .shadow(color: HChatTheme.lightShadow, radius: 4, x: 0, y: 2)
                    
                case .failure:
                    ZStack {
                        RoundedRectangle(cornerRadius: HChatTheme.mediumCornerRadius, style: .continuous)
                            .fill(HChatTheme.error.opacity(0.1))
                            .frame(height: 120)
                        
                        VStack(spacing: HChatTheme.smallSpacing) {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.largeTitle)
                                .foregroundColor(HChatTheme.error)
                            Text("图片加载失败")
                                .font(HChatTheme.captionFont)
                                .foregroundColor(HChatTheme.secondaryText)
                        }
                    }
                    
                @unknown default:
                    EmptyView()
                }
            }
            .frame(maxHeight: 300)
        }
    }
}

// MARK: - 🎬 视频附件

struct VideoAttachmentView: View {
    let attachment: Attachment
    
    var body: some View {
        if let url = attachment.getUrl {
            VideoPlayer(player: AVPlayer(url: url))
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: HChatTheme.mediumCornerRadius, style: .continuous))
                .shadow(color: HChatTheme.lightShadow, radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - 🎵 音频附件

struct AudioAttachmentView: View {
    let attachment: Attachment
    let client: HackChatClient
    
    private var audioId: String {
        attachment.getUrl ?? attachment.filename
    }
    
    private var audioManager: AudioPlayerManager {
        client.audioPlayerManager
    }
    
    private var isPlaying: Bool {
        audioManager.isPlayingAudio(id: audioId)
    }
    
    private var currentTime: TimeInterval {
        isPlaying ? audioManager.currentTime : 0
    }
    
    private var duration: TimeInterval {
        audioManager.duration > 0 ? audioManager.duration : 10.0
    }
    
    var body: some View {
        VoiceMessagePlayer(
            duration: duration,
            waveformData: generateWaveform(),
            onPlay: {
                Task {
                    await togglePlayback()
                }
            }
        )
    }
    
    private func generateWaveform() -> [CGFloat] {
        // 基于文件名生成一致的波形
        let seed = attachment.filename.hashValue
        return (0..<30).map { index in
            let hash = Double((seed + index).hashValue)
            return CGFloat(abs(sin(hash)) * 0.6 + 0.4)
        }
    }
    
    private func togglePlayback() async {
        guard let urlString = attachment.getUrl else {
            DebugLogger.log("❌ 无效的音频 URL", level: .error)
            return
        }
        
        // 使用当前频道的加密密钥
        let passphrase = client.currentChannel
        
        await audioManager.togglePlayback(
            audioId: audioId,
            url: urlString,
            passphrase: passphrase
        )
    }
}

// MARK: - 📄 文件附件

struct FileAttachmentView: View {
    let attachment: Attachment
    
    private var fileIcon: String {
        let ext = (attachment.filename as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.fill"
        case "doc", "docx": return "doc.text.fill"
        case "xls", "xlsx": return "tablecells.fill"
        case "zip", "rar", "7z": return "doc.zipper"
        default: return "doc.fill"
        }
    }
    
    var body: some View {
        if let url = attachment.getUrl {
            Link(destination: url) {
                HStack(spacing: HChatTheme.mediumSpacing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: HChatTheme.smallCornerRadius, style: .continuous)
                            .fill(HChatTheme.accent.opacity(0.1))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: fileIcon)
                            .font(.title3)
                            .foregroundColor(HChatTheme.accent)
                    }
                    
                    VStack(alignment: .leading, spacing: HChatTheme.tinySpacing) {
                        Text(attachment.filename)
                            .font(HChatTheme.bodyFont)
                            .foregroundColor(HChatTheme.primaryText)
                            .lineLimit(2)
                        
                        if let size = attachment.sizeBytes {
                            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                .font(HChatTheme.captionFont)
                                .foregroundColor(HChatTheme.secondaryText)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.down.circle")
                        .font(.title2)
                        .foregroundColor(HChatTheme.accent)
                }
                .padding(HChatTheme.mediumSpacing)
                .background(HChatTheme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: HChatTheme.mediumCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: HChatTheme.mediumCornerRadius, style: .continuous)
                        .stroke(HChatTheme.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}
