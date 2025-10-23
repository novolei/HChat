# 💬 私聊功能设计 V2 - 微信/WhatsApp 风格

## 设计理念

### 与微信/WhatsApp 一致的体验

```
主界面
├─ 聊天 Tab（默认）
│  ├─ 🟢 Alice (在线)
│  │   最后消息: 好的，明天见
│  │   时间: 5分钟前
│  │   未读: 2
│  │
│  ├─ 🔴 Bob (离线)
│  │   最后消息: [图片]
│  │   时间: 昨天
│  │
│  └─ 🟢 Charlie (在线)
│      最后消息: 👍
│      时间: 刚刚
│
├─ 频道 Tab
│  ├─ #general
│  ├─ #ios-dev
│  └─ #random
│
├─ 通讯录 Tab
│  └─ 所有在线用户列表
│
└─ 我 Tab
   └─ 设置、个人信息等
```

## 核心差异

### 当前设计 vs 新设计

| 特性 | 当前设计（类 IRC） | 新设计（类微信） |
|------|-------------------|-----------------|
| 聊天入口 | `/dm Alice` 命令 | 点击用户头像 |
| 聊天列表 | 混在频道列表中 | 独立的"聊天"Tab |
| 会话管理 | 作为频道管理 | 独立的会话管理 |
| 在线状态 | 不显示 | 实时显示 |
| 最后消息 | 不显示 | 显示预览 |
| 未读角标 | 通用未读数 | 每个会话独立 |
| 消息顺序 | 按频道排序 | 按最后消息时间排序 |

## 新架构设计

### 数据模型

#### 1. 会话（Conversation）

```swift
/// 聊天会话
public struct Conversation: Identifiable, Codable {
    public let id: String              // 会话 ID
    public let type: ConversationType  // 会话类型
    public var title: String           // 显示名称
    public var avatar: String?         // 头像 URL
    public var lastMessage: ChatMessage?  // 最后一条消息
    public var unreadCount: Int = 0    // 未读数
    public var isPinned: Bool = false  // 是否置顶
    public var isMuted: Bool = false   // 是否免打扰
    public var updatedAt: Date         // 最后更新时间
    
    // 私聊专属
    public var otherUserId: String?    // 对方用户 ID（私聊）
    public var isOnline: Bool = false  // 对方是否在线（私聊）
    
    // 频道专属
    public var channelId: String?      // 频道 ID
    public var memberCount: Int = 0    // 成员数
}

/// 会话类型
public enum ConversationType: String, Codable {
    case dm          // 私聊
    case channel     // 频道
    case group       // 群聊（未来）
}
```

#### 2. 用户状态（UserStatus）

```swift
/// 用户在线状态
public struct UserStatus: Codable {
    public let userId: String
    public var isOnline: Bool
    public var lastSeen: Date?
    public var customStatus: String?  // "忙碌"、"学习中"等
}
```

#### 3. 更新 ChatState

```swift
@MainActor
@Observable
public final class ChatState {
    // ✨ 新增：会话列表
    public var conversations: [Conversation] = []
    
    // ✨ 新增：当前活跃会话
    public var currentConversation: Conversation?
    
    // ✨ 新增：用户状态映射
    public var userStatuses: [String: UserStatus] = [:]
    
    // 现有属性
    public var channels: [Channel] = []
    public var messagesByChannel: [String: [ChatMessage]] = [:]
    public var myNick: String = ""
    
    // ✨ 新增：会话管理方法
    public func createOrGetDM(with userId: String) -> Conversation {
        let conversationId = "dm:\(userId)"
        
        if let existing = conversations.first(where: { $0.id == conversationId }) {
            return existing
        }
        
        let conversation = Conversation(
            id: conversationId,
            type: .dm,
            title: userId,
            otherUserId: userId,
            updatedAt: Date()
        )
        
        conversations.append(conversation)
        return conversation
    }
    
    public func updateConversationLastMessage(_ conversationId: String, message: ChatMessage) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else {
            return
        }
        
        conversations[index].lastMessage = message
        conversations[index].updatedAt = message.timestamp
        
        // 重新排序（最新消息在最上面）
        sortConversations()
    }
    
    public func incrementUnread(_ conversationId: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else {
            return
        }
        conversations[index].unreadCount += 1
    }
    
    public func clearUnread(_ conversationId: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else {
            return
        }
        conversations[index].unreadCount = 0
    }
    
    private func sortConversations() {
        conversations.sort { conv1, conv2 in
            // 置顶的在最上面
            if conv1.isPinned != conv2.isPinned {
                return conv1.isPinned
            }
            // 按最后更新时间排序
            return conv1.updatedAt > conv2.updatedAt
        }
    }
}
```

### UI 架构

#### 主界面：Tab 导航

```swift
// MainTabView.swift

struct MainTabView: View {
    @State var client: HackChatClient
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // ✨ Tab 1: 聊天列表（私聊 + 最近会话）
            ConversationsView(client: client)
                .tabItem {
                    Label("聊天", systemImage: "message.fill")
                }
                .badge(totalUnreadCount)
                .tag(0)
            
            // ✨ Tab 2: 频道列表
            ChannelListView(client: client)
                .tabItem {
                    Label("频道", systemImage: "number")
                }
                .tag(1)
            
            // ✨ Tab 3: 通讯录（在线用户）
            ContactsView(client: client)
                .tabItem {
                    Label("通讯录", systemImage: "person.2.fill")
                }
                .tag(2)
            
            // Tab 4: 我
            SettingsView(client: client)
                .tabItem {
                    Label("我", systemImage: "person.fill")
                }
                .tag(3)
        }
    }
    
    private var totalUnreadCount: Int {
        client.state.conversations.reduce(0) { $0 + $1.unreadCount }
    }
}
```

#### 聊天列表视图

```swift
// ConversationsView.swift

struct ConversationsView: View {
    let client: HackChatClient
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            List {
                // 置顶会话
                if !pinnedConversations.isEmpty {
                    Section {
                        ForEach(pinnedConversations) { conversation in
                            ConversationRow(conversation: conversation, client: client)
                        }
                    }
                }
                
                // 普通会话
                Section {
                    ForEach(normalConversations) { conversation in
                        ConversationRow(conversation: conversation, client: client)
                    }
                    .onDelete(perform: deleteConversations)
                }
            }
            .searchable(text: $searchText, prompt: "搜索聊天")
            .navigationTitle("聊天")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // 新建聊天（跳转到通讯录选人）
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
    }
    
    private var pinnedConversations: [Conversation] {
        client.state.conversations.filter { $0.isPinned }
    }
    
    private var normalConversations: [Conversation] {
        client.state.conversations.filter { !$0.isPinned }
    }
}
```

#### 会话行（类似微信）

```swift
// ConversationRow.swift

struct ConversationRow: View {
    let conversation: Conversation
    let client: HackChatClient
    
    var body: some View {
        NavigationLink(value: conversation) {
            HStack(spacing: 12) {
                // 头像
                ZStack(alignment: .bottomTrailing) {
                    avatarView
                    
                    // 在线状态点（仅私聊）
                    if conversation.type == .dm && conversation.isOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    }
                }
                
                // 内容
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(conversation.title)
                            .font(.headline)
                        
                        Spacer()
                        
                        // 时间
                        if let lastMsg = conversation.lastMessage {
                            Text(formatTime(lastMsg.timestamp))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        // 最后一条消息预览
                        lastMessagePreview
                        
                        Spacer()
                        
                        // 未读角标
                        if conversation.unreadCount > 0 {
                            UnreadBadge(count: conversation.unreadCount)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            // 置顶/取消置顶
            Button {
                togglePin()
            } label: {
                Label(conversation.isPinned ? "取消置顶" : "置顶", 
                      systemImage: conversation.isPinned ? "pin.slash" : "pin.fill")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // 删除
            Button(role: .destructive) {
                deleteConversation()
            } label: {
                Label("删除", systemImage: "trash")
            }
            
            // 免打扰
            Button {
                toggleMute()
            } label: {
                Label(conversation.isMuted ? "取消免打扰" : "免打扰", 
                      systemImage: conversation.isMuted ? "bell" : "bell.slash")
            }
            .tint(.purple)
        }
    }
    
    @ViewBuilder
    private var avatarView: some View {
        if conversation.type == .dm {
            // 私聊头像
            Circle()
                .fill(colorForNickname(conversation.title))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(conversation.title.prefix(1).uppercased())
                        .foregroundColor(.white)
                        .font(.title3.bold())
                )
        } else {
            // 频道图标
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Text("#")
                        .foregroundColor(.accentColor)
                        .font(.title2.bold())
                )
        }
    }
    
    @ViewBuilder
    private var lastMessagePreview: some View {
        if let lastMsg = conversation.lastMessage {
            HStack(spacing: 4) {
                // 发送者（群聊时显示）
                if conversation.type != .dm && lastMsg.sender != client.myNick {
                    Text("\(lastMsg.sender):")
                        .foregroundColor(.secondary)
                }
                
                // 消息内容预览
                messageContentPreview(lastMsg)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
    }
    
    @ViewBuilder
    private func messageContentPreview(_ message: ChatMessage) -> some View {
        if !message.attachments.isEmpty {
            switch message.attachments[0].kind {
            case .image: Text("[图片]")
            case .video: Text("[视频]")
            case .audio: Text("[语音]")
            case .file: Text("[文件]")
            }
        } else {
            Text(message.text)
        }
    }
}
```

#### 通讯录视图（在线用户）

```swift
// ContactsView.swift

struct ContactsView: View {
    let client: HackChatClient
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            List {
                // 在线用户
                Section("在线 (\(onlineUsers.count))") {
                    ForEach(onlineUsers, id: \.self) { userId in
                        ContactRow(userId: userId, client: client)
                    }
                }
                
                // 离线用户（最近联系过的）
                if !recentOfflineUsers.isEmpty {
                    Section("最近") {
                        ForEach(recentOfflineUsers, id: \.self) { userId in
                            ContactRow(userId: userId, client: client)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索用户")
            .navigationTitle("通讯录")
        }
    }
    
    private var onlineUsers: [String] {
        // 从所有频道的在线用户中去重
        let allOnline = client.state.onlineByRoom.values
            .flatMap { $0 }
            .filter { $0 != client.myNick }
        
        return Array(Set(allOnline)).sorted()
    }
    
    private var recentOfflineUsers: [String] {
        // 从会话中提取最近联系的离线用户
        client.state.conversations
            .filter { $0.type == .dm && !$0.isOnline }
            .compactMap { $0.otherUserId }
    }
}

struct ContactRow: View {
    let userId: String
    let client: HackChatClient
    
    var body: some View {
        Button {
            // 点击用户 → 打开私聊
            openPrivateChat()
        } label: {
            HStack(spacing: 12) {
                // 头像
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(colorForNickname(userId))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(userId.prefix(1).uppercased())
                                .foregroundColor(.white)
                                .font(.headline)
                        )
                    
                    // 在线状态
                    if isOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: 1.5)
                            )
                    }
                }
                
                // 用户名
                Text(userId)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 在线状态文字
                if isOnline {
                    Text("在线")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if let lastSeen = userStatus?.lastSeen {
                    Text(formatLastSeen(lastSeen))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private var isOnline: Bool {
        client.state.userStatuses[userId]?.isOnline ?? false
    }
    
    private var userStatus: UserStatus? {
        client.state.userStatuses[userId]
    }
    
    private func openPrivateChat() {
        // 创建或获取私聊会话
        let conversation = client.state.createOrGetDM(with: userId)
        client.state.currentConversation = conversation
        
        // 导航到聊天界面
        // （使用 NavigationPath 或其他导航机制）
    }
}
```

### 命令行快捷方式（保留）

在频道中，仍然支持 `/dm` 命令快速发起私聊：

```swift
// ChatView.swift

// 在频道中输入 /dm Alice Hello
// ↓
// 自动创建或打开与 Alice 的私聊
// 发送 "Hello"
// 切换到聊天 Tab 并打开该会话
```

## 后端改造

### 在线状态广播

```javascript
// chat-gateway/src/handlers/connectionHandler.js

function handleUserOnline(ws, userId, channel) {
  // 广播用户上线状态
  broadcast('global', {
    type: 'user_status',
    userId: userId,
    isOnline: true,
    timestamp: Date.now()
  });
}

function handleUserOffline(ws, userId) {
  // 广播用户离线状态
  broadcast('global', {
    type: 'user_status',
    userId: userId,
    isOnline: false,
    lastSeen: Date.now()
  });
}
```

### 私聊消息路由（复用虚拟频道）

```javascript
// 后端逻辑保持不变
// 仍然使用 dm:user1:user2 虚拟频道
// 但 iOS 端会包装成独立的会话
```

## 迁移路径

### 阶段 1：数据模型（1 小时）

- [ ] 创建 `Conversation` 模型
- [ ] 创建 `UserStatus` 模型
- [ ] 更新 `ChatState` 添加会话管理

### 阶段 2：UI 重构（2 小时）

- [ ] 创建 Tab 导航
- [ ] 实现 `ConversationsView`
- [ ] 实现 `ContactsView`
- [ ] 调整 `ChatView` 支持会话模式

### 阶段 3：在线状态（1 小时）

- [ ] 后端广播在线状态
- [ ] iOS 端接收并更新 `UserStatus`
- [ ] UI 显示在线状态点

### 阶段 4：会话管理（1 小时）

- [ ] 实现置顶/删除/免打扰
- [ ] 未读角标管理
- [ ] 最后消息更新

## 总时间估算

- **P0: 基础架构**（2 小时）- 数据模型 + Tab 导航
- **P1: 聊天列表**（1 小时）- ConversationsView
- **P2: 通讯录**（1 小时）- ContactsView + 在线状态
- **P3: 会话管理**（1 小时）- 置顶/免打扰等

**总计：5-6 小时**完成完整的微信风格私聊！

## 要开始实现吗？

这个方案更符合现代 IM 的设计，用户体验会好很多！准备好了就告诉我！

