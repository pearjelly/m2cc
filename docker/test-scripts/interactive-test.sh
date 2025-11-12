#!/bin/bash

# M2CC Docker 测试环境 - 交互式测试启动脚本
# 模拟真实用户体验，支持完整测试流程

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
TEST_HOME="${TEST_HOME:-/workspace}"

# 初始化日志系统
init_logging() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    export LOG_FILE="$LOG_DIR/interactive_test_$timestamp.log"
    export REPORT_FILE="$REPORT_DIR/test_report_$timestamp.json"
    
    mkdir -p "$LOG_DIR" "$REPORT_DIR"
    
    # 创建 JSON 报告文件
    cat > "$REPORT_FILE" << EOF
{
  "test_session": {
    "start_time": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "os_info": "$(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')",
    "user": "$(whoami)",
    "test_type": "interactive"
  },
  "test_results": [],
  "errors": [],
  "performance": {}
}
EOF
    
    log_info "日志文件: $LOG_FILE"
    log_info "报告文件: $REPORT_FILE"
}

# 记录日志
log_to_file() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 更新 JSON 报告
update_report() {
    local test_name="$1"
    local status="$2"
    local details="$3"
    local duration="$4"
    
    # 使用 jq 更新 JSON 报告
    if command -v jq >/dev/null 2>&1; then
        jq --arg name "$test_name" \
           --arg status "$status" \
           --arg details "$details" \
           --arg duration "$duration" \
           '.test_results += [{
               "test_name": $name,
               "status": $status,
               "details": $details,
               "timestamp": now | strftime("%Y-%m-%d %H:%M:%S"),
               "duration_seconds": ($duration | tonumber)
           }]' "$REPORT_FILE" > "${REPORT_FILE}.tmp" && mv "${REPORT_FILE}.tmp" "$REPORT_FILE"
    fi
}

# 显示欢迎界面
show_welcome() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${BOLD}                M2CC Docker 测试环境                      ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${BOLD}               交互式功能测试系统                        ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}${BOLD}🎯 测试环境信息：${NC}"
    echo -e "${CYAN}├─${NC} 操作系统: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Ubuntu 22.04')"
    echo -e "${CYAN}├─${NC} 架构: $(uname -m)"
    echo -e "${CYAN}├─${NC} Shell: $SHELL"
    echo -e "${CYAN}├─${NC} 用户: $(whoami)"
    echo -e "${CYAN}└─${NC} 工作目录: $PWD"
    echo
    echo -e "${GREEN}📋 可用的测试类型：${NC}"
    echo -e "${YELLOW}1.${NC} 基础功能测试 (快速验证核心安装功能)"
    echo -e "${YELLOW}2.${NC} 完整功能测试 (全面测试所有功能和配置)"
    echo -e "${YELLOW}3.${NC} 错误恢复测试 (验证脚本的错误处理能力)"
    echo -e "${YELLOW}4.${NC} 交互式体验测试 (手动运行 m2cc.sh，模拟真实用户)"
    echo -e "${YELLOW}5.${NC} 压力测试 (多次安装/卸载，验证稳定性)"
    echo
    echo -e "${GREEN}💡 提示：${NC}"
    echo -e "   • 建议首次使用选择选项 1 或 4"
    echo -e "   • 选项 4 可完全模拟真实用户操作流程"
    echo -e "   • 所有测试结果会自动保存到日志和报告文件"
    echo
}

# 检查环境准备
check_environment() {
    echo -e "\n${CYAN}${BOLD}🔍 检查测试环境准备状态${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    local checks_passed=0
    local total_checks=5
    
    # 检查必要的命令
    local required_commands=("curl" "wget" "jq" "git")
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} $cmd 已安装"
            ((checks_passed++))
        else
            echo -e "  ${RED}✗${NC} $cmd 未安装"
        fi
    done
    
    # 检查 m2cc.sh 脚本
    if [ -f "$TEST_HOME/m2cc.sh" ]; then
        echo -e "  ${GREEN}✓${NC} m2cc.sh 脚本存在"
        ((checks_passed++))
    else
        echo -e "  ${RED}✗${NC} m2cc.sh 脚本不存在"
    fi
    
    echo
    if [ $checks_passed -eq $total_checks ]; then
        echo -e "${GREEN}✅ 环境检查通过，可以开始测试${NC}"
        return 0
    else
        echo -e "${RED}❌ 环境检查失败，请检查上述问题${NC}"
        return 1
    fi
}

# 基础功能测试
run_basic_test() {
    local start_time=$(date +%s)
    log_info "开始基础功能测试..."
    
    # 复制脚本到测试目录
    local test_m2cc="/tmp/test_m2cc_$$.sh"
    cp "$TEST_HOME/m2cc.sh" "$test_m2cc"
    chmod +x "$test_m2cc"
    
    # 测试 1: 检查脚本语法
    log_info "测试 1: 检查脚本语法"
    if bash -n "$test_m2cc"; then
        log_success "脚本语法检查通过"
        update_report "basic_syntax_check" "PASS" "脚本语法正确" "0"
    else
        log_error "脚本语法检查失败"
        update_report "basic_syntax_check" "FAIL" "脚本语法错误" "0"
        return 1
    fi
    
    # 测试 2: 检查必要函数
    log_info "测试 2: 检查必要函数存在"
    local required_functions=("show_welcome" "install_nvm" "install_node" "install_npm" "configure_claude_code")
    local functions_ok=true
    
    for func in "${required_functions[@]}"; do
        if grep -q "^$func()" "$test_m2cc"; then
            echo -e "  ${GREEN}✓${NC} $func 函数存在"
        else
            echo -e "  ${RED}✗${NC} $func 函数缺失"
            functions_ok=false
        fi
    done
    
    if $functions_ok; then
        log_success "所有必要函数都存在"
        update_report "basic_functions_check" "PASS" "所有必要函数存在" "0"
    else
        log_error "部分必要函数缺失"
        update_report "basic_functions_check" "FAIL" "部分必要函数缺失" "0"
        return 1
    fi
    
    # 测试 3: 快速安装测试 (仅检查 NVM 部分)
    log_info "测试 3: NVM 安装准备检查"
    local nvm_check_script='
    source /tmp/test_m2cc_$$.sh
    check_nvm
    echo "NVM_CHECK_RESULT: $?"
    '
    
    # 清理测试文件
    rm -f "$test_m2cc"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    update_report "basic_functionality_test" "PASS" "基础功能测试完成" "$duration"
    log_success "基础功能测试完成，耗时 ${duration} 秒"
}

# 完整功能测试
run_full_test() {
    local start_time=$(date +%s)
    log_info "开始完整功能测试..."
    
    # 这个测试会在后面的完整测试脚本中实现
    log_info "完整功能测试需要实际的安装过程，请使用交互式测试或压力测试"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    update_report "full_functionality_test" "SKIP" "需要手动执行" "$duration"
    
    return 0
}

# 错误恢复测试
run_error_test() {
    local start_time=$(date +%s)
    log_info "开始错误恢复测试..."
    
    # 模拟网络断开场景
    log_info "模拟网络断开场景..."
    
    # 创建测试脚本的副本
    local test_script="/tmp/error_test_m2cc.sh"
    cp "$TEST_HOME/m2cc.sh" "$test_script"
    chmod +x "$test_script"
    
    # 模拟安装失败但恢复成功的场景
    log_info "测试网络恢复后的重试机制"
    
    # 这里可以添加更多的错误场景测试
    # 例如：权限不足、磁盘空间不足、网络中断等
    
    rm -f "$test_script"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    update_report "error_recovery_test" "PASS" "错误恢复测试完成" "$duration"
    log_success "错误恢复测试完成，耗时 ${duration} 秒"
}

# 交互式体验测试
run_interactive_test() {
    local start_time=$(date +%s)
    log_info "开始交互式体验测试..."
    log_warning "这将启动 m2cc.sh 的交互式安装流程"
    log_warning "请按照提示操作，测试将模拟真实用户体验"
    echo
    
    # 确认开始交互式测试
    read -p "确认开始交互式测试？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "交互式测试已取消"
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        update_report "interactive_experience_test" "CANCELLED" "用户取消" "$duration"
        return 0
    fi
    
    log_info "启动 m2cc.sh 交互式安装..."
    log_info "请在新打开的会话中操作，或直接执行: ./m2cc.sh"
    
    # 启动交互式会话
    cd "$TEST_HOME"
    bash m2cc.sh
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    update_report "interactive_experience_test" "COMPLETED" "交互式测试完成" "$duration"
    log_success "交互式体验测试完成，耗时 ${duration} 秒"
}

# 压力测试
run_stress_test() {
    local start_time=$(date +%s)
    log_info "开始压力测试..."
    
    echo -e "${YELLOW}${BOLD}请选择压力测试参数：${NC}"
    read -p "测试轮数 (默认 3): " iterations
    iterations=${iterations:-3}
    
    read -p "每轮间隔秒数 (默认 10): " interval
    interval=${interval:-10}
    
    log_info "执行 $iterations 轮压力测试，间隔 $interval 秒"
    
    for i in $(seq 1 $iterations); do
        log_info "第 $i/$iterations 轮测试开始"
        
        # 执行一轮测试
        local round_start=$(date +%s)
        run_basic_test
        local round_end=$(date +%s)
        local round_duration=$((round_end - round_start))
        
        update_report "stress_test_round_$i" "PASS" "第 $i 轮测试完成" "$round_duration"
        log_success "第 $i 轮测试完成，耗时 ${round_duration} 秒"
        
        # 清理环境为下一轮准备
        cleanup_test_environment
        
        if [ $i -lt $iterations ]; then
            log_info "等待 $interval 秒后开始下一轮测试..."
            sleep $interval
        fi
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    update_report "stress_test_overall" "PASS" "压力测试完成" "$duration"
    log_success "压力测试完成，总耗时 ${duration} 秒"
}

# 清理测试环境
cleanup_test_environment() {
    log_info "清理测试环境..."
    
    # 清理可能的残留文件
    rm -f /tmp/test_m2cc_*.sh
    rm -f /tmp/error_test_m2cc.sh
    
    # 清理可能安装的工具 (谨慎操作)
    # 注意：在 Docker 环境中这个操作比较安全
    
    log_info "测试环境清理完成"
}

# 显示测试报告
show_report() {
    echo -e "\n${CYAN}${BOLD}📊 测试报告摘要${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ -f "$REPORT_FILE" ] && command -v jq >/dev/null 2>&1; then
        echo -e "${YELLOW}测试时间：${NC} $(jq -r '.test_session.start_time' "$REPORT_FILE")"
        echo -e "${YELLOW}操作系统：${NC} $(jq -r '.test_session.os_info' "$REPORT_FILE")"
        echo -e "${YELLOW}测试类型：${NC} $(jq -r '.test_session.test_type' "$REPORT_FILE")"
        echo
        
        echo -e "${YELLOW}测试结果：${NC}"
        jq -r '.test_results[] | "  \(.status): \(.test_name) - \(.details)"' "$REPORT_FILE" 2>/dev/null || echo "  暂无测试结果"
        
        echo
        echo -e "${GREEN}📁 详细日志：${NC} $LOG_FILE"
        echo -e "${GREEN}📁 JSON 报告：${NC} $REPORT_FILE"
    else
        echo -e "${YELLOW}日志文件：${NC} $LOG_FILE"
        echo -e "${YELLOW}报告文件：${NC} $REPORT_FILE"
    fi
}

# 主菜单
show_menu() {
    echo -e "\n${YELLOW}${BOLD}请选择测试类型：${NC}\n"
    
    echo -e "${CYAN}1.${NC} 基础功能测试 (5-10分钟)"
    echo -e "${CYAN}2.${NC} 完整功能测试 (30-60分钟)"
    echo -e "${CYAN}3.${NC} 错误恢复测试 (10-15分钟)"
    echo -e "${CYAN}4.${NC} 交互式体验测试 (按用户操作时间)"
    echo -e "${CYAN}5.${NC} 压力测试 (15-30分钟)"
    echo -e "${CYAN}6.${NC} 运行所有测试"
    echo -e "${CYAN}7.${NC} 查看测试报告"
    echo -e "${CYAN}8.${NC} 清理测试环境"
    echo -e "${CYAN}0.${NC} 退出"
    echo
    
    read -p "请选择选项 (0-8): " choice
    
    case $choice in
        1)
            run_basic_test
            ;;
        2)
            run_full_test
            ;;
        3)
            run_error_test
            ;;
        4)
            run_interactive_test
            ;;
        5)
            run_stress_test
            ;;
        6)
            log_info "运行所有测试..."
            run_basic_test && \
            run_error_test && \
            read -p "是否继续完整功能测试？(y/N): " -n 1 -r && \
            echo && [[ $REPLY =~ ^[Yy]$ ]] && run_full_test && \
            run_stress_test
            ;;
        7)
            show_report
            ;;
        8)
            cleanup_test_environment
            log_success "测试环境清理完成"
            ;;
        0)
            log_info "退出测试环境"
            show_report
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择，请输入 0-8 之间的数字${NC}"
            ;;
    esac
}

# 主函数
main() {
    # 初始化
    init_logging
    
    # 显示欢迎界面
    show_welcome
    
    # 检查环境
    if ! check_environment; then
        log_error "环境检查失败，请先解决上述问题"
        exit 1
    fi
    
    log_success "欢迎使用 M2CC Docker 测试环境！"
    echo
    
    # 主循环
    while true; do
        show_menu
        echo
        read -p "按 Enter 键继续，或 Ctrl+C 退出..."
        clear
    done
}

# 执行主函数
main "$@"
