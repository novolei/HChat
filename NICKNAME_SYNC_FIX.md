# 🔧 昵称同步功能修复

**日期：** 2025-10-21  
**问题：** 在线用户列表显示的都是 "iOSUser"，昵称修改后没有同步到服务器  
**状态：** ✅ 已完全修复

---

## 🐛 问题描述

用户报告的问题：

1. **首次启动没有提示设置昵称**
   - 用户不知道如何修改昵称
   - 默认使用 "iOSUser"

2. **昵称修改后没有同步**
   - 执行 `/nick newName` 后，只更新了本地
   - 服务器端的 `ws.nick` 仍然是 "iOSUser"
   - 在线用户列表显示：`{"type":"presence","room":"lobby","users":["iOSUser","iOSUser"],"count":2}`

3. **其他用户看不到新昵称**
   - 昵称变更没有广播
   - 所有人显示的都是默认昵称

---

## 🔍 问题分析

### 根本原因

1. **客户端问题（iOS）**
   ```swift
   // ❌ 问题代码
   case .nick(let name):
       myNick = name  // 只更新本地
       // 没有发送到服务器！
       systemMessage("昵称已更新为 \(name)")
   ```

2. **没有持久化**
   - 昵称使用简单变量 `var myNick: String = "iOSUser"`
   - 每次启动都重置为默认值

3. **没有首次启动提示**
   - 用户不知道需要设置昵称
   - 没有引导流程

---

## ✅ 解决方案

### 1️⃣ 昵称持久化

**使用 UserDefaults 保存昵称：**

```swift
var myNick: String {
    get {
        UserDefaults.standard.string(forKey: "myNick") ?? "iOSUser"
    }
    set {
        UserDefaults.standard.set(newValue, forKey: "myNick")
    }
}
```

**效果：**
- ✅ 昵称会保存到本地
- ✅ 重启 App 后保持昵称
- ✅ 自动加载上次设置的昵称

---

### 2️⃣ 昵称同步到服务器

**修复 `/nick` 命令处理：**

```swift
case .nick(let name):
    myNick = name
    // ✅ 发送 nick 命令到服务器，同步昵称
    send(json: ["type":"nick", "nick": name])
    DebugLogger.log("👤 发送昵称变更到服务器: \(name)", level: .websocket)
    
    if let pass = CommandParser.extractPassphrase(fromNick: name) {
        passphraseForEndToEndEncryption = pass
        systemMessage("E2EE 群口令已更新")
    } else {
        systemMessage("昵称已更新为 \(name)")
    }
```

**新增公共方法：**

```swift
/// 修改昵称（用于UI调用，会同步到服务器）
func changeNick(_ newNick: String) {
    let trimmedNick = newNick.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedNick.isEmpty else {
        systemMessage("昵称不能为空")
        return
    }
    
    myNick = trimmedNick
    send(json: ["type":"nick", "nick": trimmedNick])
    DebugLogger.log("👤 修改昵称: \(trimmedNick)", level: .websocket)
    systemMessage("昵称已更新为 \(trimmedNick)")
}
```

**效果：**
- ✅ 昵称修改立即发送到服务器
- ✅ 服务器更新 `ws.nick`
- ✅ 服务器广播昵称变更给其他用户

---

### 3️⃣ 首次启动提示

**添加检测属性：**

```swift
var shouldShowNicknamePrompt: Bool {
    myNick == "iOSUser" || myNick.hasPrefix("iOSUser")
}
```

**UI 提示：**

```swift
.alert("设置您的昵称", isPresented: $showNicknamePrompt) {
    TextField("输入昵称", text: $nicknameInput)
    Button("确定") {
        if !nicknameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            client.changeNick(nicknameInput)
        }
    }
    Button("取消", role: .cancel) { }
} message: {
    Text("欢迎使用 HChat！请设置一个昵称，其他用户将看到这个名字。")
}
.onAppear {
    NotificationManager.shared.configure()
    
    // ✅ 首次启动时提示设置昵称
    if client.shouldShowNicknamePrompt {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showNicknamePrompt = true
        }
    }
}
```

**效果：**
- ✅ 首次启动时自动弹出昵称设置对话框
- ✅ 引导用户设置个性化昵称
- ✅ 提升用户体验

---

### 4️⃣ 工具栏快捷入口

**添加昵称修改菜单：**

```swift
ToolbarItem(placement: .navigationBarTrailing) {
    Menu {
        Button {
            nicknameInput = client.myNick
            showNicknamePrompt = true
        } label: {
            Label("修改昵称 (\(client.myNick))", systemImage: "person.circle")
        }
        
        Divider()
        
        Button {
            showCallSheet = true
        } label: {
            Label("发起语音通话", systemImage: "phone.arrow.up.right")
        }
    } label: {
        Image(systemName: "ellipsis.circle")
    }
}
```

**效果：**
- ✅ 用户可以随时修改昵称
- ✅ 工具栏显示当前昵称
- ✅ 快捷访问常用功能

---

## 🎯 服务器端（已有功能）

**服务器端的 `nick` 命令处理（已经正确实现）：**

```javascript
// 处理 nick 命令
if (msgType === 'nick' && msg.nick) {
  const oldNick = ws.nick || 'guest';
  const newNick = msg.nick;
  ws.nick = newNick;  // ✅ 更新服务器端昵称
  
  // 如果用户已加入频道，广播昵称变更通知
  if (ws.channel && oldNick !== newNick) {
    broadcast(ws.channel, {
      type: 'nick_change',
      oldNick: oldNick,
      newNick: newNick,
      channel: ws.channel
    });
  }
  
  // 发送确认消息给当前用户
  if (ws.readyState === 1) {
    try {
      ws.send(JSON.stringify({ 
        type: 'info', 
        text: `昵称已更改为 ${newNick}` 
      }));
    } catch (err) {
      console.error('send nick confirmation error:', err.message);
    }
  }
  return;
}

// 处理 who 命令（在线用户列表）
if (msgType === 'who' && ws.channel) {
  const users = Array.from(rooms.get(ws.channel) || []).map(c => c.nick || 'guest');
  // ✅ 返回正确的昵称列表
  ws.send(JSON.stringify({ 
    type: 'presence', 
    room: ws.channel, 
    users, 
    count: users.length 
  }));
}
```

**服务器端已经支持：**
- ✅ 接收 `nick` 命令并更新 `ws.nick`
- ✅ 广播昵称变更给频道所有用户
- ✅ `who` 命令返回正确的昵称列表

---

## 📊 修复效果

### 修复前 ❌

```json
{
  "type": "presence",
  "room": "lobby",
  "users": ["iOSUser", "iOSUser", "iOSUser"],
  "count": 3
}
```

**问题：**
- ❌ 所有用户都显示 "iOSUser"
- ❌ 无法区分不同用户
- ❌ 用户不知道如何修改昵称

### 修复后 ✅

```json
{
  "type": "presence",
  "room": "lobby",
  "users": ["Alice", "Bob", "Charlie"],
  "count": 3
}
```

**效果：**
- ✅ 首次启动提示设置昵称
- ✅ 昵称持久化保存
- ✅ 昵称自动同步到服务器
- ✅ 其他用户看到正确的昵称
- ✅ 工具栏可随时修改昵称

---

## 🧪 测试步骤

### 1. 首次启动测试

1. **删除 App 或清除数据**
2. **重新安装并启动**
3. **预期：** 自动弹出昵称设置对话框
4. **输入昵称：** 例如 "Alice"
5. **点击确定**
6. **预期：** 看到系统消息 "昵称已更新为 Alice"

### 2. 昵称同步测试

1. **用户 A 设置昵称为 "Alice"**
2. **用户 B 设置昵称为 "Bob"**
3. **两个用户都加入同一频道（lobby）**
4. **查看在线用户列表**
5. **预期：** `{"users":["Alice","Bob"],"count":2}`

### 3. 昵称修改测试

**方式 1：命令行**
```
/nick NewName
```

**方式 2：工具栏菜单**
1. 点击右上角 `⋯` 按钮
2. 选择 "修改昵称 (Alice)"
3. 输入新昵称 "Alice2"
4. 点击确定

**预期：**
- ✅ 本地昵称立即更新
- ✅ 服务器收到 `nick` 命令
- ✅ 服务器更新 `ws.nick`
- ✅ 广播昵称变更给其他用户
- ✅ 其他用户看到新昵称

### 4. 持久化测试

1. **设置昵称为 "TestUser"**
2. **完全关闭 App**
3. **重新打开 App**
4. **预期：** 昵称仍然是 "TestUser"，不会弹出设置提示

---

## 🔄 完整流程

### 首次使用流程

```
1. 用户首次打开 App
   ↓
2. 检测到昵称为默认值 "iOSUser"
   ↓
3. 自动弹出昵称设置对话框
   ↓
4. 用户输入昵称（如 "Alice"）
   ↓
5. 点击确定
   ↓
6. 昵称保存到 UserDefaults
   ↓
7. 发送 nick 命令到服务器
   ↓
8. 服务器更新 ws.nick = "Alice"
   ↓
9. 连接已建立，用户正常使用
   ↓
10. 其他用户执行 /who 看到 "Alice"
```

### 昵称修改流程

```
1. 用户点击工具栏菜单
   ↓
2. 选择 "修改昵称 (Alice)"
   ↓
3. 修改为 "Alice2"
   ↓
4. 点击确定
   ↓
5. 调用 client.changeNick("Alice2")
   ↓
6. 更新 UserDefaults
   ↓
7. 发送 {"type":"nick", "nick":"Alice2"}
   ↓
8. 服务器更新 ws.nick = "Alice2"
   ↓
9. 服务器广播昵称变更
   ↓
10. 其他用户收到 nick_change 消息
```

---

## 📝 修改文件清单

### iOS 客户端

1. **`HChat/Core/HackChatClient.swift`**
   - ✅ `myNick` 改为计算属性，使用 UserDefaults
   - ✅ 新增 `shouldShowNicknamePrompt` 属性
   - ✅ 新增 `changeNick()` 公共方法
   - ✅ 修复 `.nick` 命令处理，添加服务器同步

2. **`HChat/UI/ChatView.swift`**
   - ✅ 新增 `@State private var showNicknamePrompt`
   - ✅ 新增 `@State private var nicknameInput`
   - ✅ 添加 `.alert` 昵称设置对话框
   - ✅ `onAppear` 中添加首次启动检测
   - ✅ 工具栏添加昵称修改菜单

### 后端（无需修改）

**服务器端已经正确实现了昵称处理，无需修改。**

---

## 💡 最佳实践

### 昵称设置建议

1. **长度限制**
   ```swift
   guard trimmedNick.count >= 2 && trimmedNick.count <= 20 else {
       systemMessage("昵称长度应为 2-20 个字符")
       return
   }
   ```

2. **字符限制**
   ```swift
   let allowedChars = CharacterSet.alphanumerics
       .union(.init(charactersIn: "_-"))
   guard trimmedNick.rangeOfCharacter(from: allowedChars.inverted) == nil else {
       systemMessage("昵称只能包含字母、数字、下划线和连字符")
       return
   }
   ```

3. **敏感词过滤**
   ```swift
   let bannedWords = ["admin", "system", "guest"]
   guard !bannedWords.contains(trimmedNick.lowercased()) else {
       systemMessage("该昵称不可用")
       return
   }
   ```

### 服务器端增强（可选）

1. **唯一性检查**
   ```javascript
   // 检查昵称是否已被使用
   const existingUser = Array.from(rooms.get(ws.channel) || [])
       .find(c => c.nick === newNick && c !== ws);
   
   if (existingUser) {
       ws.send(JSON.stringify({ 
           type: 'error', 
           text: `昵称 ${newNick} 已被使用` 
       }));
       return;
   }
   ```

2. **昵称历史记录**
   ```javascript
   if (!ws.nickHistory) ws.nickHistory = [];
   if (ws.nick) ws.nickHistory.push(ws.nick);
   ```

---

## 🎉 总结

### 主要成果

1. ✅ **昵称持久化** - 使用 UserDefaults 保存
2. ✅ **首次启动引导** - 自动提示设置昵称
3. ✅ **服务器同步** - 昵称修改立即发送到服务器
4. ✅ **实时更新** - 其他用户看到正确的昵称
5. ✅ **便捷修改** - 工具栏快捷入口

### 用户体验提升

| 方面 | 修改前 | 修改后 |
|------|--------|--------|
| 首次使用 | 不知道如何设置昵称 | 自动提示设置 ✅ |
| 昵称显示 | 都是 "iOSUser" | 个性化昵称 ✅ |
| 昵称同步 | 只在本地 | 实时同步到服务器 ✅ |
| 修改昵称 | 只能用命令 | 工具栏菜单 + 命令 ✅ |
| 持久化 | 每次重启重置 | 自动保存和加载 ✅ |

---

**🎉 昵称同步功能已完全修复！用户体验大幅提升！** ✅

