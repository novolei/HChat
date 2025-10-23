import SwiftUI

// MARK: - 消息反应浮层系统
//
// 核心架构：
// 1. MessageOverlayState: 集中管理浮层状态和计算
// 2. MessageOverlayContainer: 包装消息列表，提供浮层渲染容器
// 3. ReactionOverlayView: 实际的浮层UI，包含半透明背景和反应栏
// 4. ReactionBarView: 可横向滚动的表情选择栏
//
// 用户交互流程：
// 1. 长按消息 → MessageRowView 触发 onLongPress
// 2. MessageOverlayState 收集消息位置信息
// 3. MessageOverlayMetrics 计算浮层位置（防止超出屏幕）
// 4. ReactionOverlayView 渲染浮层和反应栏
// 5. 用户选择表情或点击外部区域关闭
//
// 性能优化：
// - 使用 PreferenceKey 高效传递几何信息
// - 惰性计算浮层位置，仅在需要时触发
// - 反应栏支持横向滚动显示所有表情

private enum ReactionBarLayout {
  static let maxEmoji = 6
  static let emojiDiameter: CGFloat = 36
  static let emojiFont: CGFloat = 24
  static let spacing: CGFloat = 10
  static let plusGap: CGFloat = 14
  static let plusDiameter: CGFloat = 34
  static let horizontalPadding: CGFloat = 18
  static let verticalPadding: CGFloat = 12

  static var barHeight: CGFloat { emojiDiameter + verticalPadding * 2 }

  static var barWidth: CGFloat {
    let count = min(QuickReactions.defaults.count, maxEmoji)
    let emojiBlock = CGFloat(count) * emojiDiameter
    let gapTotal = CGFloat(max(count - 1, 0)) * spacing
    return emojiBlock + gapTotal + plusGap + plusDiameter + horizontalPadding * 2
  }
}

struct MessageAnchorInfo: Equatable {
  var frameInScroll: CGRect
  var globalFrame: CGRect
  var isMine: Bool
}

struct MessageFramePreferenceKey: PreferenceKey {
  static var defaultValue: [String: MessageAnchorInfo] = [:]
  static func reduce(value: inout [String: MessageAnchorInfo], nextValue: () -> [String: MessageAnchorInfo]) {
    value.merge(nextValue()) { $1 }
  }
}

struct ScrollViewFramePreferenceKey: PreferenceKey {
  static var defaultValue: CGRect = .zero
  static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
    value = nextValue()
  }
}

@Observable
final class MessageOverlayState {
  var highlightedMessageID: String? = nil
  private(set) var anchors: [String: MessageAnchorInfo] = [:]
  private(set) var scrollFrame: CGRect = .zero
  private(set) var metrics: MessageOverlayMetrics? = nil

  private let messageProvider: () -> [ChatMessage]
  private let reactionHandler: (String, ChatMessage) -> Void
  private let moreReactionHandler: (ChatMessage) -> Void

  init(
    messageProvider: @escaping () -> [ChatMessage],
    reactionHandler: @escaping (String, ChatMessage) -> Void,
    moreReactionHandler: @escaping (ChatMessage) -> Void
  ) {
    self.messageProvider = messageProvider
    self.reactionHandler = reactionHandler
    self.moreReactionHandler = moreReactionHandler
  }

  func updateAnchors(_ anchors: [String: MessageAnchorInfo]) {
    self.anchors.merge(anchors) { $1 }
    recalc()
  }

  func updateScrollFrame(_ frame: CGRect) {
    scrollFrame = frame
    recalc()
  }

  func presentOverlay(for messageID: String) {
    highlightedMessageID = messageID
    recalc()
  }

  func dismiss() {
    highlightedMessageID = nil
    metrics = nil
  }

  private func recalc() {
    guard let id = highlightedMessageID, let anchor = anchors[id] else {
      metrics = nil
      return
    }
    let container = scrollFrame.isEmpty ? UIScreen.main.bounds : scrollFrame
    metrics = MessageOverlayMetrics(anchor: anchor, containerFrame: container)
  }

  func currentMessage() -> ChatMessage? {
    guard let id = highlightedMessageID else { return nil }
    return messageProvider().first { $0.id == id }
  }

  func performReaction(_ emoji: String) {
    guard let message = currentMessage() else { return }
    reactionHandler(emoji, message)
    dismiss()
  }

  func showAllReactions() {
    guard let message = currentMessage() else { return }
    moreReactionHandler(message)
    dismiss()
  }
}

struct MessageOverlayMetrics: Equatable {
  let anchor: MessageAnchorInfo
  let containerFrame: CGRect

  private let verticalSpacing: CGFloat = 12
  private let topSafePadding: CGFloat = 48
  private let bottomSafePadding: CGFloat = 120
  private let horizontalPadding: CGFloat = 28

  var reactionPosition: CGPoint {
    let barSize = CGSize(width: ReactionBarLayout.barWidth, height: ReactionBarLayout.barHeight)
    let topLimit = containerFrame.minY + topSafePadding + barSize.height / 2
    let bottomLimit = containerFrame.maxY - bottomSafePadding - barSize.height / 2

    var y = anchor.globalFrame.minY - verticalSpacing - barSize.height / 2
    if y < topLimit {
      y = anchor.globalFrame.maxY + verticalSpacing + barSize.height / 2
    }
    y = min(max(y, topLimit), bottomLimit)

    let leftLimit = containerFrame.minX + horizontalPadding + barSize.width / 2
    let rightLimit = containerFrame.maxX - horizontalPadding - barSize.width / 2
    var x = anchor.globalFrame.midX
    x = min(max(x, leftLimit), rightLimit)

    return CGPoint(x: x, y: y)
  }

  var glowCenterUnitPoint: UnitPoint {
    let width = containerFrame.width
    let height = containerFrame.height
    guard width > 0, height > 0 else { return .center }
    let x = min(max((anchor.globalFrame.midX - containerFrame.minX) / width, 0), 1)
    let y = min(max((anchor.globalFrame.midY - containerFrame.minY) / height, 0), 1)
    return UnitPoint(x: x, y: y)
  }

  var glowStartRadius: CGFloat {
    max(min(anchor.globalFrame.width, anchor.globalFrame.height) * 0.5, 14)
  }

  var glowEndRadius: CGFloat {
    max(glowStartRadius * 3, max(containerFrame.width, containerFrame.height))
  }
}

struct MessageOverlayContainer<Content: View>: View {
  let client: HackChatClient
  let onShowFullPicker: (ChatMessage) -> Void
  let content: (MessageOverlayState) -> Content

  @State private var overlayState: MessageOverlayState

  init(
    client: HackChatClient,
    onShowFullPicker: @escaping (ChatMessage) -> Void,
    @ViewBuilder content: @escaping (MessageOverlayState) -> Content
  ) {
    self.client = client
    self.onShowFullPicker = onShowFullPicker
    self.content = content
    _overlayState = State(
      initialValue: MessageOverlayState(
        messageProvider: { client.messagesByChannel[client.currentChannel] ?? [] },
        reactionHandler: { emoji, message in
          client.reactionManager.toggleReaction(
            emoji: emoji,
            messageId: message.id,
            channel: message.channel
          )
        },
        moreReactionHandler: onShowFullPicker
      )
    )
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      content(overlayState)

      if let metrics = overlayState.metrics {
        GeometryReader { geo in
          ReactionOverlayView(
            metrics: metrics,
            containerFrame: geo.frame(in: .global),
            currentMessage: overlayState.currentMessage(),
            myNick: client.myNick,
            onDismiss: { overlayState.dismiss() },
            onReactionTap: { overlayState.performReaction($0) },
            onMoreReaction: { overlayState.showAllReactions() }
          )
          .frame(width: geo.size.width, height: geo.size.height)
          .ignoresSafeArea()
        }
        .transition(.scale(scale: 0.92).combined(with: .opacity))
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: metrics)
      }
    }
  }
}

struct ReactionOverlayView: View {
  let metrics: MessageOverlayMetrics
  let containerFrame: CGRect
  let currentMessage: ChatMessage?
  let myNick: String
  var onDismiss: () -> Void
  var onReactionTap: (String) -> Void
  var onMoreReaction: () -> Void

  var body: some View {
    let position = metrics.reactionPosition
    let barX = position.x - containerFrame.minX
    let barY = position.y - containerFrame.minY

    ZStack(alignment: .topLeading) {
      Color.black.opacity(0.08)
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }

      RadialGradient(
        gradient: Gradient(colors: [Color.white.opacity(0.14), .clear]),
        center: metrics.glowCenterUnitPoint,
        startRadius: metrics.glowStartRadius,
        endRadius: metrics.glowEndRadius
      )
      .blendMode(.screen)
      .allowsHitTesting(false)
      .ignoresSafeArea()

      ReactionBarView(
        currentMessage: currentMessage,
        myNick: myNick,
        onReactionTap: onReactionTap,
        onMore: onMoreReaction
      )
        .position(x: barX, y: barY)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .contentShape(Rectangle())
  }
}

struct ReactionBarView: View {
  let currentMessage: ChatMessage?
  let myNick: String
  var onReactionTap: (String) -> Void
  var onMore: () -> Void
  
  // 获取当前用户选择的表情
  private var selectedEmoji: String? {
    guard let message = currentMessage else { return nil }
    for (emoji, reactions) in message.reactions {
      if reactions.contains(where: { $0.userId == myNick }) {
        return emoji
      }
    }
    return nil
  }

  var body: some View {
    HStack(spacing: 0) {
      // 横向滚动的表情列表
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: ReactionBarLayout.spacing) {
          ForEach(QuickReactions.all, id: \.self) { emoji in
            Button {
              onReactionTap(emoji)
            } label: {
              Text(emoji)
                .font(.system(size: ReactionBarLayout.emojiFont))
                .frame(width: ReactionBarLayout.emojiDiameter, height: ReactionBarLayout.emojiDiameter)
                .background(
                  // 如果是已选择的表情，显示圆形背景
                  Circle()
                    .fill(
                      selectedEmoji == emoji
                        ? LinearGradient(
                            colors: [Color(hex: "5B36FF").opacity(0.25), Color(hex: "FF6CCB").opacity(0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                        : LinearGradient(colors: [.clear, .clear], startPoint: .top, endPoint: .bottom)
                    )
                )
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, ReactionBarLayout.horizontalPadding)
      }
      .frame(maxWidth: UIScreen.main.bounds.width * 0.7) // 限制最大宽度以便显示加号按钮
      
      Spacer().frame(width: ReactionBarLayout.plusGap)
      
      // 加号按钮
      Button(action: onMore) {
        Image(systemName: "plus")
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(Color(hex: "626A81"))
          .frame(width: ReactionBarLayout.plusDiameter, height: ReactionBarLayout.plusDiameter)
          .background(
            Circle()
              .fill(Color.white.opacity(0.9))
              .shadow(color: Color.black.opacity(0.08), radius: 3, y: 2)
          )
      }
      .buttonStyle(.plain)
      .padding(.trailing, ReactionBarLayout.horizontalPadding)
    }
    .frame(height: ReactionBarLayout.barHeight)
    .background(
      RoundedRectangle(cornerRadius: 26, style: .continuous)
        .fill(
          LinearGradient(
            colors: [Color.white.opacity(0.95), Color.white.opacity(0.82)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .shadow(color: Color.black.opacity(0.15), radius: 16, y: 8)
    )
  }
}
