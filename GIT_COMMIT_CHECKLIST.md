# ✅ Git 提交前检查清单

**重要原则：** 提交前必须确保编译无误，不遗留问题！

---

## 📋 提交前检查流程

### 1️⃣ 代码检查

#### iOS/Swift 代码

```bash
# 检查 linter 错误
read_lints([
  "HChat/Core/HackChatClient.swift",
  "HChat/UI/ChatView.swift",
  "HChat/App/HChatApp.swift"
  # ... 所有修改的文件
])
```

**必须确认：**
- ✅ No linter errors found
- ✅ 没有语法错误
- ✅ 没有类型错误
- ✅ 没有未解析的引用

#### 后端/JavaScript 代码

```bash
# 检查 JavaScript 语法
cd HCChatBackEnd/chat-gateway
node -c server.js  # 检查语法

cd HCChatBackEnd/message-service
node -c server.js  # 检查语法
```

---

### 2️⃣ 构建测试（可选但推荐）

#### iOS 项目

在 Xcode 中：
```
Product → Build (Command + B)
```

**或者命令行：**
```bash
cd /Users/ryanliu/DDCS/HChat
xcodebuild -project HChat.xcodeproj -scheme HChat -destination 'platform=iOS Simulator,name=iPhone 15' build
```

#### 后端服务

```bash
# 测试服务启动
cd HCChatBackEnd/chat-gateway
npm install
node server.js
# 确认能正常启动

cd HCChatBackEnd/message-service
npm install
node server.js
# 确认能正常启动
```

---

### 3️⃣ Git 提交

**只有在确认编译通过后才执行：**

```bash
git add -A
git status --short  # 检查要提交的文件
git commit -m "commit message"
```

---

## 🚫 禁止的操作

### ❌ 错误的做法

```bash
# ❌ 直接提交，不检查编译
git add -A
git commit -m "fix something"
git push

# 结果：可能提交了有编译错误的代码
```

---

## ✅ 正确的流程

### ✅ 标准做法

```bash
# 1. 修改代码
# ... 编辑文件 ...

# 2. 检查 linter（iOS）
read_lints(["修改的文件列表"])

# 3. 检查语法（后端）
node -c server.js

# 4. 确认无误后提交
git add -A
git commit -m "commit message"
git push
```

---

## 📝 AI 助手的工作流程

### 未来的提交流程

1. **修改代码**
   - 使用 search_replace 或 write 工具

2. **立即检查编译**
   ```python
   read_lints(paths=[所有修改的文件])
   ```

3. **发现错误时**
   - 立即修复
   - 重新检查
   - 直到没有错误

4. **确认无误后提交**
   ```python
   run_terminal_cmd("git add -A && git commit -m '...'")
   ```

5. **向用户报告**
   - ✅ 编译检查通过
   - ✅ 已提交到 Git
   - 📝 提交信息

---

## 🎯 检查清单

提交前必须确认：

- [ ] 所有修改的 Swift 文件通过 linter 检查
- [ ] 所有修改的 JS 文件语法正确
- [ ] 没有未解析的引用或类型错误
- [ ] 提交信息清晰描述了改动内容
- [ ] 相关文档已更新

**只有全部勾选后才能提交！**

---

## 💡 最佳实践

### 1. 小步提交

```bash
# ✅ 好的做法：每个功能单独提交
git commit -m "feat: 添加昵称持久化"
# 检查编译
git commit -m "feat: 添加昵称同步到服务器"
# 检查编译
git commit -m "feat: 添加首次启动提示"
# 检查编译
```

```bash
# ❌ 不好的做法：一次提交所有改动
git commit -m "feat: 添加很多功能"
# 没检查编译，可能有多个问题
```

---

### 2. 提交前自测

```bash
# iOS 项目
1. Command + B (Build)
2. Command + R (Run)
3. 测试新功能
4. 确认无误后提交

# 后端项目
1. npm install
2. node server.js
3. 测试 API
4. 确认无误后提交
```

---

### 3. 使用 Git Hooks（可选）

**`.git/hooks/pre-commit`** (未来可以添加)

```bash
#!/bin/bash

echo "🔍 检查代码..."

# 检查 Swift 文件
swift_files=$(git diff --cached --name-only --diff-filter=ACM | grep ".swift$")
if [ -n "$swift_files" ]; then
    echo "检查 Swift 文件..."
    # 这里可以添加 swiftlint 检查
fi

# 检查 JS 文件
js_files=$(git diff --cached --name-only --diff-filter=ACM | grep ".js$")
if [ -n "$js_files" ]; then
    echo "检查 JavaScript 文件..."
    for file in $js_files; do
        node -c "$file" || exit 1
    done
fi

echo "✅ 检查通过！"
```

---

## 🔍 常见问题

### Q: 如果发现提交后有编译错误怎么办？

**A: 立即修复并提交修复：**

```bash
# 1. 修复错误
# ... 编辑文件 ...

# 2. 检查编译
read_lints([修改的文件])

# 3. 提交修复
git add -A
git commit -m "fix: 修复编译错误"

# 4. 如果还没推送到远程，可以修改上一次提交
git add -A
git commit --amend --no-edit
```

---

### Q: 如何检查整个项目是否能编译？

**A: iOS 项目：**

```bash
# 在 Xcode 中
Product → Clean Build Folder (Shift + Command + K)
Product → Build (Command + B)

# 或命令行
xcodebuild clean
xcodebuild build
```

**A: 后端项目：**

```bash
cd HCChatBackEnd/chat-gateway
npm install
npm test  # 如果有测试

cd HCChatBackEnd/message-service
npm install
npm test  # 如果有测试
```

---

### Q: linter 检查通过，但 Xcode 编译失败怎么办？

**A: Linter 只检查语法，不检查类型和依赖**

```bash
# 需要在 Xcode 中查看详细错误
Product → Build (Command + B)
# 查看 Issue Navigator (Command + 5)
# 查看具体错误信息并修复
```

---

## 📚 相关文档

- **[Git 工作流程](UPDATE_VPS.md)** - VPS 更新和部署
- **[AI 智能部署](HCChatBackEnd/AI_DEPLOY_GUIDE.md)** - 后端自动化部署
- **[调试指南](DEBUGGING.md)** - 问题排查

---

## 🎉 总结

### 核心原则

**永远不要提交无法编译的代码！**

1. ✅ 修改代码后立即检查
2. ✅ 发现错误立即修复
3. ✅ 确认无误后再提交
4. ✅ 保持代码库始终可编译

### 用户期望

- ✅ 每个 commit 都是可编译的
- ✅ 问题不会遗留到下一个版本
- ✅ 回滚到任何 commit 都能运行
- ✅ 团队协作更顺畅

---

**🎯 记住：编译检查是提交的前提条件，不是可选项！** ✅

