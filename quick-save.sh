#!/bin/bash
# ===== HChat iOS 快速保存脚本 =====
# 一键保存所有改动到 git stash
# 使用方法：./quick-save.sh [可选描述]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

# 检查是否有改动
if git diff-index --quiet HEAD -- 2>/dev/null && [ "$(git ls-files --others --exclude-standard | wc -l)" -eq 0 ]; then
    echo -e "${GREEN}✅ 没有需要保存的改动${NC}"
    exit 0
fi

# 获取保存描述
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
if [ -n "$1" ]; then
    DESCRIPTION="$1"
else
    DESCRIPTION="iOS 代码快速保存"
fi

STASH_MSG="💾 $DESCRIPTION @ $TIMESTAMP"

echo -e "${BLUE}═════════════════════════════════════════${NC}"
echo -e "${BLUE}  快速保存到 Git Stash${NC}"
echo -e "${BLUE}═════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}📊 当前改动:${NC}"
git status --short
echo ""

# 包含未跟踪文件
echo -e "${BLUE}💾 保存到 stash: ${NC}$STASH_MSG"
git stash save --include-untracked "$STASH_MSG"

echo ""
echo -e "${GREEN}✅ 保存成功！${NC}"
echo ""
echo -e "${BLUE}当前 stash 列表:${NC}"
git stash list | head -5
echo ""
echo -e "${YELLOW}💡 提示:${NC}"
echo -e "   • 恢复最近保存: ${GREEN}git stash pop${NC}"
echo -e "   • 查看 stash 内容: ${GREEN}git stash show -p stash@{0}${NC}"
echo -e "   • 删除 stash: ${GREEN}git stash drop stash@{0}${NC}"
echo -e "${BLUE}═════════════════════════════════════════${NC}"

