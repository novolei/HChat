//
//  ToastView.swift
//  HChat
//
//  Created on 2025-10-21.
//  Toast 提示组件
//

import SwiftUI

/// Toast 消息模型
struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let icon: String?
    let duration: TimeInterval
    
    init(text: String, icon: String? = nil, duration: TimeInterval = 2.0) {
        self.text = text
        self.icon = icon
        self.duration = duration
    }
}

/// Toast 显示视图
struct ToastView: View {
    let message: ToastMessage
    
    var body: some View {
        HStack(spacing: 8) {
            if let icon = message.icon {
                Image(systemName: icon)
                    .font(.subheadline)
            }
            Text(message.text)
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .foregroundColor(.primary)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

/// Toast 管理器（用于在视图中显示 Toast）
struct ToastModifier: ViewModifier {
    @Binding var toast: ToastMessage?
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            
            if let toast = toast {
                VStack {
                    ToastView(message: toast)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 16)
                        .padding(.horizontal, 16)
                        .zIndex(1000)
                    
                    Spacer()
                }
                .onAppear {
                    // 自动隐藏
                    DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
                        withAnimation {
                            self.toast = nil
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: toast != nil)
    }
}

extension View {
    /// 显示 Toast 提示
    func toast(_ toast: Binding<ToastMessage?>) -> some View {
        self.modifier(ToastModifier(toast: toast))
    }
}

#Preview {
    VStack {
        Text("Content")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .toast(.constant(ToastMessage(text: "新消息反应", icon: "heart.fill")))
}

