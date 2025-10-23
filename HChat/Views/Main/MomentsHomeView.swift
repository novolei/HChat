//
//  MomentsHomeView.swift
//  HChat
//
//  Created by AI Assistant on 2025/10/22.
//  ✨ 首页：Encrypted Moments 记忆流 + 聊天摘要，下拉分页切换
//

import SwiftUI
import UIKit

struct MomentsHomeView: View {
    var client: HackChatClient
    
    @State private var selectedPage: MomentsPage = .memories
    @State private var dragOffset: CGFloat = 0
    @State private var memoriesAtTop: Bool = true
    @State private var connectionsAtTop: Bool = true
    
    private let triggerDistance: CGFloat = 200

    var body: some View {
        ZStack(alignment: .top) {
            background(for: selectedPage)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                header(topInset: 0)
                pager(topInset: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .simultaneousGesture(dragGesture())
    }
    
    private func background(for page: MomentsPage) -> LinearGradient {
        switch page {
        case .memories: return ModernTheme.momentsMemoriesGradient
        case .connections: return ModernTheme.twilightGradient
        }
    }
    
    private func pager(topInset: CGFloat) -> some View {
        ZStack {
            if selectedPage == .memories {
                MomentsFeedView(
                    client: client,
                    isAtTop: $memoriesAtTop,
                    externalDragOffset: $dragOffset,
                    triggerDistance: triggerDistance
                )
                .transition(pagerTransition)
            }
            if selectedPage == .connections {
                ConnectionsFeedView(
                    client: client,
                    isAtTop: $connectionsAtTop,
                    externalDragOffset: $dragOffset,
                    triggerDistance: triggerDistance
                )
                .transition(pagerTransition)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: selectedPage)
    }
    
    private var pagerTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }
    
    private var canDragCurrentPage: Bool {
        switch selectedPage {
        case .memories: return memoriesAtTop
        case .connections: return connectionsAtTop
        }
    }
    
    private func dragGesture() -> some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                guard canDragCurrentPage else {
                    dragOffset = 0
                    return
                }
                let translation = value.translation.height
                guard translation > 18 else {
                    dragOffset = 0
                    return
                }
                dragOffset = min(translation - 18, triggerDistance + 80)
            }
            .onEnded { value in
                defer { dragOffset = 0 }
                guard canDragCurrentPage else { return }
                let translation = value.translation.height
                guard translation > triggerDistance else { return }
                HapticManager.impact(style: .medium)
                withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                    selectedPage = selectedPage.toggle()
                }
                HapticManager.notification(type: .success)
            }
    }
    
    private func header(topInset: CGFloat) -> some View {
        VStack(spacing: ModernTheme.spacing1) {
            Text(selectedPage.title)
                .font(ModernTheme.title2)
                .foregroundColor(.white)
            PageIndicator(selected: selectedPage)
        }
        .frame(maxWidth: .infinity)
//        .padding(.top, max(0, 0))
        .padding(.bottom, ModernTheme.spacing1)
    }
}

private enum MomentsPage: CaseIterable {
    case memories
    case connections
    
    var gradient: LinearGradient {
        switch self {
        case .memories: return ModernTheme.dawnGradient
        case .connections: return ModernTheme.twilightGradient
        }
    }
    
    var pullHint: String? {
        switch self {
        case .memories: return "下拉查看聊天 & 收藏"
        case .connections: return "下拉返回记忆流"
        }
    }
    
    var title: String {
        switch self {
        case .memories: return "记忆流"
        case .connections: return "聊天记录"
        }
    }
    
    func toggle() -> MomentsPage {
        switch self {
        case .memories: return .connections
        case .connections: return .memories
        }
    }
}

private struct PageIndicator: View {
    let selected: MomentsPage
    
    var body: some View {
        HStack(spacing: ModernTheme.spacing3) {
            ForEach(MomentsPage.allCases.indices, id: \.self) { index in
                let page = MomentsPage.allCases[index]
                Capsule()
                    .fill(page == selected ? Color.white.opacity(0.9) : Color.white.opacity(0.3))
                    .frame(width: page == selected ? 26 : 12, height: 6)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.75), value: selected)
    }
}

private struct HintView: View {
    let text: String
    let icon: String
    
    var body: some View {
        HStack(spacing: ModernTheme.spacing2) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(text)
                .font(ModernTheme.caption)
        }
        .foregroundColor(.white.opacity(0.9))
        .padding(.horizontal, ModernTheme.spacing4)
        .padding(.vertical, ModernTheme.spacing2)
        .background(Color.white.opacity(0.12))
        .clipShape(Capsule(style: .continuous))
    }
}

/// ✨ Moments 记忆流视图 - 可被外部导航容器复用
struct MomentsFeedView: View {
    var client: HackChatClient
    @Binding var isAtTop: Bool
    @Binding var externalDragOffset: CGFloat
    var triggerDistance: CGFloat

    @State private var selectedEmotion: EmotionTag? = nil
    @State private var showAllMoments = false
    @State private var isPresentingCapture = false

    private var moments: [MemoryMoment] { MemoryMoment.sampleMoments }
    private var filteredMoments: [MemoryMoment] {
        guard let selectedEmotion else { return moments }
        return moments.filter { $0.emotion == selectedEmotion }
    }

    private var quickActions: [(title: String, icon: String, gradient: LinearGradient, action: () -> Void)] {
        [
            ("文字", "quote.bubble", ModernTheme.dawnGradient, { isPresentingCapture = true }),
            ("照片", "camera.fill", ModernTheme.duskGradient, { isPresentingCapture = true }),
            ("语音", "mic.fill", ModernTheme.twilightGradient, { isPresentingCapture = true })
        ]
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: ModernTheme.spacing5) {
                header
                suggestionSection
                quickCaptureSection
                memoryStreamSection
                chatSummarySection
            }
            .padding(.horizontal, ModernTheme.spacing4)
            .padding(.top, ModernTheme.spacing4)
            .padding(.bottom, ModernTheme.spacing6)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .named("momentsScroll")).minY)
                }
            )
        }
        .coordinateSpace(name: "momentsScroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            isAtTop = value >= -1
        }
        .scrollDismissesKeyboardIfAvailable()
        .background(Color.clear)
        .simultaneousGesture(DragGesture().onChanged { value in
            if value.translation.height < 0 { externalDragOffset = 0 }
        })
        .sheet(isPresented: $isPresentingCapture) {
            MomentsCapturePlaceholderView()
                .presentationDetents([.medium, .large])
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: ModernTheme.spacing3) {
            HStack(spacing: ModernTheme.spacing2) {
                if isAtTop && externalDragOffset > 0 {
                    HintView(text: "下拉查看聊天 & 收藏", icon: "chevron.down")
                        .opacity(Double(max(0.2, 1 - externalDragOffset / triggerDistance)))
                        .transition(.opacity)
                }
                Spacer()
            }

            Text(greetingTitle)
                .font(ModernTheme.title1)
                .foregroundColor(.white)
                .padding(.top, isAtTop && externalDragOffset > 0 ? ModernTheme.spacing1 : 0)

            Text("今天想记录些什么只属于你们的小瞬间？")
                .font(ModernTheme.subheadline)
                .foregroundColor(Color.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeOut(duration: 0.2), value: externalDragOffset)
    }
    
    private var suggestionSection: some View {
        VStack(alignment: .leading, spacing: ModernTheme.spacing3) {
            Text("情绪标签")
                .font(ModernTheme.title3)
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ModernTheme.spacing3) {
                    emotionChip(for: nil)
                    ForEach(EmotionTag.allCases) { emotion in
                        emotionChip(for: emotion)
                    }
                }
            }
        }
    }
    
    private func emotionChip(for emotion: EmotionTag?) -> some View {
        Button {
            withAnimation(ModernTheme.standardAnimation) {
                selectedEmotion = selectedEmotion == emotion ? nil : emotion
            }
        } label: {
            HStack(spacing: ModernTheme.spacing2) {
                Image(systemName: emotion?.icon ?? "sparkles")
                Text(emotion?.displayName ?? "全部")
                    .fontWeight(.medium)
            }
            .font(ModernTheme.caption)
            .foregroundColor(selectedEmotion == emotion ? .white : Color.white.opacity(0.7))
            .padding(.horizontal, ModernTheme.spacing4)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(selectedEmotion == emotion ? Color.white.opacity(0.32) : Color.white.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }
    
    private var quickCaptureSection: some View {
        VStack(alignment: .leading, spacing: ModernTheme.spacing3) {
            Text("快速捕捉")
                .font(ModernTheme.title3)
                .foregroundColor(.white)
            
            HStack(spacing: ModernTheme.spacing4) {
                ForEach(quickActions, id: \.title) { item in
                    QuickCaptureButton(title: item.title, icon: item.icon, gradient: item.gradient) {
                        item.action()
                    }
                }
            }
        }
    }
    
    private var memoryStreamSection: some View {
        VStack(alignment: .leading, spacing: ModernTheme.spacing3) {
            HStack {
                Text("记忆流")
                    .font(ModernTheme.title3)
                    .foregroundColor(.white)
                Spacer()
                Button {
                    showAllMoments.toggle()
                } label: {
                    Text("查看全部")
                        .font(ModernTheme.caption)
                        .foregroundColor(Color.white.opacity(0.85))
                }
                .buttonStyle(.plain)
            }
            
            LazyVStack(spacing: ModernTheme.spacing4) {
                ForEach(filteredMoments) { moment in
                    MemoryMomentCard(moment: moment) {}
                }
            }
        }
    }
    
    private var chatSummarySection: some View {
        VStack(alignment: .leading, spacing: ModernTheme.spacing3) {
            Text("聊天摘要")
                .font(ModernTheme.title3)
                .foregroundColor(.white)
            
            VStack(spacing: ModernTheme.spacing3) {
                SummaryRow(icon: "bubble.left.and.bubble.right.fill", title: "未完的话题", detail: "还有 2 条消息待回复")
                SummaryRow(icon: "heart.text.square.fill", title: "情绪指数", detail: "今日情绪波动稳定，传递了 3 次正反馈")
                SummaryRow(icon: "clock.badge.checkmark", title: "限时回顾", detail: "今天 19:30 解锁")
            }
            .modernCard(padding: ModernTheme.spacing4, backgroundColor: Color.white.opacity(0.16), shadowRadius: 10, blurRadius: 16, borderGradient: ModernTheme.cardGradient)
        }
    }
    
    private var greetingTitle: String {
        let nick = client.myNick
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String
        switch hour {
        case 5..<12: greeting = "早安"
        case 12..<18: greeting = "午后"
        case 18..<23: greeting = "夜晚"
        default: greeting = "凌晨"
        }
        return "你好，\(nick)。祝你们\(greeting)温柔。"
    }
}

/// ✨ Connections 聊天记录视图 - 可被外部导航容器复用
struct ConnectionsFeedView: View {
    var client: HackChatClient
    @Binding var isAtTop: Bool
    @Binding var externalDragOffset: CGFloat
    var triggerDistance: CGFloat

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: ModernTheme.spacing4) {
                header
                listContent
            }
            .padding(.horizontal, ModernTheme.spacing4)
            .padding(.top, ModernTheme.spacing4)
            .padding(.bottom, ModernTheme.spacing6)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .named("connectionsScroll")).minY)
                }
            )
        }
        .coordinateSpace(name: "connectionsScroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            isAtTop = value >= -1
        }
        .scrollDismissesKeyboardIfAvailable()
        .background(Color.clear)
        .simultaneousGesture(DragGesture().onChanged { value in
            if value.translation.height < 0 { externalDragOffset = 0 }
        })
    }

    private var header: some View {
        HStack(spacing: ModernTheme.spacing2) {
            if isAtTop && externalDragOffset > 0 {
                HintView(text: "下拉返回记忆流", icon: "chevron.down")
                    .opacity(Double(max(0.2, 1 - externalDragOffset / triggerDistance)))
                    .transition(.opacity)
            }
            Spacer()
        }
        .animation(.easeOut(duration: 0.2), value: externalDragOffset)
    }

    @ViewBuilder
    private var listContent: some View {
        Text("聊天记录")
            .font(ModernTheme.title3)
            .foregroundColor(.white)

        LazyVStack(spacing: ModernTheme.spacing3) {
            ForEach(ChatPreview.sampleChats) { preview in
                ChatPreviewRow(preview: preview) {
                    NotificationCenter.default.post(name: Notification.Name("NavigateToChatView"), object: preview.channel)
                }
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: ModernTheme.largeRadius, style: .continuous))
            }
        }

        Text("收藏联系人")
            .font(ModernTheme.title3)
            .foregroundColor(.white)
            .padding(.top, ModernTheme.spacing4)

        LazyVGrid(columns: columns, spacing: ModernTheme.spacing3) {
            ForEach(FavoriteContact.sampleContacts) { contact in
                FavoriteContactRow(contact: contact) {
                    client.sendText("/join pm-\(contact.name)")
                }
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: ModernTheme.largeRadius, style: .continuous))
            }
        }
    }
}

private struct SummaryRow: View {
    let icon: String
    let title: String
    let detail: String
    
    var body: some View {
        HStack(spacing: ModernTheme.spacing4) {
            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: icon)
                        .foregroundColor(.white)
                        .font(.system(size: 20, weight: .semibold))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ModernTheme.bodyBold)
                    .foregroundColor(.white)
                Text(detail)
                    .font(ModernTheme.caption)
                    .foregroundColor(Color.white.opacity(0.72))
            }
            Spacer()
        }
    }
}

private struct MomentsCapturePlaceholderView: View {
    var body: some View {
        VStack(spacing: ModernTheme.spacing6) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(ModernTheme.accent)
            Text("捕捉新记忆")
                .font(ModernTheme.title2)
                .foregroundColor(ModernTheme.primaryText)
            Text("这里将来会整合文本、照片和语音的捕捉器，全部本地加密存储。")
                .font(ModernTheme.body)
                .foregroundColor(ModernTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ModernTheme.spacing6)
            Button {
                // TODO: 实现捕捉逻辑
            } label: {
                Text("即将上线")
                    .font(ModernTheme.bodyBold)
                    .foregroundColor(.white)
                    .padding(.horizontal, ModernTheme.spacing6)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(ModernTheme.accent)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ModernTheme.backgroundGradient)
    }
}

// MARK: - Scroll Helpers

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
