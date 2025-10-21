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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(message.sender == "system" ? "•" : message.sender)
                    .font(.subheadline.weight(.semibold))
                Text(message.timestamp, style: .time)
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .opacity(0.9)

            if !message.text.isEmpty {
                RichText(message: message, myNick: myNick)
            }

            ForEach(message.attachments) { a in
                AttachmentCard(attachment: a)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(message.isLocalEcho ? Color.primary.opacity(0.03) : .clear)
        .cornerRadius(8)
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
