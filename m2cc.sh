#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 日志函数
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

# 依赖检查和环境准备函数

# 检查基本系统依赖
check_basic_dependencies() {
    log_info "🔍 检查系统基础依赖..."

    local missing_deps=()
    local available_commands=()

    # 检查 curl 或 wget（用于下载）
    if check_command "curl"; then
        available_commands+=("curl")
        log_success "✓ curl 已安装"
    elif check_command "wget"; then
        available_commands+=("wget")
        log_success "✓ wget 已安装"
    else
        missing_deps+=("download_tool")
        log_error "❌ 需要 curl 或 wget 来下载依赖"
    fi

    # 检查 jq（用于 JSON 处理）
    if check_command "jq"; then
        log_success "✓ jq 已安装"
    else
        missing_deps+=("jq")
        log_warning "⚠ jq 未安装，将自动安装"
    fi

    # 检查 nvm（用于 Node.js 版本管理）
    if check_nvm; then
        log_success "✓ nvm 已安装"
    else
        missing_deps+=("nvm")
        log_warning "⚠ nvm 未安装，将自动安装"
    fi

    # 返回缺失的依赖列表
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "${missing_deps[@]}"
        return 1
    else
        log_success "✓ 所有基础依赖已就绪"
        return 0
    fi
}

# 智能安装 jq（下载二进制文件方式）
install_jq_manually() {
    log_info "正在安装 jq..."

    local temp_dir="/tmp/jq_install"
    local jq_version="jq-1.6"
    local jq_binary="jq-osx-amd64"
    local install_path="/usr/local/bin/jq"

    # 创建临时目录
    mkdir -p "$temp_dir"
    cd "$temp_dir"

    # 检测系统架构
    local arch=$(uname -m)
    case $arch in
        "x86_64")
            jq_binary="jq-osx-amd64"
            ;;
        "arm64"|"aarch64")
            jq_binary="jq-osx-arm64"
            ;;
        *)
            log_error "不支持的系统架构: $arch"
            rm -rf "$temp_dir"
            return 1
            ;;
    esac

    # 尝试从 GitHub 下载 jq
    if check_command "curl"; then
        log_info "正在从 GitHub 下载 jq..."
        if curl -L "https://github.com/jqlang/jq/releases/download/${jq_version}/${jq_binary}" -o jq; then
            chmod +x jq
            if sudo mv jq "$install_path" 2>/dev/null; then
                log_success "✓ jq 安装成功: $install_path"
            else
                # 尝试无 sudo 安装到用户目录
                local user_bin="$HOME/bin"
                mkdir -p "$user_bin"
                mv jq "$user_bin/jq"
                export PATH="$user_bin:$PATH"
                log_success "✓ jq 安装成功: $user_bin/jq"
            fi
        else
            log_error "jq 下载失败，请检查网络连接"
            cd - > /dev/null
            rm -rf "$temp_dir"
            return 1
        fi
    elif check_command "wget"; then
        log_info "正在从 GitHub 下载 jq..."
        if wget -O jq "https://github.com/jqlang/jq/releases/download/${jq_version}/${jq_binary}"; then
            chmod +x jq
            if sudo mv jq "$install_path" 2>/dev/null; then
                log_success "✓ jq 安装成功: $install_path"
            else
                local user_bin="$HOME/bin"
                mkdir -p "$user_bin"
                mv jq "$user_bin/jq"
                export PATH="$user_bin:$PATH"
                log_success "✓ jq 安装成功: $user_bin/jq"
            fi
        else
            log_error "jq 下载失败，请检查网络连接"
            cd - > /dev/null
            rm -rf "$temp_dir"
            return 1
        fi
    else
        log_error "需要 curl 或 wget 来下载 jq"
        cd - > /dev/null
        rm -rf "$temp_dir"
        return 1
    fi

    # 清理临时文件
    cd - > /dev/null
    rm -rf "$temp_dir"

    # 验证安装
    if check_command "jq"; then
        local jq_ver=$(jq --version)
        log_success "✓ jq 验证成功: $jq_ver"
        return 0
    else
        log_error "jq 安装验证失败"
        return 1
    fi
}

# 安全安装 nvm
install_nvm_safely() {
    log_info "正在安装 NVM (Node Version Manager)..."

    local nvm_version="v0.39.7"
    local nvm_install_script="https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh"

    # 确保 NVM_DIR 存在
    export NVM_DIR="$HOME/.nvm"

    # 检查网络连接
    log_info "正在测试网络连接..."
    if ! ping -c 1 raw.githubusercontent.com &>/dev/null; then
        log_error "网络连接失败，请检查网络设置"
        return 1
    fi

    # 下载并安装 nvm
    if check_command "curl"; then
        log_info "正在下载并安装 NVM..."
        if curl -o- "$nvm_install_script" | bash; then
            log_success "✓ NVM 下载成功"
        else
            log_error "NVM 下载失败"
            return 1
        fi
    elif check_command "wget"; then
        log_info "正在下载并安装 NVM..."
        if wget -qO- "$nvm_install_script" | bash; then
            log_success "✓ NVM 下载成功"
        else
            log_error "NVM 下载失败"
            return 1
        fi
    else
        log_error "需要 curl 或 wget 来安装 NVM"
        return 1
    fi

    # 确保 nvm 可用
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        \. "$NVM_DIR/nvm.sh"
        log_success "✓ NVM 加载成功"
    else
        log_error "NVM 安装文件未找到"
        return 1
    fi

    # 验证安装
    if command -v nvm >/dev/null 2>&1; then
        local nvm_ver=$(nvm --version)
        log_success "✓ NVM 安装成功: $nvm_ver"
        return 0
    else
        log_error "NVM 安装验证失败"
        return 1
    fi
}

# Shell 检测和配置更新
detect_and_update_shell() {
    log_info "正在检测和更新 Shell 配置..."

    local current_shell=$(basename "$SHELL")
    local config_files=()

    case $current_shell in
        "bash")
            config_files+=("$HOME/.bashrc")
            config_files+=("$HOME/.bash_profile")
            config_files+=("$HOME/.profile")
            ;;
        "zsh")
            config_files+=("$HOME/.zshrc")
            config_files+=("$HOME/.zprofile")
            ;;
        *)
            # 通用处理
            config_files+=("$HOME/.bashrc")
            config_files+=("$HOME/.zshrc")
            config_files+=("$HOME/.profile")
            ;;
    esac

    # 添加 nvm 配置到配置文件
    local nvm_config='
# NVM Configuration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
'

    local updated_files=0
    for config_file in "${config_files[@]}"; do
        if [ -f "$config_file" ]; then
            # 检查是否已包含 nvm 配置
            if ! grep -q "NVM Configuration" "$config_file"; then
                echo "$nvm_config" >> "$config_file"
                log_success "✓ 已更新: $config_file"
                updated_files=$((updated_files + 1))
            else
                log_info "✓ 已包含: $config_file"
            fi
        fi
    done

    # 如果没有配置文件，创建一个
    if [ $updated_files -eq 0 ]; then
        if [[ "$current_shell" == "zsh" ]]; then
            echo "$nvm_config" > "$HOME/.zshrc"
            log_success "✓ 创建配置文件: $HOME/.zshrc"
        else
            echo "$nvm_config" > "$HOME/.bashrc"
            log_success "✓ 创建配置文件: $HOME/.bashrc"
        fi
    fi
}

# 更新脚本执行环境
update_script_environment() {
    log_info "正在更新脚本执行环境..."

    # 设置 nvm 环境
    export NVM_DIR="$HOME/.nvm"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        \. "$NVM_DIR/nvm.sh"
        \. "$NVM_DIR/bash_completion" 2>/dev/null
        log_success "✓ NVM 环境已加载"
    fi

    # 确保用户 bin 目录在 PATH 中
    local user_bin="$HOME/bin"
    if [ -d "$user_bin" ]; then
        export PATH="$user_bin:$PATH"
        log_success "✓ 用户 bin 目录已添加到 PATH"
    fi

    # 确保 /usr/local/bin 在 PATH 中
    export PATH="/usr/local/bin:$PATH"

    # 验证关键命令
    local commands_to_check=("curl" "wget" "jq" "nvm")
    local failed_commands=()

    for cmd in "${commands_to_check[@]}"; do
        if ! check_command "$cmd"; then
            failed_commands+=("$cmd")
        fi
    done

    if [ ${#failed_commands[@]} -eq 0 ]; then
        log_success "✓ 所有依赖已准备就绪"
        return 0
    else
        log_error "❌ 以下命令仍不可用: ${failed_commands[*]}"
        return 1
    fi
}

# 智能安装缺失的依赖
install_missing_dependencies() {
    log_info "🔧 开始安装缺失的依赖..."

    local install_attempts=0
    local max_attempts=3

    while [ $install_attempts -lt $max_attempts ]; do
        # 检查基本依赖
        if check_basic_dependencies; then
            log_success "✓ 所有依赖检查通过"
            break
        fi

        install_attempts=$((install_attempts + 1))
        log_info "尝试安装依赖 (第 $install_attempts/$max_attempts 次)..."

        # 安装缺失的依赖
        local missing_deps=($(check_basic_dependencies 2>&1))
        local install_success=true

        # 安装 jq
        if echo "${missing_deps[@]}" | grep -q "jq"; then
            log_info "正在安装 jq..."
            if ! install_jq_manually; then
                install_success=false
                log_error "jq 安装失败"
            fi
        fi

        # 安装 nvm
        if echo "${missing_deps[@]}" | grep -q "nvm"; then
            log_info "正在安装 nvm..."
            if ! install_nvm_safely; then
                install_success=false
                log_error "nvm 安装失败"
            else
                # nvm 安装成功后更新配置文件
                detect_and_update_shell
            fi
        fi

        # 更新环境
        update_script_environment

        if [ "$install_success" = false ] && [ $install_attempts -lt $max_attempts ]; then
            log_warning "安装失败，5 秒后重试..."
            sleep 5
        elif [ "$install_success" = false ] && [ $install_attempts -eq $max_attempts ]; then
            log_error "依赖安装失败，已达到最大重试次数"
            return 1
        fi
    done

    return 0
}

# 准备完整环境
prepare_environment() {
    log_info "🚀 开始环境准备流程..."

    # 显示系统信息
    log_info "检测到系统: $(uname -s) $(uname -m)"
    log_info "当前用户: $(whoami)"
    log_info "用户目录: $HOME"

    # 安装缺失依赖
    if ! install_missing_dependencies; then
        log_error "依赖安装失败，无法继续安装流程"
        echo
        echo -e "${YELLOW}💡 可能的解决方案：${NC}"
        echo "1. 检查网络连接是否正常"
        echo "2. 确保有足够的磁盘空间（至少 100MB）"
        echo "3. 确保有安装软件的权限"
        echo "4. 手动安装依赖后重新运行脚本"
        echo
        echo -e "${CYAN}手动安装命令：${NC}"
        echo "  curl -L https://github.com/jqlang/jq/releases/download/jq-1.6/jq-osx-amd64 -o jq"
        echo "  chmod +x jq && sudo mv jq /usr/local/bin/"
        echo "  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
        exit 1
    fi

    # 更新执行环境
    if ! update_script_environment; then
        log_error "环境更新失败"
        exit 1
    fi

    log_success "✓ 环境准备完成，可以开始安装流程！"
}

# 显示欢迎界面
show_welcome() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${BOLD}                    CLI工具一键安装向导                      ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${BOLD}                 AI-Powered Development Setup                 ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}${BOLD}📋 本安装向导将为您完成以下操作：${NC}"
    echo -e "${YELLOW}├─ ① 检查并安装 NVM (Node Version Manager) - Node.js版本管理器${NC}"
    echo -e "${YELLOW}├─ ② 安装 Node.js (JavaScript 运行环境)${NC}"
    echo -e "${YELLOW}├─ ③ 更新 NPM (Node 包管理器)${NC}"
    echo -e "${YELLOW}├─ ④ 安装 Claude Code${NC}"
    echo -e "${YELLOW}│   └─ ${GREEN}Claude Code${NC} - Anthropic AI 助手${NC}"
    echo -e "${YELLOW}└─ ⑤ 配置 AI 模型（MiniMax/DeepSeek/GLM-4.6）(可选)${NC}"
    echo
    echo -e "${GREEN}💡 提示：本向导支持交互式操作，您可以选择跳过某些步骤${NC}"
    echo -e "${GREEN}   整个过程大约需要 5-10 分钟，取决于您的网络速度${NC}"
    echo
    read -p "按 Enter 键开始安装，或按 Ctrl+C 退出..."
}

# 显示系统信息
show_system_info() {
    echo -e "\n${CYAN}${BOLD}📊 系统环境检测${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # 检测操作系统
    local os_info=$(uname -s)
    local os_version=""
    if [[ "$OSTYPE" == "darwin"* ]]; then
        os_version=$(sw_vers -productVersion 2>/dev/null || echo "macOS")
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        os_version=$(lsb_release -d 2>/dev/null | cut -f2 || echo "Linux")
    fi

    echo -e "操作系统: ${GREEN}${os_info}${NC}"
    echo -e "系统版本: ${GREEN}${os_version}${NC}"
    echo -e "系统架构: ${GREEN}$(uname -m)${NC}"
    echo -e "Shell: ${GREEN}${SHELL}${NC}"
    echo -e "用户目录: ${GREEN}${HOME}${NC}"

    # 检查必要的命令
    echo -e "\n${YELLOW}🔍 检查系统依赖：${NC}"
    local deps=("curl" "wget")
    for dep in "${deps[@]}"; do
        if check_command "$dep"; then
            echo -e "  ${GREEN}✓${NC} $dep 已安装"
        else
            echo -e "  ${YELLOW}⚠${NC} $dep 未安装"
        fi
    done
    echo
}

# 解释步骤
explain_step() {
    local step=$1
    local description=$2
    local details=$3

    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}步骤 $step: $description${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [ -n "$details" ]; then
        echo -e "${YELLOW}📝 说明：${NC}"
        echo "$details"
        echo
    fi
}

# 显示进度条
show_progress() {
    local current=$1
    local total=$2
    local task=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))

    printf "\r${GREEN}[${NC}"
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "${GREEN}] ${percent}%% - $task${NC}"
}

# 旋转加载动画
spinner() {
    local pid=$1
    local message=$2
    local spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0

    while kill -0 $pid 2>/dev/null; do
        printf "\r${YELLOW}${spin[i]} $message${NC}"
        i=$(( (i+1) % ${#spin[@]} ))
        sleep 0.1
    done
    printf "\r"
}

# 显示步骤状态
show_step_status() {
    local status=$1
    local message=$2

    case $status in
        "success")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "error")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "warning")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "info")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
    esac
}

# 交互式确认函数
confirm_action() {
    local message=$1
    local default=$2  # "y" 或 "n"

    while true; do
        if [ "$default" = "y" ]; then
            read -p "$message (Y/n): " answer
            answer=${answer:-Y}
        else
            read -p "$message (y/N): " answer
            answer=${answer:-N}
        fi

        case $answer in
            [Yy]|[Yy][Ee][Ss] ) return 0 ;;
            [Nn]|[Nn][Oo] ) return 1 ;;
            * ) echo "请输入 y 或 n" ;;
        esac
    done
}

# 选择安装组件
select_components() {
    echo -e "\n${YELLOW}${BOLD}🎯 请选择要安装的组件：${NC}\n"

    # NVM
    if confirm_action "是否安装 NVM (Node Version Manager)？" "y"; then
        install_nvm=true
        show_step_status "success" "将安装 NVM"
    else
        install_nvm=false
        show_step_status "warning" "跳过 NVM 安装"
    fi
    echo

    # Claude Code
    if confirm_action "是否安装 Claude Code 工具？" "y"; then
        install_claude=true
        show_step_status "success" "将安装 Claude Code"
    else
        install_claude=false
        show_step_status "warning" "跳过 Claude Code 安装"
    fi
    echo

    # 模型配置
    if confirm_action "是否现在配置 AI 模型提供商？" "n"; then
        configure_models=true
        show_step_status "info" "将配置 AI 模型（支持 MiniMax-M2、DeepSeek、GLM-4.6）"
    else
        configure_models=false
        show_step_status "info" "跳过模型配置（可稍后手动配置）"
    fi
}

# 显示安装计划
show_installation_plan() {
    echo -e "\n${PURPLE}${BOLD}📋 安装计划确认${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo

    echo -e "${YELLOW}将安装的组件：${NC}"
    [ "$install_nvm" = true ] && echo -e "  ${GREEN}✓${NC} NVM (Node Version Manager)"
    [ "$install_claude" = true ] && echo -e "  ${GREEN}✓${NC} Claude Code (@anthropic-ai/claude-code)"
    [ "$configure_models" = true ] && echo -e "  ${GREEN}✓${NC} AI 模型配置（MiniMax-M2、DeepSeek）"
    echo

    echo -e "${YELLOW}预计安装时间：${NC} 5-10 分钟（取决于网络速度）"
    echo -e "${YELLOW}需要网络连接：${NC} 是"
    echo

    if ! confirm_action "确认开始安装？" "y"; then
        echo "安装已取消"
        exit 0
    fi
}

# 检测操作系统并打开浏览器
open_url() {
    local url=$1
    local description=$2

    echo -e "\n${YELLOW}🔗 正在打开浏览器访问：${NC}$description"
    echo -e "${BLUE}URL: $url${NC}\n"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        open "$url" 2>/dev/null
        echo "✅ 已在默认浏览器中打开页面"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        xdg-open "$url" 2>/dev/null || {
            echo "⚠️  无法自动打开浏览器，请手动访问：$url"
            echo "复制链接："
            if command -v pbcopy >/dev/null 2>&1; then
                echo "$url" | pbcopy
                echo "✅ 链接已复制到剪贴板"
            else
                echo "$url"
            fi
        }
        echo "✅ 已在默认浏览器中打开页面"
    else
        echo "⚠️  请手动访问：$url"
    fi
}

# 获取 MiniMax API Key
get_minimax_api_key() {
    echo -e "\n${GREEN}${BOLD}🔑 配置 MiniMax API Key${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "${YELLOW}📝 说明：${NC}"
    echo "   MiniMax API Key 用于访问 MiniMax 的 AI 模型服务。"
    echo "   您可以免费注册并获取 API Key。"
    echo

    if confirm_action "是否自动打开 MiniMax 注册页面？" "y"; then
        open_url "https://platform.minimaxi.com/user-center/basic-information/interface-key" \
                 "MiniMax 开放平台 - API Key 管理页面"

        echo -e "\n${GREEN}💡 提示：${NC}"
        echo "   1. 在打开的页面中点击'创建新的密钥'按钮"
        echo "   2. 输入项目名称（如：my-cli-tool）"
        echo "   3. 创建后将获得 API Key，请复制它"
        echo "   4. 复制完成后返回此处粘贴 API Key"
        echo
        read -p "创建完成后，请输入您的 API Key（或输入 'skip' 跳过）： " MINIMAX_API_KEY
    else
        read -p "请访问 https://platform.minimaxi.com 创建 API Key，然后输入：" MINIMAX_API_KEY
    fi

    # 验证 API Key
    while true; do
        if [ "$MINIMAX_API_KEY" = "skip" ]; then
            return 1
        fi

        if [ -z "$MINIMAX_API_KEY" ]; then
            echo -e "${RED}❌ API Key 不能为空，请重新输入${NC}"
            read -p "请输入您的 MiniMax API Key：" MINIMAX_API_KEY
            continue
        fi

        # 简单验证 API key 格式
        if [ ${#MINIMAX_API_KEY} -lt 10 ]; then
            echo -e "${RED}❌ API Key 格式可能不正确，请检查后重新输入${NC}"
            read -p "请重新输入（或输入 'skip' 跳过）：" MINIMAX_API_KEY
            continue
        fi

        break
    done

    return 0
}

# 检查命令是否存在
check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 检查 nvm 是否存在
check_nvm() {
    # 检查 nvm 命令或函数是否存在
    if command -v nvm >/dev/null 2>&1 || type nvm >/dev/null 2>&1; then
        return 0
    else
        # 尝试加载 nvm
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        if command -v nvm >/dev/null 2>&1 || type nvm >/dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    fi
}

# 安装函数
install_nvm() {
    log_info "开始安装 NVM..."
    
    if check_command "curl"; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    elif check_command "wget"; then
        wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    else
        log_error "需要 curl 或 wget 来安装 NVM"
        return 1
    fi
    
    # 重新加载 shell 配置
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    
    if check_nvm; then
        log_success "NVM 安装成功"
        return 0
    else
        log_error "NVM 安装失败，请手动安装后重新运行脚本"
        return 1
    fi
}

# 检查和安装 Node.js (通过 NVM)
install_node() {
    log_info "检查 Node.js 环境..."
    
    if check_command "node"; then
        NODE_VERSION=$(node --version)
        log_success "Node.js 已安装: $NODE_VERSION"
    else
        log_warning "Node.js 未安装，正在通过 NVM 安装最新 LTS 版本..."
        
        if check_nvm; then
            nvm install --lts
            nvm use --lts
            NODE_VERSION=$(node --version)
            log_success "Node.js 安装成功: $NODE_VERSION"
        else
            log_error "NVM 未安装，无法安装 Node.js"
            return 1
        fi
    fi
}

# 检查和安装 NPM
install_npm() {
    log_info "检查 NPM 环境..."
    
    if check_command "npm"; then
        NPM_VERSION=$(npm --version)
        log_success "NPM 已安装: $NPM_VERSION"
        
        # 更新 NPM 到最新版本
        log_info "正在更新 NPM 到最新版本..."
        npm install -g npm@latest
        NPM_NEW_VERSION=$(npm --version)
        if [ "$NPM_VERSION" != "$NPM_NEW_VERSION" ]; then
            log_success "NPM 已更新: $NPM_VERSION -> $NPM_NEW_VERSION"
        else
            log_info "NPM 已是最新版本: $NPM_VERSION"
        fi
    else
        log_error "NPM 未安装，请先安装 Node.js"
        return 1
    fi
}

# 安装 CLI 工具函数
install_cli_tool() {
    local package_name=$1
    local display_name=$2
    
    log_info "正在安装 $display_name ($package_name)..."
    
    if npm install -g "$package_name" 2>/dev/null; then
        log_success "$display_name 安装成功"
        return 0
    else
        log_error "$display_name 安装失败"
        return 1
    fi
}

# 初始化多模型配置系统
init_provider_config() {
    local config_dir="$HOME/.claude"
    local providers_file="$config_dir/providers.json"

    if [ ! -d "$config_dir" ]; then
        mkdir -p "$config_dir"
        log_info "创建 Claude Code 配置目录: $config_dir"
    fi

    # 创建空的 providers.json 如果不存在
    if [ ! -f "$providers_file" ]; then
        cat > "$providers_file" << 'EOF'
{
  "providers": {},
  "activeProvider": null
}
EOF
        log_info "初始化多模型配置系统"
    fi

    return 0
}

# 加载配置
load_provider_config() {
    local providers_file="$HOME/.claude/providers.json"

    if [ ! -f "$providers_file" ]; then
        echo "{}"
        return 1
    fi

    # 使用 jq 加载配置（如果可用）
    if command -v jq >/dev/null 2>&1; then
        jq -r '.' "$providers_file" 2>/dev/null || echo '{"providers": {}, "activeProvider": null}'
    else
        # 备用方案：简单读取
        cat "$providers_file" 2>/dev/null || echo '{"providers": {}, "activeProvider": null}'
    fi
}

# 保存配置
save_provider_config() {
    local config="$1"
    local providers_file="$HOME/.claude/providers.json"

    if [ -z "$config" ]; then
        log_error "配置内容为空，无法保存"
        return 1
    fi

    if command -v jq >/dev/null 2>&1; then
        # 使用 tee 同时显示输出并保存到文件
        echo "$config" | jq '.' | tee "$providers_file" > /dev/null
        local jq_result=$?
        if [ $jq_result -ne 0 ]; then
            log_error "jq 格式化配置失败"
            return 1
        fi
    else
        echo "$config" > "$providers_file"
    fi

    return 0
}

# 迁移现有配置到多模型系统
migrate_existing_config() {
    log_info "检查并迁移现有配置..."

    local settings_file="$HOME/.claude/settings.json"

    if [ ! -f "$settings_file" ]; then
        return 0
    fi

    # 检查是否已迁移
    local current_config=$(load_provider_config)
    local active_provider=$(echo "$current_config" | grep -o '"activeProvider": "[^"]*"' | cut -d'"' -f4)

    if [ -n "$active_provider" ]; then
        log_info "配置已迁移"
        return 0
    fi

    # 检测现有提供商类型
    local base_url=$(grep -o '"ANTHROPIC_BASE_URL": "[^"]*"' "$settings_file" | cut -d'"' -f4)
    local api_key=$(grep -o '"ANTHROPIC_AUTH_TOKEN": "[^"]*"' "$settings_file" | cut -d'"' -f4)

    if [ -z "$base_url" ] || [ -z "$api_key" ]; then
        log_warning "无法解析现有配置，跳过迁移"
        return 0
    fi

    # 确定提供商
    local provider_name=""
    if [[ "$base_url" == *"minimaxi"* ]]; then
        provider_name="minimax"
    elif [[ "$base_url" == *"deepseek"* ]]; then
        provider_name="deepseek"
    else
        log_warning "未知提供商类型: $base_url"
        return 0
    fi

    # 创建迁移后的配置
    if command -v jq >/dev/null 2>&1; then
        local new_config=$(echo "$current_config" | jq \
            --arg provider "$provider_name" \
            --arg key "$api_key" \
            --arg url "$base_url" \
            '.providers[$provider] = {
                "name": $provider,
                "displayName": (if $provider == "minimax" then "MiniMax-M2" else "DeepSeek" end),
                "apiKeyName": (if $provider == "minimax" then "MINIMAX_API_KEY" else "DEEPSEEK_API_KEY" end),
                "apiKeyUrl": (if $provider == "minimax" then "https://platform.minimaxi.com/user-center/basic-information/interface-key" else "https://platform.deepseek.com/api_keys" end),
                "baseUrl": $url,
                "apiKey": $key,
                "timeout": (if $provider == "minimax" then "3000000" else "600000" end),
                "models": {
                    "default": (if $provider == "minimax" then "MiniMax-M2" else "deepseek-chat" end),
                    "small_fast": (if $provider == "minimax" then "MiniMax-M2" else "deepseek-chat" end),
                    "DEFAULT_SONNET_MODEL": (if $provider == "minimax" then "MiniMax-M2" else "deepseek-chat" end),
                    "DEFAULT_OPUS_MODEL": (if $provider == "minimax" then "MiniMax-M2" else "deepseek-reasoner" end),
                    "DEFAULT_HAIKU_MODEL": (if $provider == "minimax" then "MiniMax-M2" else "deepseek-coder" end)
                }
            } | .activeProvider = $provider')

        if [ -n "$new_config" ]; then
            save_provider_config "$new_config" || {
                log_warning "迁移配置保存失败"
                return 1
            }
        else
            log_warning "迁移配置为空，跳过保存"
            return 1
        fi
    else
        log_warning "需要 jq 来迁移配置"
        return 1
    fi

    log_success "配置迁移完成: $provider_name"
    return 0
}

# 配置 MiniMax 提供商
configure_minimax_provider() {
    log_info "配置 MiniMax-M2 模型提供商..."

    if get_minimax_api_key; then
        configure_provider "minimax" "$MINIMAX_API_KEY"
        return $?
    else
        return 1
    fi
}

# 配置 DeepSeek 提供商
configure_deepseek_provider() {
    log_info "配置 DeepSeek 模型提供商..."

    if get_deepseek_api_key; then
        configure_provider "deepseek" "$DEEPSEEK_API_KEY"
        return $?
    else
        return 1
    fi
}

# 配置 GLM 提供商
configure_glm_provider() {
    log_info "配置 GLM-4.6 模型提供商..."

    if get_glm_api_key; then
        configure_provider "glm" "$GLM_API_KEY"
        return $?
    else
        return 1
    fi
}

# 配置 GLM Flash 提供商
configure_glm_flash_provider() {
    log_info "配置 GLM-4.5-Flash 模型提供商（🆓免费）..."

    if get_glm_flash_api_key; then
        configure_provider "glm-flash" "$GLM_API_KEY"
        return $?
    else
        return 1
    fi
}

# 通用提供商配置函数
configure_provider() {
    local provider_name=$1
    local api_key=$2
    local providers_file="$HOME/.claude/providers.json"

    # 获取当前配置
    local current_config=$(load_provider_config)

    # 定义提供商信息
    local provider_display=""
    local api_key_url=""
    local base_url=""
    local timeout=""
    local models_json=""

    case $provider_name in
        "minimax")
            provider_display="MiniMax-M2"
            api_key_url="https://platform.minimaxi.com/user-center/basic-information/interface-key"
            base_url="https://api.minimaxi.com/anthropic"
            timeout="3000000"
            if command -v jq >/dev/null 2>&1; then
                models_json=$(jq -n \
                    --arg default "MiniMax-M2" \
                    --arg small_fast "MiniMax-M2" \
                    --arg sonnet "MiniMax-M2" \
                    --arg opus "MiniMax-M2" \
                    --arg haiku "MiniMax-M2" \
                    '{
                        "default": $default,
                        "small_fast": $small_fast,
                        "DEFAULT_SONNET_MODEL": $sonnet,
                        "DEFAULT_OPUS_MODEL": $opus,
                        "DEFAULT_HAIKU_MODEL": $haiku
                    }')
            else
                models_json='{
                    "default": "MiniMax-M2",
                    "small_fast": "MiniMax-M2",
                    "DEFAULT_SONNET_MODEL": "MiniMax-M2",
                    "DEFAULT_OPUS_MODEL": "MiniMax-M2",
                    "DEFAULT_HAIKU_MODEL": "MiniMax-M2"
                }'
            fi
            ;;
        "deepseek")
            provider_display="DeepSeek"
            api_key_url="https://platform.deepseek.com/api_keys"
            base_url="https://api.deepseek.com/anthropic"
            timeout="600000"
            if command -v jq >/dev/null 2>&1; then
                models_json=$(jq -n \
                    --arg default "deepseek-chat" \
                    --arg small_fast "deepseek-chat" \
                    --arg sonnet "deepseek-chat" \
                    --arg opus "deepseek-reasoner" \
                    --arg haiku "deepseek-coder" \
                    '{
                        "default": $default,
                        "small_fast": $small_fast,
                        "DEFAULT_SONNET_MODEL": $sonnet,
                        "DEFAULT_OPUS_MODEL": $opus,
                        "DEFAULT_HAIKU_MODEL": $haiku
                    }')
            else
                models_json='{
                    "default": "deepseek-chat",
                    "small_fast": "deepseek-chat",
                    "DEFAULT_SONNET_MODEL": "deepseek-chat",
                    "DEFAULT_OPUS_MODEL": "deepseek-reasoner",
                    "DEFAULT_HAIKU_MODEL": "deepseek-coder"
                }'
            fi
            ;;
        "glm")
            provider_display="GLM-4.6"
            api_key_url="https://bigmodel.cn/usercenter/proj-mgmt/apikeys"
            base_url="https://open.bigmodel.cn/api/anthropic"
            timeout="3000000"
            if command -v jq >/dev/null 2>&1; then
                models_json=$(jq -n \
                    --arg default "GLM-4.6" \
                    --arg small_fast "GLM-4.6" \
                    --arg sonnet "GLM-4.6" \
                    --arg opus "GLM-4.6" \
                    --arg haiku "GLM-4.5-Air" \
                    '{
                        "default": $default,
                        "small_fast": $small_fast,
                        "DEFAULT_SONNET_MODEL": $sonnet,
                        "DEFAULT_OPUS_MODEL": $opus,
                        "DEFAULT_HAIKU_MODEL": $haiku
                    }')
            else
                models_json='{
                    "default": "GLM-4.6",
                    "small_fast": "GLM-4.6",
                    "DEFAULT_SONNET_MODEL": "GLM-4.6",
                    "DEFAULT_OPUS_MODEL": "GLM-4.6",
                    "DEFAULT_HAIKU_MODEL": "GLM-4.5-Air"
                }'
            fi
            ;;
        "glm-flash")
            provider_display="🆓 GLM-4.5-Flash (免费) 🆓"
            api_key_url="https://bigmodel.cn/usercenter/proj-mgmt/apikeys"
            base_url="https://open.bigmodel.cn/api/anthropic"
            timeout="3000000"
            if command -v jq >/dev/null 2>&1; then
                models_json=$(jq -n \
                    --arg default "glm-4.5-flash" \
                    --arg small_fast "glm-4.5-flash" \
                    --arg sonnet "glm-4.5-flash" \
                    --arg opus "glm-4.5-flash" \
                    --arg haiku "glm-4.5-flash" \
                    '{
                        "default": $default,
                        "small_fast": $small_fast,
                        "DEFAULT_SONNET_MODEL": $sonnet,
                        "DEFAULT_OPUS_MODEL": $opus,
                        "DEFAULT_HAIKU_MODEL": $haiku
                    }')
            else
                models_json='{
                    "default": "glm-4.5-flash",
                    "small_fast": "glm-4.5-flash",
                    "DEFAULT_SONNET_MODEL": "glm-4.5-flash",
                    "DEFAULT_OPUS_MODEL": "glm-4.5-flash",
                    "DEFAULT_HAIKU_MODEL": "glm-4.5-flash"
                }'
            fi
            ;;
        *)
            log_error "未知提供商: $provider_name"
            return 1
            ;;
    esac

    # 保存提供商配置
    if command -v jq >/dev/null 2>&1; then
        # 构建 API_KEY 变量名（兼容旧版本 bash）
        local key_name=""
        case $provider_name in
            "minimax")
                key_name="MINIMAX_API_KEY"
                ;;
            "deepseek")
                key_name="DEEPSEEK_API_KEY"
                ;;
            "glm")
                key_name="GLM_API_KEY"
                ;;
            "glm-flash")
                key_name="GLM_API_KEY"
                ;;
        esac

        local new_config=$(echo "$current_config" | jq \
            --arg provider "$provider_name" \
            --arg display "$provider_display" \
            --arg key_name "$key_name" \
            --arg url "$api_key_url" \
            --arg base "$base_url" \
            --arg key "$api_key" \
            --arg to "$timeout" \
            --argjson models "$models_json" \
            '.providers[$provider] = {
                "name": $provider,
                "displayName": $display,
                "apiKeyName": $key_name,
                "apiKeyUrl": $url,
                "baseUrl": $base,
                "apiKey": $key,
                "timeout": $to,
                "models": $models
            }')

        if [ -n "$new_config" ]; then
            save_provider_config "$new_config" || {
                log_error "$provider_display 配置保存失败"
                return 1
            }
            log_success "$provider_display 配置保存成功"
        else
            log_error "生成 $provider_display 配置失败"
            return 1
        fi
    else
        log_error "需要 jq 来配置多模型系统，请安装: apt-get install jq 或 brew install jq"
        return 1
    fi

    return 0
}

# 应用提供商配置到 settings.json
apply_provider_config() {
    local provider_name=$1
    local providers_file="$HOME/.claude/providers.json"
    local settings_file="$HOME/.claude/settings.json"

    # 获取提供商配置
    local provider_config=""
    if command -v jq >/dev/null 2>&1; then
        provider_config=$(jq -r ".providers[\"$provider_name\"]" "$providers_file")
    else
        log_error "需要 jq 来应用配置"
        return 1
    fi

    if [ "$provider_config" = "null" ] || [ -z "$provider_config" ]; then
        log_error "未找到提供商配置: $provider_name"
        return 1
    fi

    # 提取配置信息
    local base_url=$(echo "$provider_config" | jq -r '.baseUrl')
    local api_key=$(echo "$provider_config" | jq -r '.apiKey')
    local timeout=$(echo "$provider_config" | jq -r '.timeout')
    local default_model=$(echo "$provider_config" | jq -r '.models.default')
    local small_fast_model=$(echo "$provider_config" | jq -r '.models.small_fast')

    # 创建 settings.json
    if command -v jq >/dev/null 2>&1; then
        local settings_json=$(jq -n \
            --arg base_url "$base_url" \
            --arg api_key "$api_key" \
            --arg timeout "$timeout" \
            --arg default_model "$default_model" \
            --arg small_fast_model "$small_fast_model" \
            '{
                "env": {
                    "ANTHROPIC_BASE_URL": $base_url,
                    "ANTHROPIC_AUTH_TOKEN": $api_key,
                    "API_TIMEOUT_MS": $timeout,
                    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": 1,
                    "ANTHROPIC_MODEL": $default_model,
                    "ANTHROPIC_SMALL_FAST_MODEL": $small_fast_model,
                    "ANTHROPIC_DEFAULT_SONNET_MODEL": $default_model,
                    "ANTHROPIC_DEFAULT_OPUS_MODEL": $default_model,
                    "ANTHROPIC_DEFAULT_HAIKU_MODEL": $small_fast_model
                }
            }')

        echo "$settings_json" > "$settings_file"
    fi

    log_success "已切换到模型: $provider_name ($default_model)"
    return 0
}

# 切换提供商
switch_provider() {
    local provider_name=$1

    if [ -z "$provider_name" ]; then
        log_error "请指定要切换的提供商"
        return 1
    fi

    local providers_file="$HOME/.claude/providers.json"

    # 检查提供商是否存在
    if command -v jq >/dev/null 2>&1; then
        local exists=$(jq -r ".providers[\"$provider_name\"] | type" "$providers_file" 2>/dev/null)
        if [ "$exists" != "object" ]; then
            log_error "未找到已配置的提供商: $provider_name"
            return 1
        fi

        # 更新 activeProvider
        local current_config=$(load_provider_config)
        local new_config=$(echo "$current_config" | jq --arg provider "$provider_name" '.activeProvider = $provider')
        save_provider_config "$new_config"

        # 应用配置
        apply_provider_config "$provider_name"

        log_success "成功切换到: $provider_name"
    else
        log_error "需要 jq 来切换提供商"
        return 1
    fi

    return 0
}

# 列出所有已配置提供商
list_providers() {
    local providers_file="$HOME/.claude/providers.json"
    local active_provider=""

    if [ ! -f "$providers_file" ]; then
        echo "暂无已配置的提供商"
        return 0
    fi

    if command -v jq >/dev/null 2>&1; then
        active_provider=$(jq -r '.activeProvider' "$providers_file" 2>/dev/null)

        echo -e "${CYAN}${BOLD}📊 已配置的模型提供商：${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo

        local count=0
        jq -r '.providers | to_entries[] | "\(.key)|\(.value.displayName)|\(.value.baseUrl)"' "$providers_file" 2>/dev/null | while IFS='|' read -r name display url; do
            if [ -n "$name" ]; then
                count=$((count + 1))
                local marker="  "
                if [ "$name" = "$active_provider" ]; then
                    marker="${GREEN}✓${NC} "
                fi
                echo -e "${marker}${YELLOW}$count.${NC} $display"
                echo -e "   ${CYAN}ID:${NC} $name"
                echo -e "   ${CYAN}API:${NC} $url"
                echo
            fi
        done

        if [ $count -eq 0 ]; then
            echo -e "${YELLOW}暂无已配置的提供商${NC}"
        else
            echo -e "${GREEN}当前活跃：${NC} $active_provider"
        fi
    else
        echo "需要 jq 来显示提供商列表"
    fi
}

# 选择提供商（交互式）
select_provider_interactive() {
    local providers_file="$HOME/.claude/providers.json"

    if ! command -v jq >/dev/null 2>&1; then
        log_error "需要 jq 来选择提供商，请安装: apt-get install jq 或 brew install jq"
        return 1
    fi

    local count=$(jq '.providers | length' "$providers_file" 2>/dev/null)
    count=${count:-0}

    if [ "$count" -eq 0 ]; then
        echo -e "${YELLOW}暂无可用的提供商，请先配置一个模型提供商${NC}"
        return 1
    elif [ "$count" -eq 1 ]; then
        # 只有一个提供商，直接使用
        local provider_name=$(jq -r '.providers | keys[0]' "$providers_file" 2>/dev/null)
        switch_provider "$provider_name"
        return $?
    else
        # 多个提供商，让用户选择
        echo -e "\n${YELLOW}${BOLD}🎯 请选择要使用的模型提供商：${NC}\n"

        local i=1
        local provider_names=()
        while IFS='|' read -r name display; do
            if [ -n "$name" ]; then
                provider_names+=("$name")
                echo -e "${CYAN}$i.${NC} $display"
                i=$((i + 1))
            fi
        done < <(jq -r '.providers | to_entries[] | "\(.key)|\(.value.displayName)"' "$providers_file" 2>/dev/null)

        echo
        while true; do
            read -p "请选择 (1-$((i-1))): " choice

            if [ "$choice" -ge 1 ] 2>/dev/null && [ "$choice" -lt $i ] 2>/dev/null; then
                local index=$((choice - 1))
                switch_provider "${provider_names[$index]}"
                return $?
            else
                echo -e "${RED}无效选择，请输入 1-$((i-1)) 之间的数字${NC}"
            fi
        done
    fi
}

# 获取 DeepSeek API Key
get_deepseek_api_key() {
    echo -e "\n${GREEN}${BOLD}🔑 配置 DeepSeek API Key${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "${YELLOW}📝 说明：${NC}"
    echo "   DeepSeek API Key 用于访问 DeepSeek 的 AI 模型服务。"
    echo "   您可以免费注册并获取 API Key。"
    echo

    if confirm_action "是否自动打开 DeepSeek API Key 申请页面？" "y"; then
        open_url "https://platform.deepseek.com/api_keys" \
                 "DeepSeek 开放平台 - API Key 管理页面"

        echo -e "\n${GREEN}💡 提示：${NC}"
        echo "   1. 在打开的页面中点击'创建新的密钥'按钮"
        echo "   2. 输入项目名称（如：my-cli-tool）"
        echo "   3. 创建后将获得 API Key，请复制它"
        echo "   4. 复制完成后返回此处粘贴 API Key"
        echo
        read -p "创建完成后，请输入您的 API Key（或输入 'skip' 跳过）： " DEEPSEEK_API_KEY
    else
        read -p "请访问 https://platform.deepseek.com/api_keys 创建 API Key，然后输入：" DEEPSEEK_API_KEY
    fi

    # 验证 API Key
    while true; do
        if [ "$DEEPSEEK_API_KEY" = "skip" ]; then
            return 1
        fi

        if [ -z "$DEEPSEEK_API_KEY" ]; then
            echo -e "${RED}❌ API Key 不能为空，请重新输入${NC}"
            read -p "请输入您的 DeepSeek API Key：" DEEPSEEK_API_KEY
            continue
        fi

        # 简单验证 API key 格式
        if [ ${#DEEPSEEK_API_KEY} -lt 10 ]; then
            echo -e "${RED}❌ API Key 格式可能不正确，请检查后重新输入${NC}"
            read -p "请重新输入（或输入 'skip' 跳过）：" DEEPSEEK_API_KEY
            continue
        fi

        break
    done

    return 0
}

# 获取 GLM API Key
get_glm_api_key() {
    echo -e "\n${GREEN}${BOLD}🔑 配置 GLM API Key${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "${YELLOW}📝 说明：${NC}"
    echo "   GLM API Key 用于访问 GLM-4.6 AI 模型服务。"
    echo "   基于智谱 AI Coding Plan，您可以获得优惠价格和更高额度。"
    echo

    if confirm_action "是否自动打开 GLM API Key 管理页面？" "y"; then
        open_url "https://bigmodel.cn/usercenter/proj-mgmt/apikeys" \
                 "智谱开放平台 - API Key 管理页面"

        echo -e "\n${GREEN}💡 提示：${NC}"
        echo "   1. 在打开的页面中点击'创建新的密钥'按钮"
        echo "   2. 输入项目名称（如：my-cli-tool）"
        echo "   3. 创建后将获得 API Key，请复制它"
        echo "   4. 复制完成后返回此处粘贴 API Key"
        echo
        read -p "创建完成后，请输入您的 API Key（或输入 'skip' 跳过）： " GLM_API_KEY
    else
        read -p "请访问 https://bigmodel.cn/usercenter/proj-mgmt/apikeys 创建 API Key，然后输入：" GLM_API_KEY
    fi

    # 验证 API Key
    while true; do
        if [ "$GLM_API_KEY" = "skip" ]; then
            return 1
        fi

        if [ -z "$GLM_API_KEY" ]; then
            echo -e "${RED}❌ API Key 不能为空，请重新输入${NC}"
            read -p "请输入您的 GLM API Key：" GLM_API_KEY
            continue
        fi

        # 简单验证 API key 格式
        if [ ${#GLM_API_KEY} -lt 10 ]; then
            echo -e "${RED}❌ API Key 格式可能不正确，请检查后重新输入${NC}"
            read -p "请重新输入（或输入 'skip' 跳过）：" GLM_API_KEY
            continue
        fi

        break
    done

    return 0
}

# 获取 GLM Flash API Key
get_glm_flash_api_key() {
    echo -e "\n${GREEN}${BOLD}🔑 配置 GLM Flash API Key${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "${YELLOW}📝 说明：${NC}"
    echo "   GLM API Key 用于访问 GLM-4.5-Flash AI 模型服务。"
    echo -e "   ${GREEN}${BOLD}🆓 GLM-4.5-Flash 是智谱最新的免费模型，无需付费即可体验 Claude Code！🆓${NC}"
    echo

    if confirm_action "是否自动打开 GLM API Key 管理页面？" "y"; then
        open_url "https://bigmodel.cn/usercenter/proj-mgmt/apikeys" \
                 "智谱开放平台 - API Key 管理页面"

        echo -e "\n${GREEN}💡 提示：${NC}"
        echo "   1. 在打开的页面中点击'创建新的密钥'按钮"
        echo "   2. 输入项目名称（如：my-cli-tool）"
        echo "   3. 创建后将获得 API Key，请复制它"
        echo "   4. 复制完成后返回此处粘贴 API Key"
        echo
        read -p "创建完成后，请输入您的 API Key（或输入 'skip' 跳过）： " GLM_API_KEY
    else
        read -p "请访问 https://bigmodel.cn/usercenter/proj-mgmt/apikeys 创建 API Key，然后输入：" GLM_API_KEY
    fi

    # 验证 API Key
    while true; do
        if [ "$GLM_API_KEY" = "skip" ]; then
            return 1
        fi

        if [ -z "$GLM_API_KEY" ]; then
            echo -e "${RED}❌ API Key 不能为空，请重新输入${NC}"
            read -p "请输入您的 GLM API Key：" GLM_API_KEY
            continue
        fi

        # 简单验证 API key 格式
        if [ ${#GLM_API_KEY} -lt 10 ]; then
            echo -e "${RED}❌ API Key 格式可能不正确，请检查后重新输入${NC}"
            read -p "请重新输入（或输入 'skip' 跳过）：" GLM_API_KEY
            continue
        fi

        break
    done

    return 0
}

# 配置 Claude Code（通用版本，支持多模型）
configure_claude_code() {
    log_info "配置 Claude Code 多模型支持..."

    # 检查 Claude Code 是否已安装
    if ! check_command "claude"; then
        log_error "Claude Code 未安装，请先安装 Claude Code"
        return 1
    fi

    # 初始化配置系统
    init_provider_config

    # 迁移现有配置
    migrate_existing_config

    # 检查是否已有配置
    local current_config=$(load_provider_config)
    local active_provider=$(echo "$current_config" | grep -o '"activeProvider": "[^"]*"' | cut -d'"' -f4)

    if [ -n "$active_provider" ]; then
        log_info "检测到已有配置: $active_provider"
        read -p "是否要重新配置模型提供商？ (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "跳过配置，使用现有设置"
            select_provider_interactive
            return $?
        fi
    fi

    # 配置提供商
    echo -e "\n${YELLOW}${BOLD}🎯 请选择要配置的模型提供商：${NC}\n"

    local config_count=0

    # MiniMax
    if confirm_action "是否配置 MiniMax-M2 模型？" "y"; then
        if configure_minimax_provider; then
            config_count=$((config_count + 1))
        fi
    fi

    # DeepSeek
    if confirm_action "是否配置 DeepSeek 模型？" "n"; then
        if configure_deepseek_provider; then
            config_count=$((config_count + 1))
        fi
    fi

    # GLM-4.6
    if confirm_action "是否配置 GLM-4.6 模型？（高性能付费）" "n"; then
        if configure_glm_provider; then
            config_count=$((config_count + 1))
        fi
    fi

    # GLM-4.5-Flash
    if confirm_action "是否配置 GLM-4.5-Flash 模型？（🆓🆓🆓 免费推荐 🆓🆓🆓）" "y"; then
        if configure_glm_flash_provider; then
            config_count=$((config_count + 1))
        fi
    fi

    if [ $config_count -eq 0 ]; then
        log_warning "未配置任何模型提供商"
        return 1
    fi

    # 选择当前使用的提供商
    select_provider_interactive

    log_success "Claude Code 多模型配置完成！"
    return 0
}

# 显示成功总结
show_success_summary() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${BOLD}                    🎉 安装完成！🎉                        ${NC}${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo

    echo -e "${YELLOW}${BOLD}📊 安装结果：${NC}"
    echo -e "${GREEN}✓${NC} 环境搭建完成"
    echo -e "${GREEN}✓${NC} 所有工具已就绪"
    echo -e "${GREEN}✓${NC} 可以开始使用 AI CLI 工具了"
    echo

    # 显示已安装的工具
    local installed_tools=()
    if [ "$install_nvm" = true ]; then
        installed_tools+=("NVM (Node Version Manager)")
    fi
    if [ "$install_claude" = true ]; then
        installed_tools+=("Claude Code")
    fi

    if [ ${#installed_tools[@]} -gt 0 ]; then
        echo -e "${CYAN}${BOLD}✅ 已成功安装以下工具：${NC}"
        for tool in "${installed_tools[@]}"; do
            echo -e "   ${GREEN}✓${NC} $tool"
        done
        echo
    fi

    # 显示当前模型配置状态
    if [ -f "$HOME/.claude/providers.json" ]; then
        echo -e "${CYAN}${BOLD}🤖 AI 模型配置状态：${NC}"
        list_providers
        echo
    fi

    show_usage_examples
}

# 显示使用示例
show_usage_examples() {
    echo -e "${CYAN}${BOLD}📚 使用示例：${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo

    # Claude Code 示例
    if check_command "claude"; then
        echo -e "${YELLOW}🤖 Claude Code 使用示例：${NC}"
        echo -e "${CYAN}├─${NC} 启动 Claude Code："
        echo -e "  ${GREEN}claude${NC}"
        echo -e "${CYAN}├─${NC} 分析代码："
        echo -e "  ${GREEN}claude code analyze my-project${NC}"
        echo -e "${CYAN}├─${NC} 生成文档："
        echo -e "  ${GREEN}claude code document my-file.js${NC}"
        echo -e "${CYAN}└─${NC} 代码审查："
        echo -e "  ${GREEN}claude code review --file my-code.py${NC}"
        echo
    fi

    show_next_steps
}

# 显示下一步建议
show_next_steps() {
    echo -e "${CYAN}${BOLD}🎯 下一步建议：${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo "1️⃣  阅读官方文档："
    echo "   - Claude Code: https://docs.anthropic.com/claude-cli"
    echo
    echo "2️⃣  加入社区："
    echo "   - GitHub: https://github.com/anthropics"
    echo "   - Discord: https://discord.gg/anthropic"
    echo
    echo "3️⃣  配置快捷别名（可选）："
    echo "   在 ~/.bashrc 或 ~/.zshrc 中添加："
    echo -e "   ${GREEN}alias claude='claude'${NC}"
    echo

    # 询问是否打开文档页面
    if confirm_action "是否打开 Claude Code 官方文档？" "n"; then
        open_url "https://docs.anthropic.com/claude-cli" "Claude Code 官方文档"
    fi

    echo
    echo -e "${GREEN}${BOLD}🎉 感谢使用 CLI 工具安装向导！${NC}"
    echo
}

# 处理错误并提供解决建议
handle_error() {
    local error_code=$1
    local error_msg=$2

    echo -e "\n${RED}❌ 发生错误：$error_msg${NC}"
    echo
    echo -e "${YELLOW}💡 可能的解决方案：${NC}"

    case $error_code in
        "NVM_INSTALL_FAILED")
            echo "1. 检查网络连接是否正常"
            echo "2. 确保有足够的磁盘空间（至少 100MB）"
            echo "3. 手动安装 NVM："
            echo "   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
            echo "4. 重启终端后重新运行脚本"
            ;;
        "NODE_INSTALL_FAILED")
            echo "1. 确保 NVM 已正确安装：nvm --version"
            echo "2. 手动安装：nvm install --lts"
            echo "3. 检查 ~/.bashrc 或 ~/.zshrc 是否包含 NVM 配置"
            echo "4. 重启终端后再试"
            ;;
        "NPM_INSTALL_FAILED")
            echo "1. 检查 Node.js 是否正确安装：node --version"
            echo "2. 手动更新 NPM：npm install -g npm@latest"
            echo "3. 检查网络连接"
            ;;
        "CLI_TOOL_INSTALL_FAILED")
            echo "1. 检查 NPM 是否正确安装：npm --version"
            echo "2. 检查网络连接"
            echo "3. 尝试手动安装："
            echo "   npm install -g $2"
            echo "4. 检查 npm 权限，可能需要使用 sudo"
            ;;
        "MINIMAX_CONFIG_FAILED")
            echo "1. 检查 API Key 是否正确"
            echo "2. 确保 ~/.claude 目录有写入权限"
            echo "3. 检查配置文件格式"
            ;;
        *)
            echo "1. 检查网络连接"
            echo "2. 重试执行"
            echo "3. 查看详细错误日志"
            ;;
    esac

    echo
    if confirm_action "是否显示完整的错误日志？" "n"; then
        # 这里可以显示更详细的日志
        echo "详细日志位置：$HOME/cliode-install.log"
    fi
}

# 自动重试操作
retry_operation() {
    local operation=$1
    local max_attempts=$2
    local operation_name=$3
    shift 3
    local args=("$@")

    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        echo -e "${YELLOW}正在尝试 $operation_name (第 $attempt/$max_attempts 次)${NC}"

        if "$operation" "${args[@]}"; then
            return 0
        else
            if [ $attempt -lt $max_attempts ]; then
                echo -e "${YELLOW}操作失败，3 秒后重试...${NC}"
                sleep 3
            fi
            attempt=$((attempt + 1))
        fi
    done

    echo -e "${RED}操作失败，已重试 $max_attempts 次${NC}"
    return 1
}

# 检查网络连接
check_network() {
    echo -e "${YELLOW}🌐 检查网络连接...${NC}"

    if ping -c 1 google.com &>/dev/null; then
        show_step_status "success" "网络连接正常"
        return 0
    elif ping -c 1 baidu.com &>/dev/null; then
        show_step_status "success" "网络连接正常"
        return 0
    else
        show_step_status "warning" "网络连接可能有问题"
        echo -e "${YELLOW}   建议检查网络设置或防火墙配置${NC}"
        return 1
    fi
}

# 检查系统资源
check_system_resources() {
    echo -e "${YELLOW}💾 检查系统资源...${NC}"

    # 检查磁盘空间（至少需要 100MB）
    local available_space=$(df -h "$HOME" | awk 'NR==2 {print $4}' | sed 's/G.*//')
    if [ -z "$available_space" ]; then
        # 尝试以字节为单位
        available_space=$(df -k "$HOME" | awk 'NR==2 {print $4}')
        available_space=$((available_space / 1024 / 1024))
    fi

    if [ "$available_space" -gt 100 ] 2>/dev/null; then
        show_step_status "success" "磁盘空间充足"
        return 0
    else
        show_step_status "warning" "磁盘空间可能不足"
        echo -e "${YELLOW}   建议释放至少 100MB 空间${NC}"
        return 1
    fi
}

# 选择安装模式
select_install_mode() {
    echo -e "\n${YELLOW}${BOLD}🎮 请选择安装模式：${NC}\n"
    echo -e "${CYAN}1. 向导模式（推荐新手）${NC}"
    echo -e "   - 详细的步骤说明和进度显示"
    echo -e "   - 可以选择安装哪些组件"
    echo -e "   - 自动打开浏览器获取 API Key"
    echo
    echo -e "${CYAN}2. 快速模式（推荐有经验用户）${NC}"
    echo -e "   - 自动安装所有组件"
    echo -e "   - 最小化用户交互"
    echo
    read -p "请选择 (1/2): " mode_choice

    case $mode_choice in
        1)
            wizard_mode
            ;;
        2)
            express_mode
            ;;
        *)
            echo -e "${YELLOW}无效选择，默认使用向导模式${NC}"
            wizard_mode
            ;;
    esac
}

# 向导模式
wizard_mode() {
    show_welcome
    show_system_info

    # 检查网络和系统资源
    check_network
    check_system_resources

    # 准备环境（安装缺失的依赖）
    prepare_environment

    # 选择安装组件
    select_components

    # 显示安装计划
    show_installation_plan

    # 执行安装
    execute_installation
}

# 快速模式
express_mode() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    快速安装模式                        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo

    # 默认所有组件都安装
    install_nvm=true
    install_claude=true
    configure_models=false

    echo -e "${YELLOW}将自动安装以下组件：${NC}"
    echo -e "${GREEN}✓${NC} NVM (Node Version Manager)"
    echo -e "${GREEN}✓${NC} Claude Code"
    echo

    if confirm_action "确认开始安装？" "y"; then
        # 准备环境（安装缺失的依赖）
        prepare_environment
        
        execute_installation
    else
        echo "安装已取消"
        exit 0
    fi
}

# 执行安装流程
execute_installation() {
    local total_steps=5
    local current_step=0

    # 步骤1：安装 NVM
    if [ "$install_nvm" = true ]; then
        current_step=$((current_step + 1))
        explain_step 1 "安装 NVM (Node Version Manager)" \
            "NVM 是一个 Node.js 版本管理器，可以轻松安装和切换不同版本的 Node.js"
        show_progress 0 $total_steps "正在安装 NVM..."

        if ! check_nvm; then
            # 直接调用安装函数
            local attempt=1
            while [ $attempt -le 3 ]; do
                echo -e "${YELLOW}正在尝试安装 NVM (第 $attempt/3 次)${NC}"
                if install_nvm; then
                    show_progress $current_step $total_steps "NVM 安装完成"
                    show_step_status "success" "NVM 安装成功: $(nvm --version)"
                    break
                else
                    if [ $attempt -lt 3 ]; then
                        echo -e "${YELLOW}安装失败，3 秒后重试...${NC}"
                        sleep 3
                        attempt=$((attempt + 1))
                    else
                        show_progress $current_step $total_steps "NVM 安装失败"
                        handle_error "NVM_INSTALL_FAILED" "NVM 安装失败"
                        exit 1
                    fi
                fi
            done
        else
            show_step_status "info" "NVM 已安装: $(nvm --version)"
        fi
    fi

    # 步骤2：安装 Node.js
    current_step=$((current_step + 1))
    explain_step 2 "安装 Node.js" \
        "Node.js 是一个 JavaScript 运行环境，是运行现代前端和后端应用的基础"
    show_progress $current_step $total_steps "正在安装 Node.js..."

    if ! check_command "node"; then
        if check_nvm; then
            (nvm install --lts &>/dev/null && nvm use --lts &>/dev/null) &
            spinner $! "安装 Node.js LTS 版本"

            if check_command "node"; then
                show_progress $current_step $total_steps "Node.js 安装完成"
                show_step_status "success" "Node.js 安装成功: $(node --version)"
            else
                show_progress $current_step $total_steps "Node.js 安装失败"
                handle_error "NODE_INSTALL_FAILED" "Node.js 安装失败"
                exit 1
            fi
        else
            show_progress $current_step $total_steps "Node.js 安装失败"
            handle_error "NODE_INSTALL_FAILED" "NVM 未安装，无法安装 Node.js"
            exit 1
        fi
    else
        show_step_status "info" "Node.js 已安装: $(node --version)"
    fi

    # 步骤3：更新 NPM
    current_step=$((current_step + 1))
    explain_step 3 "更新 NPM (Node 包管理器)" \
        "NPM 是 Node.js 的包管理器，用于安装和管理 JavaScript 包"
    show_progress $current_step $total_steps "正在更新 NPM..."

    if check_command "npm"; then
        npm install -g npm@latest &>/dev/null
        show_progress $current_step $total_steps "NPM 更新完成"
        show_step_status "success" "NPM 更新成功: $(npm --version)"
    else
        show_progress $current_step $total_steps "NPM 更新失败"
        handle_error "NPM_INSTALL_FAILED" "NPM 未安装"
        exit 1
    fi

    # 步骤4：安装 Claude Code
    current_step=$((current_step + 1))
    explain_step 4 "安装 Claude Code" \
        "安装 Claude Code - Anthropic AI 助手命令行工具"
    show_progress $current_step $total_steps "正在安装 Claude Code..."

    local installed_tools=()

    # 安装 Claude Code
    if [ "$install_claude" = true ]; then
        if install_cli_tool "@anthropic-ai/claude-code@latest" "Claude Code"; then
            installed_tools+=("Claude Code")
        fi
    fi

    if [ ${#installed_tools[@]} -gt 0 ]; then
        show_progress $current_step $total_steps "Claude Code 安装完成"
        show_step_status "success" "成功安装 Claude Code"
    else
        show_progress $current_step $total_steps "Claude Code 安装失败"
        handle_error "CLI_TOOL_INSTALL_FAILED" "Claude Code 安装失败"
    fi

    # 步骤5：配置 AI 模型
    if [ "$configure_models" = true ]; then
        current_step=$((current_step + 1))
        explain_step 5 "配置 AI 模型提供商" \
            "配置 AI 模型（MiniMax-M2、DeepSeek 或 GLM-4.6）以启用 Claude Code 的 AI 功能"
        show_progress $current_step $total_steps "正在配置 AI 模型..."

        if configure_claude_code; then
            show_progress $current_step $total_steps "AI 模型配置完成"
            show_step_status "success" "AI 模型配置成功"
        else
            show_progress $current_step $total_steps "AI 模型配置失败"
            handle_error "MODEL_CONFIG_FAILED" "AI 模型配置失败"
        fi
    fi

    # 安装完成
    echo
    show_success_summary
}

# 显示帮助信息
show_help() {
    cat << EOF
M2CC - Claude Code 多模型配置管理工具

使用方法：
    $0 [选项]

选项：
    -h, --help              显示此帮助信息
    -v, --version           显示版本信息
    -s, --switch PROVIDER   切换到指定的模型提供商
                           （例如：--switch minimax 或 --switch deepseek）
    -l, --list              列出所有已配置的模型提供商
    -c, --configure         进入模型配置向导
    --status                显示当前配置状态

示例：
    $0                      # 启动安装向导
    $0 --switch deepseek    # 切换到 DeepSeek 模型
    $0 --switch glm         # 切换到 GLM-4.6 模型
    $0 --switch glm-flash   # 切换到 GLM-4.5-Flash (免费) 模型
    $0 --list               # 查看所有已配置的模型
    $0 --configure          # 配置或重新配置模型

支持的模型提供商：
    - minimax     : MiniMax-M2 (高性能对话模型)
    - deepseek    : DeepSeek (代码生成专家)
    - glm         : GLM-4.6 (智谱 AI Coding Plan)
    - glm-flash   : 🆓 GLM-4.5-Flash (免费推荐) 🆓

EOF
}

# 显示主菜单
show_main_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${BOLD}                    M2CC 主菜单                            ${NC}${CYAN}║${NC}"
        echo -e "${CYAN}║${BOLD}            Claude Code 多模型配置管理工具               ${NC}${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo

        echo -e "${YELLOW}${BOLD}请选择操作：${NC}\n"

        echo -e "${CYAN} 1.${NC} 运行安装向导（向导模式）"
        echo -e "     - 详细的步骤说明和进度显示"
        echo -e "     - 可以选择安装哪些组件"
        echo -e "     - 自动打开浏览器获取 API Key"
        echo

        echo -e "${CYAN} 2.${NC} 快速安装（快速模式）"
        echo -e "     - 自动安装所有组件"
        echo -e "     - 最小化用户交互"
        echo

        echo -e "${CYAN} 3.${NC} 切换模型提供商"
        echo -e "     - 切换到不同的 AI 模型提供商"
        echo -e "     - 支持 MiniMax、DeepSeek、GLM-4.6、🆓GLM-4.5-Flash(免费)🆓"
        echo

        echo -e "${CYAN} 4.${NC} 查看已配置的模型"
        echo -e "     - 显示所有已配置的模型提供商"
        echo -e "     - 查看当前活跃的模型"
        echo

        echo -e "${CYAN} 5.${NC} 重新配置模型"
        echo -e "     - 配置或重新配置 AI 模型提供商"
        echo -e "     - 支持多个模型同时配置"
        echo

        echo -e "${CYAN} 6.${NC} 查看当前状态"
        echo -e "     - 查看 Claude Code 配置状态"
        echo -e "     - 显示配置文件位置"
        echo

        echo -e "${CYAN} 7.${NC} 查看帮助文档"
        echo -e "     - 查看详细的使用说明"
        echo -e "     - 查看支持的命令和选项"
        echo

        echo -e "${CYAN} 0.${NC} 退出"
        echo

        # 获取用户选择
        read -p "请输入选项编号 (0-7): " choice

        case $choice in
            1)
                echo -e "\n${GREEN}✓${NC} 已选择：运行安装向导（向导模式）\n"
                sleep 1
                wizard_mode
                echo
                read -p "按 Enter 键返回主菜单..."
                ;;
            2)
                echo -e "\n${GREEN}✓${NC} 已选择：快速安装（快速模式）\n"
                sleep 1
                express_mode
                echo
                read -p "按 Enter 键返回主菜单..."
                ;;
            3)
                echo -e "\n${GREEN}✓${NC} 已选择：切换模型提供商\n"
                init_provider_config
                select_provider_interactive
                echo
                read -p "按 Enter 键返回主菜单..."
                ;;
            4)
                echo -e "\n${GREEN}✓${NC} 已选择：查看已配置的模型\n"
                init_provider_config
                list_providers
                echo
                read -p "按 Enter 键返回主菜单..."
                ;;
            5)
                echo -e "\n${GREEN}✓${NC} 已选择：重新配置模型\n"
                init_provider_config
                configure_claude_code
                echo
                read -p "按 Enter 键返回主菜单..."
                ;;
            6)
                echo -e "\n${GREEN}✓${NC} 已选择：查看当前状态\n"
                init_provider_config
                list_providers
                echo
                if [ -f "$HOME/.claude/settings.json" ]; then
                    echo -e "${CYAN}${BOLD}当前活跃配置：${NC}"
                    echo -e "${GREEN}✓${NC} Claude Code 已配置"
                    echo -e "配置文件：${CYAN}$HOME/.claude/settings.json${NC}"
                else
                    echo -e "${YELLOW}⚠${NC} 未找到配置文件"
                fi
                echo
                read -p "按 Enter 键返回主菜单..."
                ;;
            7)
                echo -e "\n${GREEN}✓${NC} 已选择：查看帮助文档\n"
                sleep 0.5
                show_help
                echo
                read -p "按 Enter 键返回主菜单..."
                ;;
            0)
                echo -e "\n${GREEN}感谢使用 M2CC！再见！👋${NC}\n"
                exit 0
                ;;
            *)
                echo -e "\n${RED}❌ 无效选择，请输入 0-7 之间的数字${NC}"
                sleep 1
                ;;
        esac
    done
}

# 处理命令行参数（保持向后兼容）
handle_arguments() {
    local arg1="${1:-}"

    # 如果提供了命令行参数，优先处理命令行参数
    case "$arg1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            echo "M2CC version 0.0.4"
            echo "Claude Code Multi-Provider Configuration Tool"
            exit 0
            ;;
        -s|--switch)
            if [ -z "$2" ]; then
                log_error "请指定要切换的提供商"
                echo "使用 '$0 --help' 查看帮助"
                exit 1
            fi
            init_provider_config
            switch_provider "$2"
            exit $?
            ;;
        -l|--list)
            init_provider_config
            list_providers
            exit 0
            ;;
        -c|--configure)
            init_provider_config
            configure_claude_code
            exit $?
            ;;
        --status)
            init_provider_config
            list_providers
            echo
            if [ -f "$HOME/.claude/settings.json" ]; then
                echo -e "${CYAN}${BOLD}当前活跃配置：${NC}"
                echo -e "${GREEN}✓${NC} Claude Code 已配置"
                echo -e "配置文件：${CYAN}$HOME/.claude/settings.json${NC}"
            else
                echo -e "${YELLOW}⚠${NC} 未找到配置文件"
            fi
            exit 0
            ;;
        -*)
            log_error "未知参数: $arg1"
            echo "使用 '$0 --help' 查看帮助"
            exit 1
            ;;
    esac

    # 无参数时显示交互式菜单
    show_main_menu
}

# 主安装流程
main() {
    # 处理命令行参数（如果无参数则显示交互式菜单）
    handle_arguments "$@"
}

# 执行主函数
main "$@"
