#!/bin/bash
# 修复 VPS 上的 Git 冲突并更新 chat-gateway

cat << 'EOF'
╔════════════════════════════════════════╗
║   🔧 VPS Git 冲突修复脚本             ║
╚════════════════════════════════════════╝

请在 VPS 上执行以下命令：

EOF

echo "# 1️⃣ 查看本地修改"
echo "cd /root/hc-stack"
echo "git status"
echo "git diff chat-gateway/server.js"
echo ""

echo "# 2️⃣ 保存本地修改（如果有重要内容）"
echo "git stash save 'VPS 本地临时修改'"
echo ""

echo "# 3️⃣ 拉取最新代码"
echo "git pull origin main"
echo ""

echo "# 4️⃣ 重启服务"
echo "docker compose restart chat-gateway"
echo ""

echo "# 5️⃣ 查看日志"
echo "docker compose logs -f chat-gateway"
echo ""

cat << 'EOF'
═══════════════════════════════════════════

💡 提示：
- 如果本地修改不重要，可以直接丢弃：
  git checkout -- chat-gateway/server.js
  git pull origin main

- 如果需要恢复 stash 的内容：
  git stash list
  git stash pop

═══════════════════════════════════════════
EOF

