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
    @State private var isScrolledToTop = true   // ✅ 初始在顶部
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
        // ✨ 保留双画面衔接，去掉淡出效果
        ZStack {
            let screenHeight = UIScreen.main.bounds.height
            let screenWidth = UIScreen.main.bounds.width
            
            // 垂直拖动时
            if abs(dragOffset.height) > 10 && dragOffset.height > 0 {
                let nextV = (verticalIndex + 1) % 3
                
                // ✨ 当前视图 - 跟随手指向下移动（无淡出）
                viewForPosition(vertical: verticalIndex, horizontal: horizontalIndex)
                    .offset(y: dragOffset.height)
                    .zIndex(1)
                
                // 下一个视图 - 从上方跟随进入
                viewForPosition(vertical: nextV, horizontal: horizontalIndex)
                    .offset(y: -screenHeight + dragOffset.height)
                    .zIndex(0)
            }
            // 水平拖动时
            else if abs(dragOffset.width) > 10 {
                // ✨ 智能计算目标位置（考虑行1/2会回到行0）
                let targetV = verticalIndex == 0 ? 0 : 0  // 行1/2都回到行0
                let targetH = dragOffset.width < 0 ? (horizontalIndex + 1) % 3 : (horizontalIndex - 1 + 3) % 3
                
                // ✨ 当前视图 - 跟随手指移动（无淡出）
                viewForPosition(vertical: verticalIndex, horizontal: horizontalIndex)
                    .offset(x: dragOffset.width)
                    .zIndex(1)
                
                // 目标视图 - 从对应方向跟随进入
                viewForPosition(vertical: targetV, horizontal: targetH)
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
    
    /// 计算淡出透明度（拖动越远，越淡）
    private func calculateFadeOutOpacity(for offset: CGFloat, max maxOffset: CGFloat) -> Double {
        let progress = min(offset / maxOffset, 1.0)  // 0.0 ~ 1.0
        return 1.0 - (progress * 0.3)  // 最多淡出到 0.7（保持低调）
    }
    
    @ViewBuilder
    private func viewForPosition(vertical: Int, horizontal: Int) -> some View {
        switch (vertical, horizontal) {
        // ========== 行0：多样化层 ==========
        case (0, 0):  // Explorer
            ExplorerView(client: client)
                .onScrollPosition { isTop, isBottom in
                    if vertical == verticalIndex && horizontal == horizontalIndex {
                        handleScrollPosition(isTop: isTop, isBottom: isBottom)
                    }
                }
        case (0, 1):  // Moments
            MomentsFeedViewWrapper(client: client, onScrollPosition: { isTop, isBottom in
                if vertical == verticalIndex && horizontal == horizontalIndex {
                    handleScrollPosition(isTop: isTop, isBottom: isBottom)
                }
            })
        case (0, 2):  // Personal
            PersonalizationView(client: client)
                .onScrollPosition { isTop, isBottom in
                    if vertical == verticalIndex && horizontal == horizontalIndex {
                        handleScrollPosition(isTop: isTop, isBottom: isBottom)
                    }
                }
        
        // ========== 行1：Connections 层（所有列）==========
        case (1, 0), (1, 1), (1, 2):
            ConnectionsFeedViewWrapper(client: client, onScrollPosition: { isTop, isBottom in
                if vertical == verticalIndex && horizontal == horizontalIndex {
                    handleScrollPosition(isTop: isTop, isBottom: isBottom)
                }
            })
        
        // ========== 行2：Channels 层（所有列）==========
        case (2, 0), (2, 1), (2, 2):
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
                    .fill(Color.black.opacity(0.6))  // ✨ 淡黑色背景，更醒目
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
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
        DragGesture(minimumDistance: 25)  // 提高最小距离：20 → 25，避免误触
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
        
        // ✨ 全方位垂直手势（所有列都支持）
        if isVerticalGesture && translation.height > 30 && isScrolledToTop {
            let dampingFactor: CGFloat = 0.85  // 提高阻尼：0.75 → 0.85（更跟手）
            let maxDrag: CGFloat = UIScreen.main.bounds.height * 0.5  // 提高上限：0.45 → 0.5（更自由）
            
            // ✨ 使用更平滑的弹性阻尼曲线
            let elasticDamping = calculateSmoothElasticDamping(offset: translation.height, max: maxDrag)
            dragOffset = CGSize(width: 0, height: min(translation.height * dampingFactor * elasticDamping, maxDrag))
        }
        // ✨ 全方位水平手势（所有行都支持）
        else if isHorizontalGesture && abs(translation.width) > 30 {
            let dampingFactor: CGFloat = 0.75  // 提高阻尼：0.65 → 0.75（更跟手）
            let maxDrag: CGFloat = UIScreen.main.bounds.width * 0.6  // 提高上限：0.55 → 0.6（更自由）
            
            // ✨ 使用更平滑的弹性阻尼曲线
            let elasticDamping = calculateSmoothElasticDamping(offset: abs(translation.width), max: maxDrag)
            dragOffset = CGSize(width: min(abs(translation.width) * dampingFactor * elasticDamping, maxDrag) * (translation.width > 0 ? 1 : -1), height: 0)
        }
        else {
            dragOffset = .zero
        }
    }
    
    /// 计算平滑弹性阻尼（更平滑的曲线，减少抖动）
    private func calculateSmoothElasticDamping(offset: CGFloat, max maxOffset: CGFloat) -> CGFloat {
        let progress = min(offset / maxOffset, 1.0)
        // ✨ 使用三次贝塞尔曲线，创造更平滑的阻尼感
        // easeOut 曲线：快速开始，平滑结束
        let easeOut = 1.0 - pow(1.0 - progress, 3.0)
        // 阻尼范围：1.0 → 0.8（更温和的阻尼）
        return 1.0 - (easeOut * 0.2)
    }
    
    /// 计算弹性阻尼（越接近上限，阻尼越大，产生回弹感）
    private func calculateElasticDamping(offset: CGFloat, max maxOffset: CGFloat) -> CGFloat {
        let progress = min(offset / maxOffset, 1.0)
        // 使用二次函数创造越拖越难的感觉
        return 1.0 - (progress * progress * 0.3)  // 阻尼范围：1.0 → 0.7
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        let threshold: CGFloat = 180  // 🔧 提高阈值：150 → 180，更慎重的切换
        isTransitioning = true
        
        let isVerticalGesture = abs(value.translation.height) > abs(value.translation.width)
        let isHorizontalGesture = abs(value.translation.width) > abs(value.translation.height)
        
        // 判断是否需要切换
        let willSwitch = (isVerticalGesture && value.translation.height > threshold && isScrolledToTop) ||
                        (isHorizontalGesture && abs(value.translation.width) > threshold)
        
        // ✨ 根据是否切换选择不同的动画
        let animation: Animation = willSwitch ?
            // 切换动画：快速响应
            .spring(
                response: 0.4,
                dampingFraction: 0.82,
                blendDuration: 0.1
            ) :
            // 回弹动画：仿微信丝滑效果 ✨
            .interpolatingSpring(
                mass: 1.0,           // 质量
                stiffness: 150,      // 刚度降低：200 → 150（更柔和）
                damping: 18,         // 阻尼降低：20 → 18（更平滑）
                initialVelocity: 0   // 初始速度
            )
        
        // ✨ 使用 transaction 确保动画不被打断
        var transaction = Transaction(animation: animation)
        transaction.disablesAnimations = false
        transaction.isContinuous = false
        
        withTransaction(transaction) {
            // ✨ 全方位垂直导航
            if isVerticalGesture && value.translation.height > threshold && isScrolledToTop {
                // ✅ 顶部下拉 - 切换到下一行
                lastTransitionDirection = .top
                verticalIndex = (verticalIndex + 1) % 3
                impactMedium.impactOccurred()
                flashPositionIndicator()
                print("🔄 垂直切换: (\(verticalIndex), \(horizontalIndex))")
            }
            
            // ✨ 水平导航
            if isHorizontalGesture && abs(value.translation.width) > threshold {
                if verticalIndex == 0 {
                    // 行0：正常水平切换
                    if value.translation.width < 0 {
                        lastTransitionDirection = .trailing
                        horizontalIndex = (horizontalIndex + 1) % 3
                    } else {
                        lastTransitionDirection = .leading
                        horizontalIndex = (horizontalIndex - 1 + 3) % 3
                    }
                } else {
                    // 行1/2：水平滑动回到行0的对应列
                    lastTransitionDirection = value.translation.width < 0 ? .trailing : .leading
                    verticalIndex = 0  // 回到行0
                    if value.translation.width < 0 {
                        // 左滑：下一列
                        horizontalIndex = (horizontalIndex + 1) % 3
                    } else {
                        // 右滑：上一列
                        horizontalIndex = (horizontalIndex - 1 + 3) % 3
                    }
                }
                impactHeavy.impactOccurred()
                flashPositionIndicator()
                print("🔄 水平切换: (\(verticalIndex), \(horizontalIndex))")
            }
            
            dragOffset = .zero
        }
        
        // ✨ 根据动画类型调整状态重置时间
        let resetDelay = willSwitch ? 0.5 : 0.75  // 回弹动画需要更长时间
        DispatchQueue.main.asyncAfter(deadline: .now() + resetDelay) {
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
        // ✅ 确保初始滚动状态正确（启动时在顶部）
        isScrolledToTop = true
        isScrolledToBottom = false
        
        print("🚀 初始化导航状态: isScrolledToTop=\(isScrolledToTop)")
        
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

