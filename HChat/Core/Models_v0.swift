//
//  Models.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum ConnectionState: String { case disconnected, connecting, connected }
enum MessageKind { case normal, action, system, attachment }

struct AttachmentMeta: Codable, Equatable {
    enum Kind: String, Codable { case image, video, audio, file }
    let kind: Kind
    let url: URL
    let mime: String
    let fileName: String?
    let bytes: Int64?
    let thumbURL: URL?   // ✅ 缩略图
}
//
//struct ChatMessage: Identifiable, Equatable {
//    let id: UUID
//    let senderNickname: String
//    let plaintext: String          // 已解密；ATTACH:xxx 已转换为 meta
//    let isFromSelf: Bool
//    let timestamp: Date
//    let kind: MessageKind
//    let attachment: AttachmentMeta?
//    var isProvisional: Bool = false   // ✅ 本地回显待确认（用于去重）
//
//    init(id: UUID = UUID(),
//         senderNickname: String,
//         plaintext: String,
//         isFromSelf: Bool,
//         timestamp: Date = Date(),
//         kind: MessageKind,
//         attachment: AttachmentMeta? = nil,
//         isProvisional: Bool = false) {
//        self.id = id
//        self.senderNickname = senderNickname
//        self.plaintext = plaintext
//        self.isFromSelf = isFromSelf
//        self.timestamp = timestamp
//        self.kind = kind
//        self.attachment = attachment
//        self.isProvisional = isProvisional
//    }
//}
//
//struct Channel: Identifiable, Hashable {
//    enum Kind { case publicRoom, direct }
//    let id = UUID()
//    let name: String       // 频道名（ws层）
//    let kind: Kind
//    let displayName: String
//
//    static func direct(between a: String, and b: String) -> Channel {
//        let A = a.hcBaseNick.lowercased(), B = b.hcBaseNick.lowercased()
//        let names = [A, B].sorted()
//        return Channel(name: "dm.\(names[0]).\(names[1])",
//                       kind: .direct,
//                       displayName: "🔒 \(names[1])")
//    }
//}
