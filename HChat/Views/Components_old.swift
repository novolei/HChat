//
//  Components.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//

import SwiftUI
import AVKit

struct AttachmentCardView: View {
    let attachment: AttachmentMeta
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch attachment.kind {
            case .image:
                AsyncImage(url: attachment.thumbURL ?? attachment.url) { p in
                    switch p {
                    case .success(let img): img.resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure(_): placeholder
                    case .empty: placeholder
                    @unknown default: placeholder
                    }
                }.frame(maxHeight: 260)
            case .video:
                if let thumb = attachment.thumbURL {
                    ZStack {
                        AsyncImage(url: thumb) { p in
                            switch p {
                            case .success(let img): img.resizable().scaledToFit()
                            default: Color.black.opacity(0.2)
                            }
                        }
                        Image(systemName: "play.circle.fill").imageScale(.large)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    VideoPlayer(player: AVPlayer(url: attachment.url))
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            case .audio:
                HStack {
                    Image(systemName: "waveform.circle").imageScale(.large)
                    Text(attachment.fileName ?? "音频").lineLimit(1)
                    Spacer()
                    Link("播放", destination: attachment.url)
                }
            case .file:
                HStack {
                    Image(systemName: "doc.fill").imageScale(.large)
                    VStack(alignment: .leading) {
                        Text(attachment.fileName ?? "文件").lineLimit(1)
                        Text(attachment.mime).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Link("打开", destination: attachment.url)
                }
            }
            if let bytes = attachment.bytes {
                Text("\(bytes) bytes").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(HackTheme.otherBubble, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(HackTheme.panelStroke))
    }
    private var placeholder: some View {
        ZStack { RoundedRectangle(cornerRadius: 12).fill(HackTheme.otherBubble); ProgressView() }.frame(height: 220)
    }
}

//struct MessageRowView: View {
//    let message: ChatMessage
//    let myBaseNick: String
//    let tsStyle: TimestampStyle
//
//    var body: some View {
//        HStack(alignment: .top, spacing: 10) {
//            if message.isFromSelf { Spacer(minLength: 24) }
//            if !message.isFromSelf {
//                Text("[\(message.senderNickname.hcBaseNick)]")
//                    .font(.caption2)
//                    .foregroundStyle(colorForNickname(message.senderNickname))
//                    .padding(.top, 6)
//                    .frame(minWidth: 70, alignment: .trailing)
//            }
//            VStack(alignment: message.isFromSelf ? .trailing : .leading, spacing: 4) {
//                RichMessageText(message: message, myBaseNick: myBaseNick)
//                    .padding(.horizontal, 12).padding(.vertical, 8)
//                    .background(message.kind == .system ? Color.clear : (message.isFromSelf ? HackTheme.myBubble : HackTheme.otherBubble),
//                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
//                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(HackTheme.panelStroke).opacity(message.kind == .system ? 0 : 1))
//
//                if let t = formattedTimestamp(message.timestamp, style: tsStyle) {
//                    Text(message.isProvisional ? "\(t) · 正在发送…" : t)
//                        .font(.caption2).foregroundStyle(.secondary)
//                }
//            }
//            if message.isFromSelf {
//                Image(systemName: "person.circle.fill").foregroundStyle(Color.accentColor).padding(.top, 6)
//            }
//        }
//        .frame(maxWidth: .infinity, alignment: message.isFromSelf ? .trailing : .leading)
//        .opacity(message.isProvisional ? 0.7 : 1)
//    }
//}
