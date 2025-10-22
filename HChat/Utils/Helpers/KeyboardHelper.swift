//
//  KeyboardHelper.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//  ⌨️ 键盘管理工具 - 自然、丝滑的隐藏体验
//

import SwiftUI

// MARK: - ⌨️ 键盘管理器

enum KeyboardHelper {
    private static var isKeyboardVisible = false
    private static let configureOnce: Void = {
        let center = NotificationCenter.default
        center.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
            isKeyboardVisible = true
        }
        center.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            isKeyboardVisible = false
        }
    }()
    
    static func ensureConfigured() {
        _ = configureOnce
    }
    
    /// 隐藏键盘（force=true 时无视当前显示状态）
    static func hideKeyboard(force: Bool = false) {
        ensureConfigured()
        guard force || isKeyboardVisible else { return }
        DispatchQueue.main.async {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }
    
    /// 强制隐藏键盘
    static func forceHideKeyboard() {
        hideKeyboard(force: true)
    }
}

// MARK: - 🪄 键盘隐藏辅助视图

private struct KeyboardDismissOverlay: UIViewRepresentable {
    struct Options: OptionSet {
        let rawValue: Int
        static let tap = Options(rawValue: 1 << 0)
        static let drag = Options(rawValue: 1 << 1)
        static let all: Options = [.tap, .drag]
    }
    
    var options: Options
    
    init(options: Options) {
        self.options = options
        KeyboardHelper.ensureConfigured()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(options: options)
    }
    
    func makeUIView(context: Context) -> PassthroughView {
        let view = PassthroughView()
        view.isUserInteractionEnabled = false
        return view
    }
    
    func updateUIView(_ uiView: PassthroughView, context: Context) {
        context.coordinator.options = options
        context.coordinator.attachIfNeeded(using: uiView)
    }
    
    final class PassthroughView: UIView {
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool { false }
    }
    
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var options: Options
        private weak var hostView: UIView?
        private var panHasTriggered = false
        
        private lazy var tapGesture: UITapGestureRecognizer = {
            let gesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            gesture.cancelsTouchesInView = false
            gesture.delegate = self
            return gesture
        }()
        
        private lazy var panGesture: UIPanGestureRecognizer = {
            let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            gesture.cancelsTouchesInView = false
            gesture.delegate = self
            gesture.maximumNumberOfTouches = 1
            return gesture
        }()
        
        init(options: Options) {
            self.options = options
        }
        
        func attachIfNeeded(using overlay: UIView) {
            guard let host = overlay.superview else { return }
            
            if hostView !== host {
                detachGestures(from: hostView)
                hostView = host
            }
            
            panHasTriggered = false
            
            if options.contains(.tap) {
                if tapGesture.view !== host {
                    host.addGestureRecognizer(tapGesture)
                }
                tapGesture.isEnabled = true
            } else {
                tapGesture.isEnabled = false
            }
            
            if options.contains(.drag) {
                if panGesture.view !== host {
                    host.addGestureRecognizer(panGesture)
                }
                panGesture.isEnabled = true
            } else {
                panGesture.isEnabled = false
            }
        }
        
        private func detachGestures(from view: UIView?) {
            guard let view else { return }
            if tapGesture.view === view {
                view.removeGestureRecognizer(tapGesture)
            }
            if panGesture.view === view {
                view.removeGestureRecognizer(panGesture)
            }
        }
        
        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended else { return }
            KeyboardHelper.hideKeyboard()
        }
        
        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began:
                panHasTriggered = false
            case .changed:
                guard !panHasTriggered else { return }
                let translation = gesture.translation(in: gesture.view)
                let distance = hypot(translation.x, translation.y)
                if distance > 8 {
                    panHasTriggered = true
                    KeyboardHelper.hideKeyboard()
                }
            case .ended, .cancelled, .failed:
                panHasTriggered = false
            default:
                break
            }
        }
        
        // MARK: - UIGestureRecognizerDelegate
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let view = touch.view else { return true }
            return !isTextInputView(view)
        }
        
        private func isTextInputView(_ view: UIView?) -> Bool {
            guard let view else { return false }
            if view is UITextField || view is UITextView || view is UISearchTextField {
                return true
            }
            return isTextInputView(view.superview)
        }
    }
}

// MARK: - 🔌 View 扩展

extension View {
    /// 点击时隐藏键盘（避免拦截子视图输入控件）
    func hideKeyboardOnTap() -> some View {
        background(KeyboardDismissOverlay(options: [.tap]))
    }
    
    /// 拖动时隐藏键盘（避免拦截子视图输入控件）
    func hideKeyboardOnDrag() -> some View {
        background(KeyboardDismissOverlay(options: [.drag]))
    }
    
    /// 点击或拖动均可隐藏键盘（推荐，iOS 16+ 仅保留点击以获得原生滚动动画）
    @ViewBuilder
    func interactiveDismissKeyboard() -> some View {
        if #available(iOS 16.0, *) {
            self.hideKeyboardOnTap()
        } else {
            self.background(KeyboardDismissOverlay(options: .all))
        }
    }
    
    /// 滚动时隐藏键盘（iOS 16+ 使用原生交互，旧系统优雅降级）
    @ViewBuilder
    func scrollDismissesKeyboardIfAvailable() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(.interactively)
        } else {
            self.hideKeyboardOnDrag()
        }
    }
}
