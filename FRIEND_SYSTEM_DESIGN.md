# 👥 好友系统设计

## 核心机制

### 陌生人聊天限制

```
Alice（陌生人）          Bob（陌生人）
    ↓                        ↓
发送第1条消息 ─────────→  收到消息 + 好友请求提示
    ↓                        ↓
发送第2条消息 ─────────→  收到消息（还剩1条）
    ↓                        ↓
发送第3条消息 ─────────→  收到消息（已达上限）
    ↓                        ↓
❌ 无法继续发送            可以回复3条
提示：等待对方接受好友请求    ↓
                         Bob 回复第1条 ────→ Alice 收到
                             ↓
                         Bob 回复第2条 ────→ Alice 收到
                             ↓
                         Bob 回复第3条 ────→ Alice 收到
                             ↓
                         ❌ 也无法继续发送
                         
                         Bob 点击"接受好友请求" ✅
                             ↓
                         双方成为好友
                             ↓
                         可以无限制聊天 🎉
```

### 好友关系状态

```swift
/// 好友关系状态
public enum FriendshipStatus: String, Codable {
    case stranger        // 陌生人（未发起过聊天）
    case pending         // 待确认（已发起聊天，等待对方接受）
    case friends         // 已成为好友
    case blocked         // 已屏蔽
}
```

## 数据模型

### 1. 好友关系（Friendship）

```swift
/// 好友关系
public struct Friendship: Identifiable, Codable {
    public let id: String                  // 关系 ID
    public let userId1: String             // 用户1
    public let userId2: String             // 用户2
    public var status: FriendshipStatus    // 关系状态
    public var initiator: String           // 发起者（谁先发消息）
    public var createdAt: Date             // 创建时间
    public var acceptedAt: Date?           // 接受好友时间
    
    // 消息计数（陌生人模式）
    public var messagesFromUser1: Int = 0  // 用户1发送的消息数
    public var messagesFromUser2: Int = 0  // 用户2发送的消息数
    
    public static let maxStrangerMessages = 3  // 陌生人最多发送3条
    
    /// 判断某用户是否还能发送消息
    public func canSendMessage(from userId: String) -> Bool {
        // 如果已是好友，无限制
        if status == .friends {
            return true
        }
        
        // 如果被屏蔽，不能发送
        if status == .blocked {
            return false
        }
        
        // 陌生人/待确认状态，检查消息数
        if userId == userId1 {
            return messagesFromUser1 < Self.maxStrangerMessages
        } else if userId == userId2 {
            return messagesFromUser2 < Self.maxStrangerMessages
        }
        
        return false
    }
    
    /// 获取剩余可发消息数
    public func remainingMessages(for userId: String) -> Int {
        if status == .friends {
            return Int.max
        }
        
        if userId == userId1 {
            return max(0, Self.maxStrangerMessages - messagesFromUser1)
        } else if userId == userId2 {
            return max(0, Self.maxStrangerMessages - messagesFromUser2)
        }
        
        return 0
    }
}
```

### 2. 好友请求提示（FriendRequest）

```swift
/// 好友请求
public struct FriendRequest: Identifiable, Codable {
    public let id: String
    public let from: String          // 发起者
    public let to: String            // 接收者
    public var message: String?      // 附带的首条消息
    public let timestamp: Date
    public var status: RequestStatus
    
    public enum RequestStatus: String, Codable {
        case pending    // 待处理
        case accepted   // 已接受
        case declined   // 已拒绝
        case expired    // 已过期
    }
}
```

### 3. 更新 ChatState

```swift
@MainActor
@Observable
public final class ChatState {
    // 现有属性...
    
    // ✨ 新增：好友关系映射
    public var friendships: [String: Friendship] = [:]  // userId -> Friendship
    
    // ✨ 新增：待处理的好友请求
    public var pendingFriendRequests: [FriendRequest] = []
    
    /// 获取与某用户的好友关系
    public func getFriendship(with userId: String) -> Friendship? {
        // 先尝试直接查找
        if let friendship = friendships[userId] {
            return friendship
        }
        
        // 反向查找（因为关系是双向的）
        return friendships.values.first { friendship in
            (friendship.userId1 == myNick && friendship.userId2 == userId) ||
            (friendship.userId2 == myNick && friendship.userId1 == userId)
        }
    }
    
    /// 创建或更新好友关系
    public func createOrUpdateFriendship(with userId: String, initiator: String? = nil) -> Friendship {
        if let existing = getFriendship(with: userId) {
            return existing
        }
        
        // 创建新关系
        let sorted = [myNick, userId].sorted()
        let friendship = Friendship(
            id: "friendship:\(sorted[0]):\(sorted[1])",
            userId1: sorted[0],
            userId2: sorted[1],
            status: .stranger,
            initiator: initiator ?? myNick,
            createdAt: Date()
        )
        
        friendships[userId] = friendship
        return friendship
    }
    
    /// 增加消息计数
    public func incrementMessageCount(from sender: String, to receiver: String) {
        guard var friendship = getFriendship(with: receiver) else {
            return
        }
        
        // 如果已是好友，不需要计数
        if friendship.status == .friends {
            return
        }
        
        // 增加计数
        if sender == friendship.userId1 {
            friendship.messagesFromUser1 += 1
        } else if sender == friendship.userId2 {
            friendship.messagesFromUser2 += 1
        }
        
        // 更新状态
        if friendship.status == .stranger && friendship.messagesFromUser1 > 0 {
            friendship.status = .pending
        }
        
        friendships[receiver] = friendship
    }
    
    /// 接受好友请求
    public func acceptFriendRequest(from userId: String) {
        guard var friendship = getFriendship(with: userId) else {
            return
        }
        
        friendship.status = .friends
        friendship.acceptedAt = Date()
        friendships[userId] = friendship
        
        // 移除待处理请求
        pendingFriendRequests.removeAll { $0.from == userId }
    }
    
    /// 拒绝好友请求
    public func declineFriendRequest(from userId: String) {
        guard var friendship = getFriendship(with: userId) else {
            return
        }
        
        // 可以选择删除关系或标记为已拒绝
        friendships.removeValue(forKey: userId)
        
        // 移除待处理请求
        pendingFriendRequests.removeAll { $0.from == userId }
    }
    
    /// 屏蔽用户
    public func blockUser(_ userId: String) {
        var friendship = createOrUpdateFriendship(with: userId)
        friendship.status = .blocked
        friendships[userId] = friendship
    }
}
```

## UI 设计

### 1. 消息发送限制提示

```swift
// ChatInputView.swift

struct ChatInputView: View {
    let client: HackChatClient
    @State private var inputText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // ✨ 陌生人限制提示
            if let warning = strangerWarning {
                strangerWarningBanner(warning)
            }
            
            // 输入框
            HStack {
                TextField("消息", text: $inputText)
                    .disabled(!canSendMessage)
                
                Button("发送") {
                    sendMessage()
                }
                .disabled(!canSendMessage || inputText.isEmpty)
            }
        }
    }
    
    private var canSendMessage: Bool {
        guard let conversation = currentConversation,
              conversation.type == .dm,
              let otherUser = conversation.otherUserId else {
            return true  // 频道消息无限制
        }
        
        let friendship = client.state.getFriendship(with: otherUser)
        return friendship?.canSendMessage(from: client.myNick) ?? true
    }
    
    private var strangerWarning: String? {
        guard let conversation = currentConversation,
              conversation.type == .dm,
              let otherUser = conversation.otherUserId,
              let friendship = client.state.getFriendship(with: otherUser) else {
            return nil
        }
        
        if friendship.status == .friends {
            return nil
        }
        
        let remaining = friendship.remainingMessages(for: client.myNick)
        
        if remaining == 0 {
            return "你已发送3条消息，等待对方接受好友请求后才能继续聊天"
        } else if remaining <= 2 {
            return "你还可以发送 \(remaining) 条消息（陌生人限制）"
        }
        
        return nil
    }
    
    @ViewBuilder
    private func strangerWarningBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
    }
}
```

### 2. 好友请求卡片

```swift
// FriendRequestCard.swift

struct FriendRequestCard: View {
    let request: FriendRequest
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // 头像
                Circle()
                    .fill(colorForNickname(request.from))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(request.from.prefix(1).uppercased())
                            .foregroundColor(.white)
                            .font(.title3.bold())
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.from)
                        .font(.headline)
                    
                    Text("想要添加你为好友")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let message = request.message {
                        Text(""" + message + """)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
            
            // 操作按钮
            HStack(spacing: 12) {
                Button {
                    onDecline()
                } label: {
                    Text("拒绝")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                
                Button {
                    onAccept()
                } label: {
                    Text("接受")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
        .padding(.horizontal)
    }
}
```

### 3. 会话中的好友请求横幅

```swift
// ChatView.swift

struct ChatView: View {
    let conversation: Conversation
    let client: HackChatClient
    
    var body: some View {
        VStack(spacing: 0) {
            // ✨ 好友请求横幅（置顶显示）
            if let request = pendingRequest {
                FriendRequestBanner(
                    request: request,
                    onAccept: {
                        acceptFriendRequest()
                    },
                    onDecline: {
                        declineFriendRequest()
                    }
                )
            }
            
            // 消息列表
            messageList
            
            // 输入框
            ChatInputView(client: client, conversation: conversation)
        }
    }
    
    private var pendingRequest: FriendRequest? {
        guard conversation.type == .dm,
              let otherUser = conversation.otherUserId else {
            return nil
        }
        
        return client.state.pendingFriendRequests.first { $0.from == otherUser }
    }
}

struct FriendRequestBanner: View {
    let request: FriendRequest
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.plus")
                .foregroundColor(.blue)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(request.from) 想要添加你为好友")
                    .font(.subheadline.bold())
                
                Text("接受后可以无限制聊天")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 快捷操作按钮
            HStack(spacing: 8) {
                Button("拒绝") {
                    onDecline()
                }
                .font(.caption.bold())
                .foregroundColor(.secondary)
                
                Button("接受") {
                    onAccept()
                }
                .font(.caption.bold())
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}
```

### 4. 好友列表与陌生人分组

```swift
// ContactsView.swift

struct ContactsView: View {
    let client: HackChatClient
    
    var body: some View {
        List {
            // 待处理的好友请求
            if !pendingRequests.isEmpty {
                Section("好友请求 (\(pendingRequests.count))") {
                    ForEach(pendingRequests) { request in
                        FriendRequestRow(request: request, client: client)
                    }
                }
            }
            
            // 好友列表
            Section("好友 (\(friends.count))") {
                ForEach(friends, id: \.self) { userId in
                    ContactRow(userId: userId, client: client, isFriend: true)
                }
            }
            
            // 在线用户（陌生人）
            Section("在线 (\(onlineStrangers.count))") {
                ForEach(onlineStrangers, id: \.self) { userId in
                    ContactRow(userId: userId, client: client, isFriend: false)
                }
            }
        }
    }
    
    private var pendingRequests: [FriendRequest] {
        client.state.pendingFriendRequests
    }
    
    private var friends: [String] {
        client.state.friendships.values
            .filter { $0.status == .friends }
            .flatMap { [$0.userId1, $0.userId2] }
            .filter { $0 != client.myNick }
    }
    
    private var onlineStrangers: [String] {
        // 所有在线用户 - 好友
        let allOnline = Set(client.state.onlineByRoom.values.flatMap { $0 })
        let friendSet = Set(friends)
        return Array(allOnline.subtracting(friendSet).subtracting([client.myNick]))
    }
}
```

## 后端实现

### 1. 好友关系管理

```javascript
// chat-gateway/src/services/friendshipManager.js

class FriendshipManager {
  constructor() {
    this.friendships = new Map(); // "user1:user2" -> Friendship
  }
  
  // 获取好友关系
  getFriendship(user1, user2) {
    const key = this.getFriendshipKey(user1, user2);
    return this.friendships.get(key);
  }
  
  // 创建或获取好友关系
  createOrGetFriendship(user1, user2, initiator) {
    const key = this.getFriendshipKey(user1, user2);
    
    if (this.friendships.has(key)) {
      return this.friendships.get(key);
    }
    
    const [userId1, userId2] = [user1, user2].sort();
    const friendship = {
      userId1,
      userId2,
      status: 'stranger',
      initiator: initiator || user1,
      createdAt: Date.now(),
      messagesFromUser1: 0,
      messagesFromUser2: 0
    };
    
    this.friendships.set(key, friendship);
    return friendship;
  }
  
  // 检查是否可以发送消息
  canSendMessage(from, to) {
    const friendship = this.getFriendship(from, to);
    
    if (!friendship) {
      // 首次发消息，允许
      return true;
    }
    
    if (friendship.status === 'friends') {
      return true;
    }
    
    if (friendship.status === 'blocked') {
      return false;
    }
    
    // 检查消息数限制
    const count = from === friendship.userId1 
      ? friendship.messagesFromUser1 
      : friendship.messagesFromUser2;
    
    return count < 3;
  }
  
  // 增加消息计数
  incrementMessageCount(from, to) {
    const friendship = this.createOrGetFriendship(from, to, from);
    
    if (friendship.status === 'friends') {
      return; // 好友无需计数
    }
    
    if (from === friendship.userId1) {
      friendship.messagesFromUser1++;
    } else {
      friendship.messagesFromUser2++;
    }
    
    // 更新状态
    if (friendship.status === 'stranger' && friendship.messagesFromUser1 > 0) {
      friendship.status = 'pending';
    }
  }
  
  // 接受好友请求
  acceptFriendRequest(from, to) {
    const friendship = this.getFriendship(from, to);
    
    if (friendship) {
      friendship.status = 'friends';
      friendship.acceptedAt = Date.now();
      return true;
    }
    
    return false;
  }
  
  // 生成好友关系 key（排序确保唯一）
  getFriendshipKey(user1, user2) {
    return [user1, user2].sort().join(':');
  }
}

module.exports = new FriendshipManager();
```

### 2. 消息发送检查

```javascript
// chat-gateway/src/handlers/messageHandler.js

const friendshipManager = require('../services/friendshipManager');

function handleDirectMessage(ws, msg) {
  const { to, text, id } = msg;
  const from = ws.nick;
  
  // ✨ 检查是否可以发送消息
  if (!friendshipManager.canSendMessage(from, to)) {
    // 发送错误提示
    ws.send(JSON.stringify({
      type: 'error',
      code: 'STRANGER_LIMIT_REACHED',
      message: '你已达到陌生人消息发送上限（3条），等待对方接受好友请求'
    }));
    return;
  }
  
  // ✨ 增加消息计数
  friendshipManager.incrementMessageCount(from, to);
  
  // 获取好友关系状态
  const friendship = friendshipManager.getFriendship(from, to);
  
  // 创建虚拟私聊频道
  const dmChannel = getDMChannel(from, to);
  
  // 广播消息
  const broadcastMsg = {
    type: 'message',
    channel: dmChannel,
    nick: from,
    text: text,
    id: id || generateId(),
    isDM: true,
    dmWith: to,
    // ✨ 附带好友关系信息
    friendship: {
      status: friendship?.status || 'stranger',
      canReply: friendshipManager.canSendMessage(to, from),
      remainingMessages: getRemainingMessages(friendship, to)
    }
  };
  
  broadcast(dmChannel, broadcastMsg);
  
  // ✨ 如果是首次发消息，发送好友请求通知
  if (friendship?.status === 'pending' && friendship.messagesFromUser1 === 1) {
    sendFriendRequestNotification(from, to, text);
  }
}

// 发送好友请求通知
function sendFriendRequestNotification(from, to, firstMessage) {
  const targetWs = findUserByNick(to);
  
  if (targetWs && targetWs.readyState === 1) {
    targetWs.send(JSON.stringify({
      type: 'friend_request',
      from: from,
      message: firstMessage,
      timestamp: Date.now()
    }));
  }
}
```

### 3. 好友请求处理

```javascript
// chat-gateway/src/handlers/friendshipHandler.js

function handleFriendshipAction(ws, msg) {
  const { action, targetUser } = msg;
  const myNick = ws.nick;
  
  switch (action) {
    case 'accept':
      // 接受好友请求
      if (friendshipManager.acceptFriendRequest(targetUser, myNick)) {
        // 通知双方
        broadcastFriendshipUpdate(myNick, targetUser, 'friends');
        
        // 发送成功通知
        ws.send(JSON.stringify({
          type: 'friendship_updated',
          userId: targetUser,
          status: 'friends',
          message: `你和 ${targetUser} 已成为好友`
        }));
      }
      break;
      
    case 'decline':
      // 拒绝好友请求（可选实现）
      break;
      
    case 'block':
      // 屏蔽用户（可选实现）
      break;
  }
}

function broadcastFriendshipUpdate(user1, user2, newStatus) {
  const message = {
    type: 'friendship_updated',
    user1,
    user2,
    status: newStatus,
    timestamp: Date.now()
  };
  
  // 发送给双方
  const ws1 = findUserByNick(user1);
  const ws2 = findUserByNick(user2);
  
  if (ws1?.readyState === 1) {
    ws1.send(JSON.stringify({...message, otherUser: user2}));
  }
  
  if (ws2?.readyState === 1) {
    ws2.send(JSON.stringify({...message, otherUser: user1}));
  }
}
```

## 实施计划

### 阶段 1：数据模型与基础逻辑（2 小时）

- [ ] 创建 `Friendship` 和 `FriendRequest` 模型
- [ ] 更新 `ChatState` 添加好友管理方法
- [ ] 后端实现 `FriendshipManager`

### 阶段 2：消息发送限制（1 小时）

- [ ] 后端检查消息发送权限
- [ ] 增加消息计数
- [ ] iOS 端显示限制提示

### 阶段 3：好友请求 UI（2 小时）

- [ ] 好友请求横幅
- [ ] 好友请求卡片
- [ ] 接受/拒绝操作

### 阶段 4：通讯录优化（1 小时）

- [ ] 好友与陌生人分组
- [ ] 待处理请求列表
- [ ] 好友标记

### 阶段 5：测试与优化（1 小时）

- [ ] 测试各种场景
- [ ] 优化 UI 提示
- [ ] 边界情况处理

**总计：7 小时**完成完整的好友系统

## 用户场景测试

### 场景 1：首次聊天

```
Alice 点击 Bob（陌生人）
    ↓
发送 "你好"（1/3）
    ↓
Bob 收到消息 + 好友请求横幅
    ↓
Bob 回复 "你好呀"（1/3）
    ↓
Alice 发送 "在吗？"（2/3）
    ↓
Alice 发送 "方便聊聊吗？"（3/3）
    ↓
❌ Alice 无法继续发送
提示：等待对方接受好友请求
    ↓
Bob 点击"接受好友请求" ✅
    ↓
双方成为好友
    ↓
Alice 可以继续发送消息了 🎉
```

### 场景 2：拒绝好友请求

```
Alice 发送 3 条消息
    ↓
Bob 点击"拒绝" ❌
    ↓
会话仍然保留（历史消息）
    ↓
但双方都无法继续发送
    ↓
Alice 可以选择删除会话
```

### 场景 3：已是好友

```
Alice 和 Bob 已是好友
    ↓
无任何限制
    ↓
可以无限发送消息
    ↓
不显示好友请求横幅
```

## 要开始实现吗？

这个好友系统会让 HChat 的社交体验更加完善！预计 **7 小时**完成全部功能。

要现在开始实现吗？我可以帮你一步步完成！

