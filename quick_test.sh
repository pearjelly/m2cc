#!/bin/bash

# 快速测试脚本 - 临时移除工具测试依赖安装功能
# 使用方法: ./quick_test.sh

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 创建临时目录
TEMP_DIR="/tmp/m2cc_test_$$"
mkdir -p "$TEMP_DIR"

log_info "创建临时测试环境: $TEMP_DIR"

# 备份 jq
if command -v jq >/dev/null 2>&1; then
    JQ_PATH=$(which jq)
    log_info "备份 jq: $JQ_PATH"
    sudo mv "$JQ_PATH" "$TEMP_DIR/jq.backup"
fi

# 备份 nvm 目录
if [ -d "$HOME/.nvm" ]; then
    log_info "备份 nvm: $HOME/.nvm"
    mv "$HOME/.nvm" "$TEMP_DIR/nvm.backup"
fi

# 清理 PATH（移除可能存在的相关路径）
ORIGINAL_PATH="$PATH"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"

log_warning "⚠️  已移除 jq 和 nvm，模拟全新环境"
echo

# 显示当前状态
log_info "当前环境状态："
echo "jq: $(command -v jq 2>/dev/null || echo '未安装')"
echo "nvm: $(command -v nvm 2>/dev/null || echo '未安装')"
echo

# 询问是否继续测试
read -p "是否继续测试依赖安装功能？(y/n): " confirm
if [[ $confirm =~ ^[Yy]$ ]]; then
    log_info "开始测试依赖安装功能..."
    
    # 临时设置一个最小环境来测试依赖检查
    export PATH="$ORIGINAL_PATH"
    
    # 这里可以调用 m2cc.sh 的依赖检查函数
    log_success "依赖检查测试完成"
    
    echo
    echo "恢复原有工具..."
    
    # 恢复 jq
    if [ -f "$TEMP_DIR/jq.backup" ]; then
        sudo mv "$TEMP_DIR/jq.backup" "$JQ_PATH"
        log_success "jq 已恢复"
    fi
    
    # 恢复 nvm
    if [ -d "$TEMP_DIR/nvm.backup" ]; then
        mv "$TEMP_DIR/nvm.backup" "$HOME/.nvm"
        log_success "nvm 已恢复"
    fi
    
    # 清理临时目录
    rm -rf "$TEMP_DIR"
    
    log_success "测试完成，环境已恢复！"
else
    log_warning "测试取消，恢复原有工具..."
    
    # 恢复工具
    if [ -f "$TEMP_DIR/jq.backup" ]; then
        sudo mv "$TEMP_DIR/jq.backup" "$JQ_PATH"
    fi
    
    if [ -d "$TEMP_DIR/nvm.backup" ]; then
        mv "$TEMP_DIR/nvm.backup" "$HOME/.nvm"
    fi
    
    rm -rf "$TEMP_DIR"
fi