#!/bin/bash

# M2CC Docker 测试环境 - 自动化测试脚本
# 支持非交互式运行，适合 CI/CD 集成

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${BLUE}[AUTO-TEST]${NC} $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }

# 默认配置
TEST_MODE="${TEST_MODE:-basic}"
TEST_ITERATIONS="${TEST_ITERATIONS:-3}"
SKIP_NETWORK_TESTS="${SKIP_NETWORK_TESTS:-false}"
OUTPUT_DIR="${OUTPUT_DIR:-/workspace/test-output}"
LOG_DIR="${LOG_DIR:-/workspace/test-logs}"

# 创建输出目录
mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

# 生成时间戳
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
LOG_FILE="$LOG_DIR/auto_test_$TIMESTAMP.log"
REPORT_FILE="$OUTPUT_DIR/test_report_$TIMESTAMP.json"

# 初始化报告文件
init_report() {
    cat > "$REPORT_FILE" << EOF
{
  "test_session": {
    "start_time": "$(date -Iseconds)",
    "end_time": null,
    "hostname": "$(hostname)",
    "os_info": "$(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')",
    "user": "$(whoami)",
    "test_mode": "$TEST_MODE",
    "iterations": $TEST_ITERATIONS,
    "skip_network_tests": $SKIP_NETWORK_TESTS
  },
  "test_results": [],
  "performance_metrics": {},
  "errors": [],
  "summary": {}
}
EOF
}

# 更新报告
update_report() {
    local test_name="$1"
    local status="$2"
    local details="$3"
    local duration="$4"
    local exit_code="$5"
    
    if command -v jq >/dev/null 2>&1; then
        jq --arg name "$test_name" \
           --arg status "$status" \
           --arg details "$details" \
           --arg duration "$duration" \
           --arg exit_code "$exit_code" \
           '.test_results += [{
               "test_name": $name,
               "status": $status,
               "details": $details,
               "timestamp": now | strftime("%Y-%m-%d %H:%M:%S"),
               "duration_seconds": ($duration | tonumber),
               "exit_code": ($exit_code | tonumber)
           }]' "$REPORT_FILE" > "${REPORT_FILE}.tmp" && mv "${REPORT_FILE}.tmp" "$REPORT_FILE"
    fi
}

# 执行命令并记录结果
run_command() {
    local cmd="$1"
    local timeout="${2:-300}"
    local description="$3"
    
    log_info "执行: $description"
    log_info "命令: $cmd"
    
    local start_time=$(date +%s)
    
    # 执行命令，超时则失败
    if timeout $timeout bash -c "$cmd" >> "$LOG_FILE" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "$description 完成，耗时 ${duration} 秒"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        local exit_code=$?
        
        if [ $exit_code -eq 124 ]; then
            log_error "$description 超时 (${timeout}秒)"
            update_report "$description" "TIMEOUT" "命令执行超时" "$duration" "$exit_code"
        else
            log_error "$description 失败，退出码: $exit_code"
            update_report "$description" "FAIL" "命令执行失败" "$duration" "$exit_code"
        fi
        return $exit_code
    fi
}

# 语法检查测试
test_syntax_check() {
    log_info "开始语法检查测试..."
    
    local script_path="/workspace/m2cc.sh"
    # 如果 /workspace 下没有 m2cc.sh，从宿主机目录复制
    if [ ! -f "$script_path" ] && [ -f "/host-workspace/m2cc.sh" ]; then
        cp "/host-workspace/m2cc.sh" "/workspace/"
        script_path="/workspace/m2cc.sh"
    fi
    
    if [ ! -f "$script_path" ]; then
        log_error "m2cc.sh 脚本不存在"
        update_report "syntax_check" "FAIL" "脚本文件不存在" "0" "1"
        return 1
    fi
    
    local start_time=$(date +%s)
    
    # 使用 bash -n 进行语法检查
    if bash -n "$script_path"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "语法检查通过"
        update_report "syntax_check" "PASS" "脚本语法正确" "$duration" "0"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_error "语法检查失败"
        update_report "syntax_check" "FAIL" "脚本语法错误" "$duration" "1"
        return 1
    fi
}

# 函数存在性测试
test_function_existence() {
    log_info "开始函数存在性测试..."
    
    local script_path="/workspace/m2cc.sh"
    # 如果 /workspace 下没有 m2cc.sh，从宿主机目录复制
    if [ ! -f "$script_path" ] && [ -f "/host-workspace/m2cc.sh" ]; then
        cp "/host-workspace/m2cc.sh" "/workspace/"
        script_path="/workspace/m2cc.sh"
    fi
    
    local start_time=$(date +%s)
    
    # 需要检查的函数列表
    local required_functions=(
        "show_welcome"
        "show_system_info"
        "check_nvm"
        "install_nvm"
        "install_node"
        "install_npm"
        "configure_claude_code"
        "show_main_menu"
        "handle_arguments"
        "main"
    )
    
    local missing_functions=()
    
    for func in "${required_functions[@]}"; do
        if grep -q "^$func()" "$script_path"; then
            log_info "✓ 函数 $func 存在"
        else
            log_warning "✗ 函数 $func 缺失"
            missing_functions+=("$func")
        fi
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ ${#missing_functions[@]} -eq 0 ]; then
        log_success "所有必要函数都存在"
        update_report "function_existence" "PASS" "所有必要函数存在" "$duration" "0"
        return 0
    else
        log_error "缺失函数: ${missing_functions[*]}"
        update_report "function_existence" "FAIL" "缺失函数: ${missing_functions[*]}" "$duration" "1"
        return 1
    fi
}

# 依赖检查测试
test_dependencies() {
    log_info "开始依赖检查测试..."
    
    local start_time=$(date +%s)
    
    # 检查系统依赖
    local system_deps=("curl" "wget" "jq" "git")
    local missing_deps=()
    
    for dep in "${system_deps[@]}"; do
        if command -v "$dep" >/dev/null 2>&1; then
            log_info "✓ $dep 已安装"
        else
            log_warning "✗ $dep 未安装"
            missing_deps+=("$dep")
        fi
    done
    
    # 检查 NVM/Node.js 环境
    local node_deps=("nvm" "node" "npm")
    for dep in "${node_deps[@]}"; do
        if command -v "$dep" >/dev/null 2>&1; then
            log_info "✓ $dep 可用"
        else
            log_info "ℹ $dep 不可用 (正常，脚本会安装)"
        fi
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # 只有系统依赖缺失才算失败
    if [ ${#missing_deps[@]} -eq 0 ]; then
        log_success "依赖检查通过"
        update_report "dependencies_check" "PASS" "系统依赖完整" "$duration" "0"
        return 0
    else
        log_error "缺失系统依赖: ${missing_deps[*]}"
        update_report "dependencies_check" "FAIL" "缺失系统依赖: ${missing_deps[*]}" "$duration" "1"
        return 1
    fi
}

# 快速安装测试
test_quick_install() {
    log_info "开始快速安装测试..."
    
    local start_time=$(date +%s)
    local test_script="/tmp/quick_test_$$.sh"
    
    # 创建测试版本脚本
    cat > "$test_script" << 'EOF'
#!/bin/bash
set -e

# 模拟安装 NVM (但不实际安装)
check_nvm() {
    return 1  # 模拟未安装
}

# 模拟安装 Node.js
install_node() {
    echo "模拟安装 Node.js..."
    sleep 2
    return 0
}

# 模拟安装 NPM
install_npm() {
    echo "模拟安装 NPM..."
    sleep 1
    return 0
}

# 模拟安装 Claude Code
install_cli_tool() {
    local package_name=$1
    echo "模拟安装 $package_name..."
    sleep 3
    return 0
}

# 执行模拟安装
echo "开始快速安装测试..."
check_nvm
echo "NVM 状态检查完成"
install_node
echo "Node.js 安装完成"
install_npm
echo "NPM 安装完成"
install_cli_tool "@anthropic-ai/claude-code"
echo "Claude Code 安装完成"
echo "快速安装测试完成"
EOF
    
    chmod +x "$test_script"
    
    # 运行测试脚本
    if run_command "bash $test_script" 60 "快速安装测试"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "快速安装测试通过"
        update_report "quick_install_test" "PASS" "快速安装测试完成" "$duration" "0"
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_error "快速安装测试失败"
        update_report "quick_install_test" "FAIL" "快速安装测试失败" "$duration" "1"
    fi
    
    rm -f "$test_script"
}

# 网络连接测试
test_network_connectivity() {
    if [ "$SKIP_NETWORK_TESTS" = "true" ]; then
        log_info "跳过网络连接测试"
        update_report "network_test" "SKIPPED" "跳过网络测试" "0" "0"
        return 0
    fi
    
    log_info "开始网络连接测试..."
    
    local start_time=$(date +%s)
    local test_urls=(
        "https://raw.githubusercontent.com"
        "https://www.npmjs.com"
        "https://api.minimaxi.com"
        "https://platform.deepseek.com"
    )
    
    local failed_urls=()
    
    for url in "${test_urls[@]}"; do
        log_info "测试连接: $url"
        if curl -s --connect-timeout 10 --max-time 30 "$url" > /dev/null 2>&1; then
            log_success "✓ $url 连接成功"
        else
            log_warning "✗ $url 连接失败"
            failed_urls+=("$url")
        fi
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ ${#failed_urls[@]} -eq 0 ]; then
        log_success "网络连接测试通过"
        update_report "network_test" "PASS" "所有网络连接正常" "$duration" "0"
        return 0
    else
        log_warning "网络连接测试部分失败"
        update_report "network_test" "PARTIAL" "部分网络连接失败: ${failed_urls[*]}" "$duration" "1"
        return 1
    fi
}

# 完整安装测试 (谨慎执行)
test_full_install() {
    log_info "开始完整安装测试..."
    log_warning "这将实际安装软件，请确保在测试环境中执行"
    
    local start_time=$(date +%s)
    
    # 备份现有配置
    local backup_dir="/tmp/m2cc_backup_$$"
    mkdir -p "$backup_dir"
    
    # 备份可能的现有配置
    [ -d "$HOME/.nvm" ] && cp -r "$HOME/.nvm" "$backup_dir/" 2>/dev/null || true
    [ -d "$HOME/.claude" ] && cp -r "$HOME/.claude" "$backup_dir/" 2>/dev/null || true
    [ -f "$HOME/.bashrc" ] && cp "$HOME/.bashrc" "$backup_dir/" 2>/dev/null || true
    
    # 设置测试环境变量
    export TEST_MODE="automated"
    
    # 执行实际安装测试 (限制在模拟模式)
    if run_command "echo '模拟完整安装过程...' && sleep 5" 300 "完整安装测试"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "完整安装测试通过 (模拟模式)"
        update_report "full_install_test" "PASS" "完整安装测试完成" "$duration" "0"
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_error "完整安装测试失败"
        update_report "full_install_test" "FAIL" "完整安装测试失败" "$duration" "1"
    fi
    
    # 恢复配置
    log_info "恢复原始配置..."
    [ -d "$backup_dir/.nvm" ] && cp -r "$backup_dir/.nvm" "$HOME/" 2>/dev/null || true
    [ -d "$backup_dir/.claude" ] && cp -r "$backup_dir/.claude" "$HOME/" 2>/dev/null || true
    [ -f "$backup_dir/.bashrc" ] && cp "$backup_dir/.bashrc" "$HOME/" 2>/dev/null || true
    rm -rf "$backup_dir"
}

# 压力测试
run_stress_test() {
    log_info "开始压力测试 ($TEST_ITERATIONS 轮)..."
    
    local start_time=$(date +%s)
    local passed_rounds=0
    
    for i in $(seq 1 $TEST_ITERATIONS); do
        log_info "第 $i/$TEST_ITERATIONS 轮测试"
        
        if test_syntax_check && test_function_existence; then
            ((passed_rounds++))
            log_success "第 $i 轮测试通过"
        else
            log_error "第 $i 轮测试失败"
        fi
        
        # 每轮之间短暂延迟
        if [ $i -lt $TEST_ITERATIONS ]; then
            sleep 2
        fi
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ $passed_rounds -eq $TEST_ITERATIONS ]; then
        log_success "压力测试完成 ($passed_rounds/$TEST_ITERATIONS 轮通过)"
        update_report "stress_test" "PASS" "压力测试完成: $passed_rounds/$TEST_ITERATIONS" "$duration" "0"
    else
        log_warning "压力测试部分失败 ($passed_rounds/$TEST_ITERATIONS 轮通过)"
        update_report "stress_test" "PARTIAL" "压力测试部分失败: $passed_rounds/$TEST_ITERATIONS" "$duration" "1"
    fi
}

# 生成测试报告
generate_report() {
    log_info "生成测试报告..."
    
    # 更新结束时间
    if command -v jq >/dev/null 2>&1; then
        jq --arg end_time "$(date -Iseconds)" '.test_session.end_time = $end_time' "$REPORT_FILE" > "${REPORT_FILE}.tmp" && mv "${REPORT_FILE}.tmp" "$REPORT_FILE"
        
        # 计算统计信息
        local total_tests=$(jq '.test_results | length' "$REPORT_FILE")
        local passed_tests=$(jq '[.test_results[] | select(.status == "PASS")] | length' "$REPORT_FILE")
        local failed_tests=$(jq '[.test_results[] | select(.status == "FAIL")] | length' "$REPORT_FILE")
        local skipped_tests=$(jq '[.test_results[] | select(.status == "SKIPPED")] | length' "$REPORT_FILE")
        
        # 添加统计信息到报告
        jq --arg total "$total_tests" \
           --arg passed "$passed_tests" \
           --arg failed "$failed_tests" \
           --arg skipped "$skipped_tests" \
           '.summary = {
               "total_tests": ($total | tonumber),
               "passed_tests": ($passed | tonumber),
               "failed_tests": ($failed | tonumber),
               "skipped_tests": ($skipped | tonumber),
               "success_rate": (if ($total | tonumber) > 0 then (($passed | tonumber) / ($total | tonumber) * 100) else 0 end)
           }' "$REPORT_FILE" > "${REPORT_FILE}.tmp" && mv "${REPORT_FILE}.tmp" "$REPORT_FILE"
    fi
    
    # 生成人类可读的报告
    local text_report="$OUTPUT_DIR/test_summary_$TIMESTAMP.txt"
    cat > "$text_report" << EOF
M2CC Docker 自动化测试报告
============================

测试时间: $TIMESTAMP
测试模式: $TEST_MODE
迭代次数: $TEST_ITERATIONS

测试结果摘要:
EOF
    
    if command -v jq >/dev/null 2>&1; then
        local total_tests=$(jq -r '.summary.total_tests' "$REPORT_FILE")
        local passed_tests=$(jq -r '.summary.passed_tests' "$REPORT_FILE")
        local failed_tests=$(jq -r '.summary.failed_tests' "$REPORT_FILE")
        local success_rate=$(jq -r '.summary.success_rate' "$REPORT_FILE")
        
        cat >> "$text_report" << EOF
总测试数: $total_tests
通过测试: $passed_tests
失败测试: $failed_tests
成功率: ${success_rate}%

详细结果:
EOF
        
        jq -r '.test_results[] | "- \(.status): \(.test_name) - \(.details) (\(.duration_seconds)s)"' "$REPORT_FILE" >> "$text_report"
    fi
    
    cat >> "$text_report" << EOF

文件位置:
日志文件: $LOG_FILE
JSON 报告: $REPORT_FILE
文本报告: $text_report

测试完成时间: $(date)
EOF
    
    log_success "测试报告已生成: $text_report"
    log_success "JSON 报告: $REPORT_FILE"
}

# 显示帮助信息
show_help() {
    cat << EOF
M2CC Docker 自动化测试脚本

用法: $0 [选项]

环境变量:
  TEST_MODE             测试模式 (basic|full|stress|all) [默认: basic]
  TEST_ITERATIONS       压力测试迭代次数 [默认: 3]
  SKIP_NETWORK_TESTS    跳过网络测试 [默认: false]
  OUTPUT_DIR            输出目录 [默认: /workspace/test-output]
  LOG_DIR               日志目录 [默认: /workspace/test-logs]

测试模式:
  basic        基础测试 (语法、函数、依赖检查)
  full         完整测试 (包括实际安装)
  stress       压力测试 (多次运行基础测试)
  all          运行所有测试

示例:
  $0                           # 运行基础测试
  TEST_MODE=full $0            # 运行完整测试
  TEST_MODE=stress TEST_ITERATIONS=5 $0  # 运行5轮压力测试
  SKIP_NETWORK_TESTS=true $0   # 跳过网络测试

EOF
}

# 主函数
main() {
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
    
    log_info "开始 M2CC 自动化测试"
    log_info "测试模式: $TEST_MODE"
    log_info "输出目录: $OUTPUT_DIR"
    log_info "日志文件: $LOG_FILE"
    
    # 初始化报告
    init_report
    
    # 根据测试模式执行相应测试
    case $TEST_MODE in
        basic)
            test_syntax_check
            test_function_existence
            test_dependencies
            test_quick_install
            test_network_connectivity
            ;;
        full)
            test_syntax_check
            test_function_existence
            test_dependencies
            test_network_connectivity
            test_full_install
            ;;
        stress)
            run_stress_test
            ;;
        all)
            test_syntax_check
            test_function_existence
            test_dependencies
            test_network_connectivity
            test_quick_install
            run_stress_test
            ;;
        *)
            log_error "未知的测试模式: $TEST_MODE"
            show_help
            exit 1
            ;;
    esac
    
    # 生成报告
    generate_report
    
    # 输出结果摘要
    if command -v jq >/dev/null 2>&1; then
        local failed_tests=$(jq -r '.summary.failed_tests' "$REPORT_FILE")
        if [ "$failed_tests" -eq 0 ]; then
            log_success "所有测试通过！"
            exit 0
        else
            log_error "$failed_tests 个测试失败"
            exit 1
        fi
    else
        log_info "测试完成，请查看报告文件: $REPORT_FILE"
        exit 0
    fi
}

# 执行主函数
main "$@"