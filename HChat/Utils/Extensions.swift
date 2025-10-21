//
//  Extensions.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//

import SwiftUI
import Foundation

// 安全下标
extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// 视图条件修饰
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool,
                             transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

// 简易占位 HUD
struct InlineHUD: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text(text)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
    }
}

// Data <-> Hex（可调试用）
extension Data {
    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}
