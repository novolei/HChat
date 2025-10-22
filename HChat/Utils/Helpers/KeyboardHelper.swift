//
//  KeyboardHelper.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//  ⌨️ 键盘管理工具 - 自然流畅的键盘隐藏体验
//

import SwiftUI

// MARK: - ⌨️ 键盘管理器

enum KeyboardHelper {
    /// 隐藏键盘
    static func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

// MARK: - 🖱️ 点击隐藏键盘修饰符

struct HideKeyboardOnTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture {
                KeyboardHelper.hideKeyboard()
            }
    }
}

extension View {
    /// 点击视图隐藏键盘 - 自然流畅
    func hideKeyboardOnTap() -> some View {
        modifier(HideKeyboardOnTapModifier())
    }
}

// MARK: - 📜 滚动时隐藏键盘修饰符

extension View {
    /// 滚动时自动隐藏键盘（iOS 16+自动兼容）
    func scrollDismissesKeyboardIfAvailable() -> some View {
        if #available(iOS 16.0, *) {
            return AnyView(self.scrollDismissesKeyboard(.interactively))
        } else {
            return AnyView(self)
        }
    }
}

