#!/bin/bash
# ===== HChat iOS Git 备份脚本 =====
# 用于定期保存 iOS 代码改动
# 使用方法：./git-backup.sh [可选消息]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

echo -e "${BLUE}═════════════════════════════════════════${NC}"
echo -e "${BLUE}  HChat iOS 代码备份工具${NC}"
echo -e "${BLUE}═════════════════════════════════════════${NC}"
echo ""

# 检查是否在正确的目录
if [ ! -f "HChat.xcodeproj/project.pbxproj" ]; then
    echo -e "${RED}❌ 错误: 未找到 HChat.xcodeproj${NC}"
    echo -e "${RED}   请在项目根目录运行此脚本${NC}"
    exit 1
fi

# 检查 git 状态
echo -e "${YELLOW}📊 检查 Git 状态...${NC}"
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    HAS_CHANGES=true
else
    HAS_CHANGES=false
fi

# 检查未跟踪文件
UNTRACKED=$(git ls-files --others --exclude-standard | wc -l | tr -d ' ')

if [ "$HAS_CHANGES" = false ] && [ "$UNTRACKED" -eq 0 ]; then
    echo -e "${GREEN}✅ 没有需要备份的改动${NC}"
    echo ""
    git status --short
    exit 0
fi

echo -e "${YELLOW}⚠️  发现以下改动:${NC}"
echo ""
git status --short
echo ""

# 获取备份消息
if [ -n "$1" ]; then
    BACKUP_MSG="$1"
else
    # 自动生成消息
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    MODIFIED=$(git diff --name-only | wc -l | tr -d ' ')
    STAGED=$(git diff --cached --name-only | wc -l | tr -d ' ')
    
    BACKUP_MSG="💾 自动备份 iOS 代码 @ $TIMESTAMP"
    [ "$MODIFIED" -gt 0 ] && BACKUP_MSG="$BACKUP_MSG (修改: $MODIFIED 文件)"
    [ "$STAGED" -gt 0 ] && BACKUP_MSG="$BACKUP_MSG (暂存: $STAGED 文件)"
    [ "$UNTRACKED" -gt 0 ] && BACKUP_MSG="$BACKUP_MSG (新增: $UNTRACKED 文件)"
fi

echo -e "${YELLOW}📝 备份消息:${NC} $BACKUP_MSG"
echo ""

# 询问确认
read -p "$(echo -e ${GREEN}是否继续备份? [Y/n]: ${NC})" -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    # 添加所有改动（排除 HCChatBackEnd）
    echo -e "${BLUE}📦 添加文件到 Git...${NC}"
    git add -A
    
    # 移除 HCChatBackEnd（如果误添加）
    if git ls-files --cached | grep -q "^HCChatBackEnd/"; then
        echo -e "${YELLOW}🚫 移除 HCChatBackEnd（独立仓库）${NC}"
        git reset HEAD HCChatBackEnd/ 2>/dev/null || true
    fi
    
    # 提交
    echo -e "${BLUE}💾 提交改动...${NC}"
    git commit -m "$BACKUP_MSG"
    
    echo ""
    echo -e "${GREEN}✅ 备份成功！${NC}"
    echo ""
    echo -e "${BLUE}最近 3 次提交:${NC}"
    git log --oneline -3
    echo ""
    echo -e "${YELLOW}💡 提示:${NC}"
    echo -e "   • 推送到远程: ${GREEN}git push${NC}"
    echo -e "   • 查看历史: ${GREEN}git log --oneline${NC}"
    echo -e "   • 恢复提交: ${GREEN}git revert <commit>${NC}"
else
    echo -e "${YELLOW}⏸️  备份已取消${NC}"
    exit 0
fi

echo -e "${BLUE}═════════════════════════════════════════${NC}"

