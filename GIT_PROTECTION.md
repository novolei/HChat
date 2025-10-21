# 🛡️ HChat iOS Git 保护指南

本文档介绍如何使用 Git 工具保护 HChat iOS 代码，防止意外丢失。

---

## 📋 目录

- [快速开始](#快速开始)
- [工具说明](#工具说明)
- [最佳实践](#最佳实践)
- [常见场景](#常见场景)
- [故障恢复](#故障恢复)

---

## 🚀 快速开始

### 1️⃣ 添加执行权限（首次使用）

```bash
chmod +x git-backup.sh quick-save.sh
```

### 2️⃣ 日常开发流程

```bash
# 开始工作前 - 快速保存当前状态
./quick-save.sh "开始开发新功能"

# 做一些代码改动...
# 编辑 HChat/Core/HackChatClient.swift
# 编辑 HChat/UI/ChatView.swift

# 完成阶段性工作 - 正式提交
./git-backup.sh "修复 WebSocket 连接问题"

# 继续工作...

# 临时保存进度（不确定是否要提交）
./quick-save.sh "测试中的改动"
```

---

## 🔧 工具说明

### 📦 `git-backup.sh` - 正式备份工具

**用途：** 将改动正式提交到 Git 历史记录

**使用方法：**
```bash
# 交互式备份（会询问确认）
./git-backup.sh

# 带自定义消息
./git-backup.sh "修复了登录页面的 UI 问题"
```

**功能：**
- ✅ 显示所有改动文件
- ✅ 自动生成提交消息（包含时间戳和统计）
- ✅ 自动排除 HCChatBackEnd 独立仓库
- ✅ 确认后提交到 Git 历史
- ✅ 显示最近 3 次提交

**适用场景：**
- 完成一个功能或修复
- 代码可以正常编译运行
- 想要创建一个正式的版本记录点

---

### 💾 `quick-save.sh` - 快速保存工具

**用途：** 临时保存改动到 `git stash`（不影响 Git 历史）

**使用方法：**
```bash
# 快速保存（默认描述）
./quick-save.sh

# 带自定义描述
./quick-save.sh "测试新的加密方案"
```

**功能：**
- ✅ 保存所有改动（包括未跟踪文件）
- ✅ 不创建提交记录
- ✅ 可以随时恢复
- ✅ 支持多个保存点

**适用场景：**
- 临时切换分支
- 测试性改动（不确定是否保留）
- 快速清空工作区
- 创建"时光存档"以便回滚

**恢复方法：**
```bash
# 恢复最近一次保存
git stash pop

# 查看所有保存点
git stash list

# 恢复特定保存点
git stash apply stash@{1}

# 删除保存点
git stash drop stash@{0}
```

---

## 🎯 最佳实践

### 1. 工作前先保存

```bash
# 每次开始新任务前，保存当前状态
./quick-save.sh "开始前的状态"

# 然后开始编码
```

**好处：** 如果新改动不满意，可以快速回滚到起点

---

### 2. 阶段性提交

```bash
# 每完成一个小功能，就提交一次
./git-backup.sh "实现了聊天消息加密功能"

# 继续下一个功能
./git-backup.sh "添加了文件上传进度显示"
```

**好处：** 细粒度的版本控制，方便回溯和 cherry-pick

---

### 3. 每天结束前备份

```bash
# 下班前或每天工作结束时
./git-backup.sh "$(date '+%Y-%m-%d') 工作进度保存"

# 或快速保存
./quick-save.sh "$(date '+%Y-%m-%d') 下班前保存"
```

**好处：** 确保每天的工作都有记录

---

### 4. 实验性改动使用 stash

```bash
# 开始实验前
./quick-save.sh "实验前状态"

# 进行实验性改动...
# 如果成功，转为正式提交
./git-backup.sh "实验成功：新的消息渲染方式"

# 如果失败，恢复实验前状态
git stash pop  # 恢复
```

---

## 📚 常见场景

### 场景 1：修复 Bug

```bash
# 1. 保存当前进度
./quick-save.sh "开始修复 #123 bug"

# 2. 修复代码
# 编辑文件...

# 3. 测试通过后提交
./git-backup.sh "修复: WebSocket 重连逻辑错误 (#123)"
```

---

### 场景 2：开发新功能

```bash
# 1. 创建功能分支（可选）
git checkout -b feature/voice-call

# 2. 保存起点
./quick-save.sh "开始语音通话功能"

# 3. 分步提交
./git-backup.sh "实现语音通话 UI"
./git-backup.sh "集成 LiveKit SDK"
./git-backup.sh "添加音频权限处理"

# 4. 完成后合并到主分支
git checkout main
git merge feature/voice-call
```

---

### 场景 3：代码重构

```bash
# 1. 保存重构前的状态（重要！）
./git-backup.sh "重构前备份: HackChatClient"

# 2. 创建保护点
./quick-save.sh "重构起点"

# 3. 进行重构
# 修改文件结构...

# 4. 测试通过后提交
./git-backup.sh "重构: 简化 WebSocket 连接逻辑"
```

---

### 场景 4：临时切换任务

```bash
# 当前在开发功能 A，突然需要修复紧急 Bug

# 1. 保存功能 A 的进度
./quick-save.sh "功能 A 开发中"

# 2. 切换分支或修复 Bug
git checkout main
# 修复 bug...

# 3. 提交修复
./git-backup.sh "紧急修复: 崩溃问题"

# 4. 恢复功能 A 的进度
git stash list  # 找到保存点
git stash apply stash@{0}
```

---

## 🆘 故障恢复

### 情况 1：误删文件（刚刚删的）

```bash
# 方法 1: 从 stash 恢复（如果之前用了 quick-save）
git stash list
git stash show -p stash@{0}  # 查看内容
git stash pop

# 方法 2: 从最近的提交恢复
git checkout HEAD -- HChat/Core/HackChatClient.swift

# 方法 3: 从特定提交恢复
git log --oneline  # 找到提交 hash
git checkout <commit-hash> -- HChat/Core/HackChatClient.swift
```

---

### 情况 2：想撤销最近的改动

```bash
# 丢弃工作区所有改动（危险！先 quick-save）
git reset --hard HEAD

# 只撤销某个文件
git checkout -- HChat/UI/ChatView.swift

# 撤销最近一次提交（但保留改动）
git reset --soft HEAD^
```

---

### 情况 3：提交了不想要的改动

```bash
# 方法 1: 撤销最近一次提交
git reset --soft HEAD^  # 保留改动
git reset --hard HEAD^  # 丢弃改动

# 方法 2: 创建反向提交（推荐用于已推送的提交）
git revert <commit-hash>
```

---

### 情况 4：想回到某个历史版本

```bash
# 查看历史
git log --oneline --graph

# 创建新分支从该版本开始
git checkout -b recovery-branch <commit-hash>

# 或直接回退（危险！）
git reset --hard <commit-hash>
```

---

## 📊 查看历史

### 图形化日志

```bash
# 简洁图形
git log --oneline --graph --all

# 详细信息
git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'
```

### 查看改动

```bash
# 查看某次提交的改动
git show <commit-hash>

# 比较两个提交
git diff <commit1> <commit2>

# 查看文件历史
git log --follow -- HChat/Core/HackChatClient.swift
```

---

## 🔒 Git 配置说明

### .gitignore 规则

```
# 独立后端仓库（不纳入 iOS 项目 Git）
HCChatBackEnd/

# Xcode 生成文件
*.xcworkspace/xcshareddata/swiftpm/
xcuserdata/
DerivedData/

# macOS 系统文件
.DS_Store
```

### 检查配置

```bash
# 查看当前忽略的文件
git status --ignored

# 检查某个文件是否被忽略
git check-ignore -v HCChatBackEnd/docker-compose.yml
```

---

## 🌐 远程推送

### 推送到 GitHub

```bash
# 推送到远程仓库
git push origin main

# 强制推送（危险！确保知道自己在做什么）
git push --force origin main

# 推送所有分支和标签
git push --all origin
```

### 设置远程仓库

```bash
# 查看远程仓库
git remote -v

# 添加远程仓库
git remote add origin git@github.com:yourusername/HChat.git

# 更改远程 URL
git remote set-url origin git@github.com:yourusername/HChat.git
```

---

## ⚙️ 自动化配置

### 添加 Git Alias（可选）

编辑 `~/.gitconfig` 添加：

```ini
[alias]
    # 快捷命令
    st = status --short
    co = checkout
    br = branch
    ci = commit
    
    # 美化日志
    lg = log --oneline --graph --all --decorate
    
    # 查看改动
    d = diff
    ds = diff --staged
    
    # 撤销
    undo = reset --soft HEAD^
    unstage = reset HEAD --
```

使用：
```bash
git st        # 等同于 git status --short
git lg        # 美化的日志
git undo      # 撤销最近提交
```

---

## 💡 提示和技巧

### 1. 定期查看状态

```bash
# 养成习惯：经常查看当前状态
git status

# 或使用工具脚本
./git-backup.sh  # 会先显示状态
```

### 2. 提交信息规范

推荐格式：
```
类型: 简短描述

详细说明（可选）
```

类型：
- `✨ 新增`: 新功能
- `🐛 修复`: Bug 修复
- `♻️ 重构`: 代码重构
- `📝 文档`: 文档更新
- `🎨 样式`: UI/样式调整
- `⚡️ 性能`: 性能优化
- `✅ 测试`: 添加测试
- `🔧 配置`: 配置文件修改

示例：
```bash
./git-backup.sh "✨ 新增: 语音消息录制功能"
./git-backup.sh "🐛 修复: WebSocket 重连失败问题 (#123)"
```

### 3. 使用分支隔离风险

```bash
# 开发新功能时创建分支
git checkout -b feature/new-ui

# 测试通过后合并
git checkout main
git merge feature/new-ui

# 删除分支
git branch -d feature/new-ui
```

---

## 📞 获取帮助

- 查看工具帮助：`./git-backup.sh --help`（如有实现）
- Git 文档：`git help <command>`
- 在线资源：https://git-scm.com/doc

---

**记住：经常备份，小步提交，永不丢失！** 🚀

