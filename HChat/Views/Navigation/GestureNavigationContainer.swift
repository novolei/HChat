//
//  GestureNavigationContainer.swift
//  HChat
//
//  Created on 2025-10-23.
//  🎨 沉浸式手势导航系统 - 满屏无边界设计
//

import SwiftUI

/// 主导航容器 - 9宫格手势导航
struct GestureNavigationContainer: View {
    let client: HackChatClient
    
    // MARK: - 导航状态
    @State private var verticalIndex = 0    // 0=Moments, 1=Connections, 2=Channels
    @State private var horizontalIndex = 1  // 0=Explorer, 1=Home, 2=Personalization
    
    // MARK: - 手势状态
    @State private var dragOffset: CGSize = .zero
    @State private var isTransitioning = false
    @State private var isTwoFingerGesture = false  // 双指手势标记
    @State private var lastTransitionDirection: Edge = .bottom  // 记录最后的过渡方向
    
    // MARK: - 滚动检测
    @State private var isScrolledToTop = false
    @State private var isScrolledToBottom = false
    
    // MARK: - UI 提示
    @State private var showCentralIndicator = false
    @State private var showEdgeHints = true
    @State private var lastGestureTime: Date = Date()
    
    // MARK: - 触觉反馈
    let impactLight = UIImpactFeedbackGenerator(style: .light)
    let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    
    var body: some View {
        ZStack {
            // ✨ 背景渐变（跟随当前视图）
            currentGradient
                .ignoresSafeArea()
            
            // ✨ 主内容区域（完全沉浸）
            VStack(spacing: 0) {
                // 极简 Header（贴近动态岛）
                if shouldShowHeader {
                    minimalistHeader
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // 内容区域（满屏）
                currentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // ✨ 移除 offset，防止抖动，拖动效果由内部 ZStack 处理
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // ✨ 边缘导航提示（呼吸动画）
            if showEdgeHints {
                edgeNavigationHints
                    .transition(.opacity)
            }
            
            // ✨ 中央位置指示器（短暂显示）
            if showCentralIndicator {
                centralPositionIndicator
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .simultaneousGesture(navigationGesture)  // 🔑 参考 MomentsHomeView 的方式
        .onAppear {
            setupInitialState()
        }
    }
    
    // MARK: - Header
    
    private var shouldShowHeader: Bool {
        // 只在特定视图显示 header
        switch (verticalIndex, horizontalIndex) {
        case (1, 1), (2, 1):  // Connections 和 Channels
            return true
        default:
            return false
        }
    }
    
    private var minimalistHeader: some View {
        HStack {
            // 当前位置标题
            Text(currentLocationTitle)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
            
            // 位置指示点
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i == verticalIndex ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.3), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }
    
    private var currentLocationTitle: String {
        switch (verticalIndex, horizontalIndex) {
        case (1, 1): return "聊天"
        case (2, 1): return "频道 & 通讯录"
        default: return ""
        }
    }
    
    // MARK: - 当前视图
    
    @ViewBuilder
    private var currentView: some View {
        // ✨ 抖音/微信风格：当前视图和相邻视图同步移动
        ZStack {
            let screenHeight = UIScreen.main.bounds.height
            let screenWidth = UIScreen.main.bounds.width
            
            // 垂直拖动时
            if abs(dragOffset.height) > 10 && dragOffset.height > 0 && horizontalIndex == 1 {
                let nextV = (verticalIndex + 1) % 3
                
                // 当前视图 - 跟随手指向下移动
                viewForPosition(vertical: verticalIndex, horizontal: horizontalIndex)
                    .offset(y: dragOffset.height)
                    .zIndex(1)
                
                // 下一个视图 - 从上方跟随进入
                viewForPosition(vertical: nextV, horizontal: horizontalIndex)
                    .offset(y: -screenHeight + dragOffset.height)
                    .zIndex(0)
            }
            // 水平拖动时
            else if abs(dragOffset.width) > 10 && verticalIndex == 0 {
                let nextH = dragOffset.width < 0 ? (horizontalIndex + 1) % 3 : (horizontalIndex - 1 + 3) % 3
                
                // 当前视图 - 跟随手指移动
                viewForPosition(vertical: verticalIndex, horizontal: horizontalIndex)
                    .offset(x: dragOffset.width)
                    .zIndex(1)
                
                // 下一个视图 - 从对应方向跟随进入
                viewForPosition(vertical: verticalIndex, horizontal: nextH)
                    .offset(x: dragOffset.width < 0 ? screenWidth + dragOffset.width : -screenWidth + dragOffset.width)
                    .zIndex(0)
            }
            // 没有拖动时
            else {
                viewForPosition(vertical: verticalIndex, horizontal: horizontalIndex)
                    .zIndex(1)
            }
        }
    }
    
    @ViewBuilder
    private func viewForPosition(vertical: Int, horizontal: Int) -> some View {
        switch (vertical, horizontal) {
        // 第一层：Moments Home 三视图
        case (0, 0):
            ExplorerView(client: client)
                .onScrollPosition { isTop, isBottom in
                    if vertical == verticalIndex && horizontal == horizontalIndex {
                        handleScrollPosition(isTop: isTop, isBottom: isBottom)
                    }
                }
        case (0, 1):
            MomentsFeedViewWrapper(client: client, onScrollPosition: { isTop, isBottom in
                if vertical == verticalIndex && horizontal == horizontalIndex {
                    handleScrollPosition(isTop: isTop, isBottom: isBottom)
                }
            })
        case (0, 2):
            PersonalizationView(client: client)
                .onScrollPosition { isTop, isBottom in
                    if vertical == verticalIndex && horizontal == horizontalIndex {
                        handleScrollPosition(isTop: isTop, isBottom: isBottom)
                    }
                }
        
        // 第二层：Connections（仅中央）
        case (1, 1):
            ConnectionsFeedViewWrapper(client: client, onScrollPosition: { isTop, isBottom in
                if vertical == verticalIndex && horizontal == horizontalIndex {
                    handleScrollPosition(isTop: isTop, isBottom: isBottom)
                }
            })
        
        // 第三层：Channels + Contacts（仅中央）
        case (2, 1):
            ChannelsContactsTabView(client: client)
                .onScrollPosition { isTop, isBottom in
                    if vertical == verticalIndex && horizontal == horizontalIndex {
                        handleScrollPosition(isTop: isTop, isBottom: isBottom)
                    }
                }
        
        default:
            EmptyView()
        }
    }
    
    // MARK: - 背景渐变
    
    private var currentGradient: LinearGradient {
        switch (verticalIndex, horizontalIndex) {
        case (0, 1): return ModernTheme.momentsMemoriesGradient
        case (0, 0): return ModernTheme.twilightGradient  // Explorer 使用 twilight
        case (0, 2): return ModernTheme.dawnGradient
        case (1, 1): return ModernTheme.twilightGradient  // Connections
        case (2, 1): return ModernTheme.meadowGradient  // Channels
        default: return ModernTheme.dawnGradient
        }
    }
    
    // MARK: - 边缘导航提示
    
    private var edgeNavigationHints: some View {
        ZStack {
            // 顶部下拉提示
            if verticalIndex < 2 && isScrolledToTop && horizontalIndex == 1 {
                VStack {
                    TopPullHint(nextLevel: nextVerticalLevel)
                        .padding(.top, shouldShowHeader ? 60 : 50)
                    Spacer()
                }
            }
            
            // 底部上滑提示（双指）
            if verticalIndex > 0 && isScrolledToBottom && horizontalIndex == 1 {
                VStack {
                    Spacer()
                    BottomPushHint(prevLevel: previousVerticalLevel)
                        .padding(.bottom, 30)
                }
            }
            
            // 左右滑动提示（仅在 Home 层）
            if verticalIndex == 0 {
                HStack {
                    if horizontalIndex > 0 {
                        LeftSwipeHint()
                            .padding(.leading, 8)
                    }
                    Spacer()
                    if horizontalIndex < 2 {
                        RightSwipeHint()
                            .padding(.trailing, 8)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private var nextVerticalLevel: String {
        ["Connections", "Channels", "Moments Feed"][verticalIndex + 1 < 3 ? verticalIndex + 1 : 0]
    }
    
    private var previousVerticalLevel: String {
        ["Moments Feed", "Connections", "Channels"][verticalIndex - 1 >= 0 ? verticalIndex - 1 : 2]
    }
    
    // MARK: - 中央位置指示器
    
    private var centralPositionIndicator: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 12) {
                // 垂直位置
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i == verticalIndex ? Color.blue : Color.white.opacity(0.4))
                            .frame(width: 8, height: 8)
                            .scaleEffect(i == verticalIndex ? 1.2 : 1.0)
                    }
                }
                
                // 水平位置（仅在 Home 层显示）
                if verticalIndex == 0 {
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { i in
                            Capsule()
                                .fill(i == horizontalIndex ? Color.blue : Color.white.opacity(0.4))
                                .frame(width: 20, height: 4)
                                .scaleEffect(i == horizontalIndex ? 1.1 : 1.0)
                        }
                    }
                }
                
                // 位置名称
                Text(currentPositionName)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            )
            .padding(.bottom, 40)
        }
        .allowsHitTesting(false)
    }
    
    private var currentPositionName: String {
        if verticalIndex == 0 {
            return ["Explorer", "Moments Feed", "Personal"][horizontalIndex]
        } else {
            return ["Moments Feed", "Connections", "Channels"][verticalIndex]
        }
    }
    
    // MARK: - 手势处理
    
    private var navigationGesture: some Gesture {
        DragGesture(minimumDistance: 20)  // 降低阈值，参考 MomentsHomeView 的 18
            .onChanged { value in
                handleDragChanged(value)
            }
            .onEnded { value in
                handleDragEnded(value)
            }
    }
    
    private var transitionEdge: Edge {
        // 使用记录的最后过渡方向，而不是当前的 dragOffset
        return lastTransitionDirection
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        guard !isTransitioning else {
            dragOffset = .zero
            return
        }
        
        let translation = value.translation
        let isVerticalGesture = abs(translation.height) > abs(translation.width)
        let isHorizontalGesture = abs(translation.width) > abs(translation.height)
        
        // 垂直手势（仅在中央列且在顶部）
        if isVerticalGesture && horizontalIndex == 1 && isScrolledToTop {
            guard translation.height > 20 else {
                dragOffset = .zero
                return
            }
            // ✨ 更线性的拖动，更跟手
            let dampingFactor: CGFloat = 0.8  // 从 0.5 提高到 0.8
            let maxDrag: CGFloat = UIScreen.main.bounds.height * 0.5  // 最多拖动半屏
            dragOffset = CGSize(width: 0, height: min(translation.height * dampingFactor, maxDrag))
        }
        // 水平手势（仅在第0层）
        else if isHorizontalGesture && verticalIndex == 0 {
            guard abs(translation.width) > 20 else {
                dragOffset = .zero
                return
            }
            // ✨ 更线性的拖动，更跟手
            let dampingFactor: CGFloat = 0.7  // 从 0.4 提高到 0.7
            let maxDrag: CGFloat = UIScreen.main.bounds.width * 0.6  // 最多拖动 60% 屏宽
            dragOffset = CGSize(width: min(abs(translation.width) * dampingFactor, maxDrag) * (translation.width > 0 ? 1 : -1), height: 0)
        }
        else {
            dragOffset = .zero
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        let threshold: CGFloat = 150  // 🔧 提高阈值：从 100 到 150
        isTransitioning = true
        
        let isVerticalGesture = abs(value.translation.height) > abs(value.translation.width)
        let isHorizontalGesture = abs(value.translation.width) > abs(value.translation.height)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            // 垂直导航
            if isVerticalGesture && horizontalIndex == 1 {
                if value.translation.height > threshold && isScrolledToTop {
                    // ✅ 顶部下拉 - 新视图从上方滑入（跟随手指向下的动作）
                    lastTransitionDirection = .top
                    verticalIndex = (verticalIndex + 1) % 3
                    impactMedium.impactOccurred()
                    flashPositionIndicator()
                }
                // 底部双指上滑 - 暂时禁用
                /*
                else if value.translation.height < -threshold && isScrolledToBottom {
                    lastTransitionDirection = .top
                    verticalIndex = (verticalIndex - 1 + 3) % 3
                    impactMedium.impactOccurred()
                    flashPositionIndicator()
                }
                */
            }
            // 水平导航
            else if isHorizontalGesture && verticalIndex == 0 {
                if value.translation.width < -threshold {
                    // 左滑（手指向左） - 新视图从右侧滑入
                    lastTransitionDirection = .trailing
                    horizontalIndex = (horizontalIndex + 1) % 3
                    impactHeavy.impactOccurred()
                    flashPositionIndicator()
                } else if value.translation.width > threshold {
                    // 右滑（手指向右） - 新视图从左侧滑入
                    lastTransitionDirection = .leading
                    horizontalIndex = (horizontalIndex - 1 + 3) % 3
                    impactHeavy.impactOccurred()
                    flashPositionIndicator()
                }
            }
            
            dragOffset = .zero
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isTransitioning = false
        }
    }
    
    // MARK: - 辅助方法
    
    private func oppositeEdge(of edge: Edge) -> Edge {
        switch edge {
        case .top: return .bottom
        case .bottom: return .top
        case .leading: return .trailing
        case .trailing: return .leading
        }
    }
    
    private func handleScrollPosition(isTop: Bool, isBottom: Bool) {
        isScrolledToTop = isTop
        isScrolledToBottom = isBottom
        
        // 🐛 调试：打印滚动状态
        print("📜 滚动位置更新: isTop=\(isTop), isBottom=\(isBottom)")
        
        // 在边缘时显示提示
        if isTop || isBottom {
            showEdgeHints = true
            autoHideEdgeHints()
        }
    }
    
    private func setupInitialState() {
        // 短暂显示位置指示器
        showCentralIndicator = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCentralIndicator = false
            }
        }
        
        // 3秒后自动隐藏边缘提示
        autoHideEdgeHints()
    }
    
    private func autoHideEdgeHints() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation {
                showEdgeHints = false
            }
        }
    }
    
    private func flashPositionIndicator() {
        showCentralIndicator = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation {
                showCentralIndicator = false
            }
        }
    }
}

// MARK: - 边缘提示组件

/// 顶部下拉提示
struct TopPullHint: View {
    let nextLevel: String
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chevron.down")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .offset(y: isAnimating ? 3 : -3)
            
            Text("下拉到 \(nextLevel)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
}

/// 底部上滑提示
struct BottomPushHint: View {
    let prevLevel: String
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 8) {
            Text("双指上滑返回 \(prevLevel)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
            
            HStack(spacing: 4) {
                Image(systemName: "hand.point.up.fill")
                    .font(.system(size: 12))
                Image(systemName: "hand.point.up.fill")
                    .font(.system(size: 12))
            }
            .foregroundColor(.white.opacity(0.6))
            .offset(y: isAnimating ? -3 : 3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
}

/// 左滑提示
struct LeftSwipeHint: View {
    @State private var isAnimating = false
    
    var body: some View {
        Image(systemName: "chevron.left")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white.opacity(0.4))
            .padding(12)
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
            )
            .offset(x: isAnimating ? -4 : 0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
                }
            }
    }
}

/// 右滑提示
struct RightSwipeHint: View {
    @State private var isAnimating = false
    
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white.opacity(0.4))
            .padding(12)
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
            )
            .offset(x: isAnimating ? 4 : 0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - 滚动位置检测扩展

extension View {
    func onScrollPosition(perform action: @escaping (Bool, Bool) -> Void) -> some View {
        self.modifier(ScrollPositionMonitor(onChange: action))
    }
}

struct ScrollPositionMonitor: ViewModifier {
    let onChange: (Bool, Bool) -> Void
    @State private var scrollOffset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: GestureNavScrollOffsetKey.self,
                        value: geometry.frame(in: .named("scroll")).minY
                    )
                }
            )
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(GestureNavScrollOffsetKey.self) { value in
                scrollOffset = value
                let isTop = value >= -10
                let isBottom = false  // 简化实现，可后续优化
                onChange(isTop, isBottom)
            }
    }
}

struct GestureNavScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - View Wrappers

/// MomentsFeedView 包装器 - 独立使用，不依赖 MomentsHomeView
private struct MomentsFeedViewWrapper: View {
    let client: HackChatClient
    @State private var isAtTop: Bool = true
    @State private var externalDragOffset: CGFloat = 0
    private let triggerDistance: CGFloat = 200
    let onScrollPosition: (Bool, Bool) -> Void
    
    var body: some View {
        // ✨ 直接使用 MomentsHomeView 中的 MomentsFeedView
        MomentsFeedView(
            client: client,
            isAtTop: $isAtTop,
            externalDragOffset: $externalDragOffset,
            triggerDistance: triggerDistance
        )
        .onChange(of: isAtTop) { oldValue, newValue in
            // 🐛 调试
            print("📜 MomentsFeedView 滚动状态变化: isAtTop=\(newValue)")
            onScrollPosition(newValue, false)
        }
    }
}

/// ConnectionsFeedView 包装器 - 独立使用
private struct ConnectionsFeedViewWrapper: View {
    let client: HackChatClient
    @State private var isAtTop: Bool = true
    @State private var externalDragOffset: CGFloat = 0
    private let triggerDistance: CGFloat = 200
    let onScrollPosition: (Bool, Bool) -> Void
    
    var body: some View {
        // ✨ 直接使用 MomentsHomeView 中的 ConnectionsFeedView
        ConnectionsFeedView(
            client: client,
            isAtTop: $isAtTop,
            externalDragOffset: $externalDragOffset,
            triggerDistance: triggerDistance
        )
        .onChange(of: isAtTop) { oldValue, newValue in
            // 🐛 调试
            print("📜 ConnectionsFeedView 滚动状态变化: isAtTop=\(newValue)")
            onScrollPosition(newValue, false)
        }
    }
}

