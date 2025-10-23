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
    let client: HackChatClient
    var isHighlighted: Bool = false
    var onLongPress: ((ChatMessage) -> Void)? = nil
    var onShowReactionDetail: (() -> Void)? = nil
    var onReply: (() -> Void)? = nil
    var onJumpToReply: ((String) -> Void)? = nil
    var onShowReadReceipts: (() -> Void)? = nil
    
    private var isMyMessage: Bool { message.sender == myNick }
    private var isSystemMessage: Bool { message.sender == "system" }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if isMyMessage && !isSystemMessage {
                Spacer(minLength: 0)
            }
            
            HStack(alignment: .top, spacing: 12) {
                if !isMyMessage && !isSystemMessage {
                    avatar
                }
                
                VStack(alignment: isMyMessage ? .trailing : .leading, spacing: 6) {
                    metadataView
                    
                    bubbleWithReactions
                        .frame(maxWidth: .infinity, alignment: isMyMessage ? .trailing : .leading)
                }
                .scaleEffect(isHighlighted ? 1.03 : 1.0)
                .animation(.spring(response: 0.32, dampingFraction: 0.72), value: isHighlighted)
                .overlay(highlightOverlay)
                .background(anchorReporter)
                .contentShape(Rectangle())
                .gesture(
                    LongPressGesture(minimumDuration: 0.35)
                        .onEnded { _ in
                            HapticManager.impact(style: .medium)
                            onLongPress?(message)
                        }
                )
                .onTapGesture(count: 2) {
                    onReply?()
                }
                
                if isMyMessage && !isSystemMessage {
                    avatar
                }
            }
            
            if !isMyMessage && !isSystemMessage {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, ModernTheme.spacing4)
        .padding(.vertical, 10)
    }
    
    @ViewBuilder
    private var metadataView: some View {
        if !isSystemMessage && !isMyMessage {
            HStack(spacing: 8) {
                Text(message.sender)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ModernTheme.secondaryText)
            }
            .padding(.horizontal, 6)
            .opacity(0.9)
        }
    }
    
    @ViewBuilder
    private var contentBubble: some View {
        if message.replyTo != nil || !message.text.isEmpty || !message.attachments.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if let reply = message.replyTo {
                    QuotedMessageView(reply: reply) {
                        onJumpToReply?(reply.messageId)
                    }
                }
                
                if !message.text.isEmpty {
                    RichText(message: message, myNick: myNick, allowSelection: false)
                        .foregroundColor(bubbleTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                attachmentsView
                
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    MessageTimestampWithStatus(message: message, myNick: myNick)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                bubbleBackground
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(isMyMessage ? 0.18 : 0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isMyMessage ? 0.15 : 0.08), radius: 14, y: 6)
            .frame(minWidth: 120, maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading)
        }
    }
    
    private var bubbleWithReactions: some View {
        ZStack(alignment: .bottomLeading) {
            contentBubble
            
            if message.hasReactions {
                ReactionBadgeView(
                    message: message,
                    myNick: myNick,
                    alignTrailing: isMyMessage,
                    onShowDetail: onShowReactionDetail
                )
                .offset(x: 18, y: 16)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.bottom, message.hasReactions ? 24 : 0)
    }
    
    @ViewBuilder
    private var attachmentsView: some View {
        ForEach(message.attachments) { attachment in
            AttachmentCard(attachment: attachment, client: client)
        }
    }
    
    @ViewBuilder
    private var reactionsView: some View {
        EmptyView()
    }
    
    @ViewBuilder
    private var readReceiptsView: some View {
        if message.hasReadReceipts && message.sender == myNick {
            Button {
                onShowReadReceipts?()
            } label: {
                ReadReceiptIndicator(message: message, showDetails: true)
            }
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private var highlightOverlay: some View {
        EmptyView()
    }
    
    private var bubbleBackground: some View {
        Group {
            if isSystemMessage {
                HChatTheme.systemMessageBubble
            } else if isMyMessage {
                HChatTheme.myMessageBubble
            } else {
                HChatTheme.otherMessageBubble
            }
        }
    }
    
    private var bubbleTextColor: Color {
        if isSystemMessage {
            return HChatTheme.secondaryText
        }
        return isMyMessage ? HChatTheme.myMessageText : HChatTheme.otherMessageText
    }
    
    private var avatar: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(Color.white)
                .frame(width: 48, height: 48)
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "7158FF"), Color(hex: "FF8DC7")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(4)
                        .overlay(
                            Text(message.sender.prefix(1).uppercased())
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        )
                )
                .shadow(color: Color.black.opacity(0.12), radius: 8, y: 6)
        }
    }
    
    private var anchorReporter: some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: MessageFramePreferenceKey.self,
                value: [
                    message.id: MessageAnchorInfo(
                        frameInScroll: geo.frame(in: .named("chatScroll")),
                        globalFrame: geo.frame(in: .global),
                        isMine: isMyMessage
                    )
                ]
            )
        }
    }
}

struct ReactionBadgeView: View {
    let message: ChatMessage
    let myNick: String
    let alignTrailing: Bool
    let onShowDetail: (() -> Void)?
    
    private let maxDisplayCount = 8
    
    var body: some View {
        let allSummaries = message.reactionSummaries
        let displayedSummaries = Array(allSummaries.prefix(maxDisplayCount))
        let hasMore = allSummaries.count > maxDisplayCount
        
        guard !displayedSummaries.isEmpty else { return AnyView(EmptyView()) }
        
        let badge = Button {
            onShowDetail?()
        } label: {
            HStack(spacing: 6) {
                ForEach(displayedSummaries, id: \.emoji) { summary in
                    HStack(spacing: 3) {
                        Text(summary.emoji)
                            .font(.system(size: 16))
                        
                        if summary.count > 1 {
                            Text("\(summary.count)")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                }
                
                if hasMore {
                    Text("...")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(hex: "5B36FF"), Color(hex: "FF6CCB")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            )
            .foregroundColor(.white)
            .shadow(color: Color.black.opacity(0.14), radius: 10, y: 6)
        }
            .buttonStyle(.plain)
        
        return AnyView(badge)
    }
}

struct RichText: View {
    let message: ChatMessage
    let myNick: String
    var allowSelection: Bool = true
    
    var body: some View {
        let text = Text(buildAttributed())
        if allowSelection {
            text.textSelection(.enabled)
        } else {
            text
        }
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
        attachment.getUrl?.absoluteString ?? attachment.filename
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
        // 优先使用附件中嵌入的时长（发送时已计算好）
        if let embeddedDuration = attachment.duration, embeddedDuration > 0 {
            return embeddedDuration
        }
        // 如果是当前播放的音频，使用 audioManager 的时长
        if audioManager.currentPlayingId == audioId && audioManager.duration > 0 {
            return audioManager.duration
        }
        // 否则尝试从本地缓存获取时长，如果没有则返回默认值
        return getAudioDuration() ?? 0.0
    }
    
    var body: some View {
        VoiceMessagePlayer(
            isPlaying: isPlaying,
            currentTime: currentTime,
            duration: duration,
            waveformData: attachment.waveform ?? generateWaveform(), // 优先使用嵌入的波形数据
            onPlay: {
                Task {
                    await togglePlayback()
                }
            }
        )
    }
    
    /// 尝试从缓存获取音频时长
    private func getAudioDuration() -> TimeInterval? {
        let cacheFileName = "audio_\(abs(audioId.hashValue))"
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AudioCache", isDirectory: true)
        let cachedURL = cacheDirectory.appendingPathComponent(cacheFileName + ".m4a")
        
        guard FileManager.default.fileExists(atPath: cachedURL.path) else {
            return nil
        }
        
        // 使用 AVAudioPlayer 获取时长
        do {
            let player = try AVAudioPlayer(contentsOf: cachedURL)
            return player.duration
        } catch {
            return nil
        }
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
        guard let url = attachment.getUrl else {
            DebugLogger.log("❌ 无效的音频 URL", level: .error)
            return
        }
        
        // 使用当前频道的加密密钥
        let passphrase = client.currentChannel
        
        await audioManager.togglePlayback(
            audioId: audioId,
            url: url.absoluteString,
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
