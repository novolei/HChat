//
//  DoubleCheckmarkView.swift
//  HChat
//
//  Created on 2025-10-23.
//  自定义双勾图标 - 类似 WhatsApp 的已读回执显示
//

import SwiftUI

/// 双勾图标视图（模仿 WhatsApp 风格）
struct DoubleCheckmarkView: View {
    let color: Color
    let size: CGFloat
    
    init(color: Color = .green, size: CGFloat = 12) {
        self.color = color
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // 后面的勾（稍微偏左）
            Image(systemName: "checkmark")
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(color)
                .offset(x: -size * 0.25, y: 0)
            
            // 前面的勾（稍微偏右）
            Image(systemName: "checkmark")
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(color)
                .offset(x: size * 0.15, y: 0)
        }
        .frame(width: size * 1.5, height: size)
    }
}

/// 单勾图标视图
struct SingleCheckmarkView: View {
    let color: Color
    let size: CGFloat
    
    init(color: Color = .gray, size: CGFloat = 12) {
        self.color = color
        self.size = size
    }
    
    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(color)
            .frame(width: size, height: size)
    }
}

// MARK: - Preview

#Preview("状态对比") {
    VStack(spacing: 20) {
        HStack(spacing: 15) {
            VStack {
                SingleCheckmarkView(color: .gray, size: 16)
                Text("已发送")
                    .font(.caption)
            }
            
            VStack {
                DoubleCheckmarkView(color: .gray, size: 16)
                Text("已送达")
                    .font(.caption)
            }
            
            VStack {
                DoubleCheckmarkView(color: .green, size: 16)
                Text("已读")
                    .font(.caption)
            }
        }
        
        Divider()
        
        // 不同尺寸
        HStack(spacing: 20) {
            DoubleCheckmarkView(color: .green, size: 10)
            DoubleCheckmarkView(color: .green, size: 12)
            DoubleCheckmarkView(color: .green, size: 14)
            DoubleCheckmarkView(color: .green, size: 16)
        }
    }
    .padding()
}

