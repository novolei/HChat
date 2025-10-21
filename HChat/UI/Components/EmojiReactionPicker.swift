//
//  EmojiReactionPicker.swift
//  HChat
//
//  Created on 2025-10-21.
//  表情反应选择器 UI 组件

import SwiftUI

/// 快捷表情反应选择器（长按消息时显示）
struct EmojiReactionPicker: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // 快捷反应按钮行
            HStack(spacing: 16) {
                ForEach(QuickReactions.defaults, id: \.self) { emoji in
                    Button {
                        onSelect(emoji)
                        dismiss()
                    } label: {
                        Text(emoji)
                            .font(.system(size: 32))
                            .frame(width: 44, height: 44)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }
}

/// 完整的表情选择器（带更多选项）
struct FullEmojiReactionPicker: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    private let columns = [
        GridItem(.adaptive(minimum: 44), spacing: 12)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(QuickReactions.all, id: \.self) { emoji in
                        Button {
                            onSelect(emoji)
                            dismiss()
                        } label: {
                            Text(emoji)
                                .font(.system(size: 32))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("选择表情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// 反应气泡（显示在消息下方）
struct ReactionBubble: View {
    let emoji: String
    let count: Int
    let isMyReaction: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(emoji)
                    .font(.body)
                if count > 1 {
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isMyReaction ? .white : .primary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isMyReaction
                    ? Color.blue
                    : Color(.systemGray5)
            )
            .foregroundColor(isMyReaction ? .white : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isMyReaction ? Color.blue.opacity(0.3) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

/// 反应气泡组（显示所有反应）
struct ReactionBubblesView: View {
    let message: ChatMessage
    let myNick: String
    let alignment: HorizontalAlignment  // 对齐方式：.leading（左）或 .trailing（右）
    let onTapReaction: (String) -> Void
    let onShowMore: () -> Void
    
    var body: some View {
        if message.hasReactions {
            // 直接返回 HStack，让父 VStack 控制对齐（与"1人已读"相同的方式）
            HStack(spacing: 6) {
                ForEach(message.reactionSummaries, id: \.emoji) { summary in
                    ReactionBubble(
                        emoji: summary.emoji,
                        count: summary.count,
                        isMyReaction: summary.contains(user: myNick)
                    ) {
                        onTapReaction(summary.emoji)
                    }
                }
                
                // 添加反应按钮
                Button {
                    onShowMore()
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
    }
}

/// 反应详情视图（显示谁添加了反应）
struct ReactionDetailView: View {
    let message: ChatMessage
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(message.reactionSummaries, id: \.emoji) { summary in
                    Section {
                        ForEach(summary.users, id: \.self) { user in
                            HStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.3))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Text(user.prefix(1).uppercased())
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    )
                                
                                Text(user)
                                    .font(.body)
                                
                                Spacer()
                            }
                        }
                    } header: {
                        HStack {
                            Text(summary.emoji)
                                .font(.title2)
                            Text("\(summary.count) 人")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("反应详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 预览

#Preview("快捷选择器") {
    EmojiReactionPicker { emoji in
        print("Selected: \(emoji)")
    }
}

#Preview("反应气泡") {
    VStack(spacing: 16) {
        ReactionBubble(emoji: "👍", count: 3, isMyReaction: false) {}
        ReactionBubble(emoji: "❤️", count: 1, isMyReaction: true) {}
        ReactionBubble(emoji: "😂", count: 12, isMyReaction: false) {}
    }
    .padding()
}

#Preview("反应气泡组") {
    var sampleMessage: ChatMessage {
        var msg = ChatMessage(
            id: "1",
            channel: "lobby",
            sender: "Alice",
            text: "Hello world!"
        )
        msg.reactions = [
            "👍": [
                MessageReaction(emoji: "👍", userId: "Bob"),
                MessageReaction(emoji: "👍", userId: "Charlie")
            ],
            "❤️": [
                MessageReaction(emoji: "❤️", userId: "Alice")
            ]
        ]
        return msg
    }
    
//    ReactionBubblesView(
//        message: sampleMessage,
//        myNick: "Alice",
//        onTapReaction: { _ in },
//        onShowMore: {}
//    )
//    .padding()
}

