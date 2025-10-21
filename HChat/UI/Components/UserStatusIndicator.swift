//
//  UserStatusIndicator.swift
//  HChat
//
//  Created on 2025-10-21.
//  用户在线状态指示器 UI 组件

import SwiftUI

/// 用户在线状态指示器（小圆点）
struct UserStatusIndicator: View {
    let status: UserStatus
    let size: CGFloat
    
    init(status: UserStatus, size: CGFloat = 12) {
        self.status = status
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // 背景圆（用于离线状态的描边效果）
            Circle()
                .strokeBorder(status == .offline ? Color.gray : Color.clear, lineWidth: 2)
                .background(Circle().fill(status.color))
                .frame(width: size, height: size)
            
            // 忙碌状态的横线
            if status == .busy {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: size * 0.6, height: 2)
            }
            
            // 离开状态的月亮图标
            if status == .away {
                Image(systemName: "moon.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.6, height: size * 0.6)
                    .foregroundColor(.white)
            }
        }
    }
}

/// 带文字的用户状态显示（用于设置界面）
struct UserStatusRow: View {
    let status: UserStatus
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                UserStatusIndicator(status: status, size: 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.displayName)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(statusDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
    
    private var statusDescription: String {
        switch status {
        case .online: return "活跃状态，接收所有通知"
        case .away: return "离开状态，仅接收重要通知"
        case .busy: return "忙碌状态，请勿打扰"
        case .offline: return "离线状态，不接收通知"
        }
    }
}

/// 在线用户列表项
struct OnlineUserRow: View {
    let presence: UserPresence
    let myNick: String
    
    var body: some View {
        HStack(spacing: 12) {
            // 头像占位符
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(presence.id.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.white)
                    )
                
                // 状态指示器
                UserStatusIndicator(status: presence.status, size: 12)
                    .offset(x: 2, y: 2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(presence.id)
                        .font(.body)
                        .fontWeight(presence.id == myNick ? .bold : .regular)
                    
                    if presence.id == myNick {
                        Text("(你)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 最后活跃时间或当前频道
                if let channel = presence.channel, presence.isOnline {
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(.caption2)
                        Text(channel)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                } else {
                    Text(presence.lastSeenString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 状态文本（紧凑显示）
            Text(presence.status.emoji)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

/// 状态选择器（Sheet 弹窗）
struct StatusPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var currentStatus: UserStatus
    let onStatusChange: (UserStatus) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                ForEach([UserStatus.online, .away, .busy, .offline], id: \.self) { status in
                    UserStatusRow(
                        status: status,
                        isSelected: currentStatus == status
                    ) {
                        currentStatus = status
                        onStatusChange(status)
                        dismiss()
                    }
                }
            }
            .navigationTitle("设置状态")
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

#Preview("状态指示器") {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            VStack {
                UserStatusIndicator(status: .online)
                Text("在线")
                    .font(.caption)
            }
            VStack {
                UserStatusIndicator(status: .away)
                Text("离开")
                    .font(.caption)
            }
            VStack {
                UserStatusIndicator(status: .busy)
                Text("忙碌")
                    .font(.caption)
            }
            VStack {
                UserStatusIndicator(status: .offline)
                Text("离线")
                    .font(.caption)
            }
        }
        
        Divider()
        
        VStack(alignment: .leading, spacing: 8) {
            OnlineUserRow(
                presence: UserPresence(id: "Alice", status: .online, channel: "lobby"),
                myNick: "Bob"
            )
            OnlineUserRow(
                presence: UserPresence(id: "Bob", status: .away, channel: "lobby"),
                myNick: "Bob"
            )
            OnlineUserRow(
                presence: UserPresence(id: "Charlie", status: .busy),
                myNick: "Bob"
            )
        }
        .padding()
    }
}

#Preview("状态选择器") {
    StatusPickerView(
        currentStatus: .constant(.online),
        onStatusChange: { _ in }
    )
}

