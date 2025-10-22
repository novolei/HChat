//
//  ConnectionStatusBanner.swift
//  HChat
//
//  Created on 2025-10-22.
//  连接状态提示条

import SwiftUI

/// 连接状态
enum ConnectionStatus {
    case connected
    case connecting
    case disconnected
    
    var text: String {
        switch self {
        case .connected: return "已连接"
        case .connecting: return "正在重连..."
        case .disconnected: return "连接已断开"
        }
    }
    
    var icon: String {
        switch self {
        case .connected: return "wifi"
        case .connecting: return "wifi.exclamationmark"
        case .disconnected: return "wifi.slash"
        }
    }
    
    var color: Color {
        switch self {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .red
        }
    }
}

/// 连接状态提示条
struct ConnectionStatusBanner: View {
    let status: ConnectionStatus
    let onReconnect: () -> Void
    
    var body: some View {
        if status != .connected {
            HStack(spacing: 12) {
                // 状态图标
                Image(systemName: status.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                // 状态文本
                Text(status.text)
                    .font(ModernTheme.subheadline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // 重连按钮
                if status == .disconnected {
                    Button {
                        onReconnect()
                        HapticManager.impact(style: .light)
                    } label: {
                        Text("重新连接")
                            .font(ModernTheme.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                            )
                    }
                    .buttonStyle(.plain)
                } else if status == .connecting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, ModernTheme.spacing4)
            .padding(.vertical, ModernTheme.spacing2)
            .background(
                Rectangle()
                    .fill(status.color.gradient)
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - 预览

#Preview("已连接") {
    ConnectionStatusBanner(status: .connected, onReconnect: {})
}

#Preview("重连中") {
    ConnectionStatusBanner(status: .connecting, onReconnect: {})
}

#Preview("已断开") {
    ConnectionStatusBanner(status: .disconnected, onReconnect: {})
}

