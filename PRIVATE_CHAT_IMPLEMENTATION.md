# 💬 1:1 私聊功能实现方案

## 当前状态

### iOS 端
- ✅ 已定义 `ClientCommand.dm(String, String)` 命令
- ✅ 已实现 `handleDirectMessage` 处理逻辑
- ✅ 本地使用 `pm/{nickname}` 作为私聊频道

### 后端
- ❌ **未实现私聊消息路由**
- ❌ 当前只广播到频道，不支持点对点

## 设计方案

### 方案 1：虚拟私聊频道（推荐）⭐⭐⭐

**原理**：将 1:1 私聊视为一个特殊的频道，只有两个用户。

**频道命名规则**：
```javascript
// 将两个用户名排序后组合（确保唯一性）
function getDMChannel(user1, user2) {
  const sorted = [user1, user2].sort();
  return `dm:${sorted[0]}:${sorted[1]}`;
}

// 例如：
// Alice + Bob → "dm:Alice:Bob"
// Bob + Alice → "dm:Alice:Bob" (相同)
```

**优点**：
- ✅ 复用现有频道逻辑（广播、在线用户等）
- ✅ 实现简单，不需要新的消息类型
- ✅ 支持群聊扩展（添加更多用户到频道）
- ✅ 与 E2EE 完美兼容

**缺点**：
- ❌ 频道名可能泄露私聊关系（但消息内容仍加密）

### 方案 2：点对点路由（复杂）⭐⭐

**原理**：服务器维护用户 WebSocket 映射，直接路由消息。

```javascript
// 用户连接映射
const userConnections = new Map(); // nickname -> ws

// 发送私聊消息
function sendDM(from, to, message) {
  const targetWs = userConnections.get(to);
  if (targetWs && targetWs.readyState === WebSocket.OPEN) {
    targetWs.send(JSON.stringify({
      type: 'dm',
      from: from,
      text: message
    }));
  }
}
```

**优点**：
- ✅ 真正的点对点
- ✅ 隐私性更好

**缺点**：
- ❌ 实现复杂
- ❌ 需要新的消息类型和处理逻辑
- ❌ 难以扩展到群聊
- ❌ 离线消息处理复杂

## 推荐实施：方案 1（虚拟私聊频道）

### 架构设计

```
iOS App                    chat-gateway              其他用户
   ↓                            ↓                        ↓
发送 /dm Bob Hello         收到 dm 消息              (Bob)
   ↓                            ↓                        ↓
本地创建频道              创建/加入虚拟频道          自动加入频道
pm/Bob                    dm:Alice:Bob              dm:Alice:Bob
   ↓                            ↓                        ↓
显示在私聊列表            广播到该频道                收到消息
```

### 实现步骤

#### Step 1：后端支持私聊消息类型

**文件**: `HCChatBackEnd/chat-gateway/src/handlers/index.js`

```javascript
// handlers/index.js

function handleMessage(ws, data) {
  try {
    const msg = JSON.parse(data.toString());
    
    switch (msg.type) {
      case 'join':
        handleJoin(ws, msg);
        break;
        
      case 'message':
        handleChatMessage(ws, msg);
        break;
        
      // ✨ 新增：处理私聊消息
      case 'dm':
        handleDirectMessage(ws, msg);
        break;
        
      case 'typing':
        handleTyping(ws, msg);
        break;
        
      // ... 其他消息类型
    }
  } catch (e) {
    console.error('Message parse error:', e);
  }
}

// ✨ 新增：处理私聊消息
function handleDirectMessage(ws, msg) {
  const { to, text, id } = msg;
  const from = ws.nick;
  
  if (!from || !to || !text) {
    console.warn('Invalid DM message:', msg);
    return;
  }
  
  // 1. 创建虚拟私聊频道名（排序确保唯一）
  const dmChannel = getDMChannel(from, to);
  
  // 2. 自动将发送者和接收者加入该频道
  joinDMChannel(ws, dmChannel, from);
  joinDMChannel(findUserByNick(to), dmChannel, to);
  
  // 3. 广播消息到私聊频道
  const broadcastMsg = {
    type: 'message',
    channel: dmChannel,
    nick: from,
    text: text,
    id: id || generateId(),
    isDM: true, // 标记为私聊消息
    dmWith: to   // 对方昵称
  };
  
  broadcast(dmChannel, broadcastMsg);
  
  // 4. 发送 ACK
  if (ws.readyState === 1) {
    ws.send(JSON.stringify({
      type: 'message_ack',
      messageId: broadcastMsg.id,
      status: 'received'
    }));
  }
  
  console.log(`💬 DM: ${from} -> ${to} in channel ${dmChannel}`);
}

// 辅助函数：生成私聊频道名
function getDMChannel(user1, user2) {
  const sorted = [user1, user2].sort();
  return `dm:${sorted[0]}:${sorted[1]}`;
}

// 辅助函数：加入私聊频道（不广播 join 消息）
function joinDMChannel(ws, channel, nick) {
  if (!ws || ws.readyState !== 1) return;
  
  ws.channel = channel;
  ws.nick = nick;
  roomManager.addToRoom(channel, ws);
}

// 辅助函数：根据昵称查找用户
function findUserByNick(nick) {
  // 遍历所有房间，查找该昵称的用户
  const allUsers = roomManager.getAllUsers();
  return allUsers.find(user => user.nick === nick);
}
```

#### Step 2：iOS 端适配

**文件**: `HChat/Core/Networking/MessageHandler.swift`

```swift
// MessageHandler.swift

private func handleChatMessage(_ obj: [String: Any], state: ChatState) {
    // ... 现有代码 ...
    
    let channel = (obj["channel"] as? String) ?? "general"
    let nick = (obj["nick"] as? String) ?? "unknown"
    let text = (obj["text"] as? String) ?? ""
    let msgId = (obj["id"] as? String) ?? UUID().uuidString
    
    // ✨ 检查是否为私聊消息
    let isDM = (obj["isDM"] as? Bool) ?? false
    let dmWith = obj["dmWith"] as? String
    
    // ✨ 如果是私聊消息，本地频道名使用 "pm/{对方昵称}"
    let localChannel: String
    if isDM {
        if nick == state.myNick {
            // 自己发的私聊，频道名是 pm/{对方}
            localChannel = "pm/\(dmWith ?? "unknown")"
        } else {
            // 对方发来的私聊，频道名是 pm/{对方}
            localChannel = "pm/\(nick)"
        }
    } else {
        // 普通频道消息
        localChannel = channel
    }
    
    // ... 解密和创建消息 ...
    
    let message = ChatMessage(
        id: msgId,
        channel: localChannel,  // ✅ 使用本地频道名
        sender: nick,
        text: decryptedText,
        attachments: attachments,
        replyTo: replyTo
    )
    
    state.appendMessage(message)
    
    // ✨ 如果是私聊消息且是新会话，自动添加到频道列表
    if isDM && !state.channels.contains(where: { $0.id == localChannel }) {
        state.addChannel(Channel(id: localChannel, name: displayName))
    }
}
```

**文件**: `HChat/Core/Networking/CommandHandler.swift`

```swift
// CommandHandler.swift

private func handleDirectMessage(to: String, text: String, state: ChatState) {
    let id = UUID().uuidString
    state.markMessageAsSent(id: id)
    
    // ✅ 本地频道名：pm/{对方昵称}
    let localChannel = "pm/\(to)"
    
    // ✅ 自动创建私聊频道（如果不存在）
    if !state.channels.contains(where: { $0.id == localChannel }) {
        state.addChannel(Channel(id: localChannel, name: to))
    }
    
    // ✅ 发送到后端（后端会处理虚拟频道）
    let dmMessage: [String: Any] = [
        "type": "dm",
        "id": id,
        "to": to,
        "text": text
    ]
    
    sendMessage(dmMessage)
    
    // ✅ 本地回显
    let message = ChatMessage(
        id: id,
        channel: localChannel,
        sender: state.myNick,
        text: text,
        isLocalEcho: true
    )
    
    state.appendMessage(message)
}
```

#### Step 3：UI 层适配

**文件**: `HChat/Views/Main/ChatsListView.swift`

添加私聊列表显示：

```swift
// ChatsListView.swift

var body: some View {
    List {
        Section("频道") {
            ForEach(regularChannels) { channel in
                channelRow(channel)
            }
        }
        
        // ✨ 新增：私聊列表
        Section("私聊") {
            ForEach(dmChannels) { channel in
                dmRow(channel)
            }
        }
    }
}

// 分离频道和私聊
private var regularChannels: [Channel] {
    client.channels.filter { !$0.id.hasPrefix("pm/") }
}

private var dmChannels: [Channel] {
    client.channels.filter { $0.id.hasPrefix("pm/") }
}

// 私聊行显示
private func dmRow(_ channel: Channel) -> some View {
    HStack {
        // 头像
        Circle()
            .fill(colorForNickname(channel.name))
            .frame(width: 40, height: 40)
            .overlay(
                Text(String(channel.name.prefix(1)))
                    .foregroundColor(.white)
                    .font(.headline)
            )
        
        VStack(alignment: .leading) {
            Text(channel.name)
                .font(.headline)
            
            if let lastMsg = lastMessage(for: channel.id) {
                Text(lastMsg.text)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        
        Spacer()
        
        // 未读角标
        if unreadCount(for: channel.id) > 0 {
            Badge(count: unreadCount(for: channel.id))
        }
    }
}
```

#### Step 4：添加发起私聊功能

**文件**: `HChat/Views/Main/ChatsListView.swift`

```swift
// ChatsListView.swift

.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Menu {
            Button {
                showNewChannel = true
            } label: {
                Label("新建频道", systemImage: "number")
            }
            
            // ✨ 新增：发起私聊
            Button {
                showNewDM = true
            } label: {
                Label("发起私聊", systemImage: "person.fill.badge.plus")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
        }
    }
}
.sheet(isPresented: $showNewDM) {
    NewDMView(client: client)
}
```

**新建文件**: `HChat/Views/Main/NewDMView.swift`

```swift
import SwiftUI

struct NewDMView: View {
    let client: HackChatClient
    @Environment(\.dismiss) private var dismiss
    
    @State private var targetNickname = ""
    @State private var initialMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("发送给") {
                    TextField("输入对方昵称", text: $targetNickname)
                        .autocapitalization(.none)
                }
                
                Section("首条消息（可选）") {
                    TextField("输入消息", text: $initialMessage, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("发起私聊")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("开始") {
                        startDM()
                    }
                    .disabled(targetNickname.isEmpty)
                }
            }
        }
    }
    
    private func startDM() {
        // 发送私聊消息（会自动创建频道）
        if !initialMessage.isEmpty {
            client.commandHandler.handle(.dm(targetNickname, initialMessage))
        } else {
            // 只创建频道，不发消息
            let channel = "pm/\(targetNickname)"
            if !client.channels.contains(where: { $0.id == channel }) {
                client.state.addChannel(Channel(id: channel, name: targetNickname))
            }
            client.currentChannel = channel
        }
        
        dismiss()
    }
}
```

### 测试场景

#### 场景 1：发起新私聊

1. Alice 打开 App
2. 点击 "+" → "发起私聊"
3. 输入 "Bob"
4. 输入消息 "你好"
5. 点击 "开始"
6. 验证：
   - ✅ 创建了 `pm/Bob` 频道
   - ✅ 消息发送成功
   - ✅ 后端创建了 `dm:Alice:Bob` 虚拟频道

#### 场景 2：接收私聊

1. Bob 打开 App
2. Alice 发送私聊消息给 Bob
3. 验证：
   - ✅ Bob 自动创建 `pm/Alice` 频道
   - ✅ 消息显示在该频道中
   - ✅ 收到通知（如果在后台）

#### 场景 3：双向对话

1. Alice 和 Bob 互相发送消息
2. 验证：
   - ✅ Alice 看到 `pm/Bob` 频道
   - ✅ Bob 看到 `pm/Alice` 频道
   - ✅ 消息实时同步
   - ✅ 已读回执正常工作

### E2EE 支持

私聊消息的加密方式：

#### 选项 1：使用频道密钥（简单）

```swift
// 私聊频道使用双方共享的密钥
let dmChannel = "pm/Bob"
let sharedSecret = "\(myNick)#\(theirNick)#\(passphrase)"
let encryptor = E2EE.makeFrom(passphrase: sharedSecret, channelName: dmChannel)
```

**问题**：需要双方都知道相同的口令。

#### 选项 2：使用公钥加密（复杂但安全）

后续可以实现：
1. 每个用户生成 RSA 密钥对
2. 上传公钥到服务器
3. 发送私聊前，获取对方公钥
4. 使用对方公钥加密对称密钥
5. 使用对称密钥加密消息

**暂不实现**：先使用方案 1 的共享密钥。

### 优先级和时间估算

#### P0: 基础私聊（2-3 小时）

- [x] 后端支持 `dm` 消息类型
- [x] 虚拟频道创建和路由
- [x] iOS 端消息接收和显示
- [x] 基础 UI（频道列表分组）

#### P1: UI 优化（1-2 小时）

- [x] 发起私聊界面
- [x] 私聊头像和样式
- [x] 未读角标
- [x] 最后一条消息预览

#### P2: 高级功能（未来）

- [ ] 在线状态显示
- [ ] 输入指示器
- [ ] 私聊搜索
- [ ] 会话置顶

## 下一步

准备好了就开始实现吗？我可以帮你：

1. ✅ 修改后端 `chat-gateway`
2. ✅ 修改 iOS 消息处理逻辑
3. ✅ 创建私聊 UI
4. ✅ 测试端到端功能

预计时间：**2-3 小时**完成基础功能！

