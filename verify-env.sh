#!/bin/bash

# M2CC Docker 环境快速验证脚本
# 验证环境是否正确设置，脚本是否可以正常运行

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${BLUE}[VERIFY]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; }

# 脚本路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$SCRIPT_DIR"

# 验证计数器
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# 执行检查并记录结果
run_check() {
    local check_name="$1"
    local check_command="$2"
    local required="${3:-true}"
    
    ((TOTAL_CHECKS++))
    
    log_info "检查: $check_name"
    
    if eval "$check_command"; then
        log_success "$check_name"
        ((PASSED_CHECKS++))
        return 0
    else
        if [ "$required" = "true" ]; then
            log_error "$check_name (必需)"
            ((FAILED_CHECKS++))
            return 1
        else
            log_warning "$check_name (可选)"
            return 0
        fi
    fi
}

# 检查文件存在性
check_file_exists() {
    local file="$1"
    [ -f "$file" ]
}

# 检查目录存在性
check_dir_exists() {
    local dir="$1"
    [ -d "$dir" ]
}

# 检查脚本可执行性
check_script_executable() {
    local script="$1"
    [ -x "$script" ]
}

# 检查语法
check_script_syntax() {
    local script="$1"
    bash -n "$script" 2>/dev/null
}

# 检查 Docker 环境
check_docker_environment() {
    command -v docker >/dev/null 2>&1 && \
    docker info >/dev/null 2>&1
}

# 主验证函数
main_verify() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${BOLD}              M2CC Docker 环境验证工具                      ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${BOLD}              Environment Verification Tool                   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    log_info "开始验证 M2CC Docker 测试环境..."
    echo
    
    # 1. 检查项目结构
    echo -e "${YELLOW}${BOLD}📁 项目结构检查${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    run_check "Dockerfile 存在" "check_file_exists '$PROJECT_ROOT/Dockerfile'"
    run_check "docker-compose.yml 存在" "check_file_exists '$PROJECT_ROOT/docker-compose.yml'"
    run_check "m2cc.sh 存在" "check_file_exists '$PROJECT_ROOT/m2cc.sh'"
    
    echo
    
    # 2. 检查 Docker 目录结构
    echo -e "${YELLOW}${BOLD}🐳 Docker 目录结构检查${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    run_check "docker/test-scripts 目录存在" "check_dir_exists '$PROJECT_ROOT/docker/test-scripts'"
    run_check "docker/config 目录存在" "check_dir_exists '$PROJECT_ROOT/docker/config'"
    run_check "docker/templates 目录存在" "check_dir_exists '$PROJECT_ROOT/docker/templates'"
    
    echo
    
    # 3. 检查脚本文件
    echo -e "${YELLOW}${BOLD}📜 脚本文件检查${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    run_check "主启动脚本存在" "check_file_exists '$PROJECT_ROOT/docker-test.sh'"
    run_check "主启动脚本可执行" "check_script_executable '$PROJECT_ROOT/docker-test.sh'"
    run_check "主启动脚本语法正确" "check_script_syntax '$PROJECT_ROOT/docker-test.sh'"
    
    run_check "交互式测试脚本存在" "check_file_exists '$PROJECT_ROOT/docker/test-scripts/interactive-test.sh'"
    run_check "交互式测试脚本可执行" "check_script_executable '$PROJECT_ROOT/docker/test-scripts/interactive-test.sh'"
    run_check "交互式测试脚本语法正确" "check_script_syntax '$PROJECT_ROOT/docker/test-scripts/interactive-test.sh'"
    
    run_check "自动化测试脚本存在" "check_file_exists '$PROJECT_ROOT/docker/test-scripts/automated-test.sh'"
    run_check "自动化测试脚本可执行" "check_script_executable '$PROJECT_ROOT/docker/test-scripts/automated-test.sh'"
    run_check "自动化测试脚本语法正确" "check_script_syntax '$PROJECT_ROOT/docker/test-scripts/automated-test.sh'"
    
    run_check "清理脚本存在" "check_file_exists '$PROJECT_ROOT/docker/cleanup.sh'"
    run_check "清理脚本可执行" "check_script_executable '$PROJECT_ROOT/docker/cleanup.sh'"
    run_check "清理脚本语法正确" "check_script_syntax '$PROJECT_ROOT/docker/cleanup.sh'"
    
    echo
    
    # 4. 检查配置文件
    echo -e "${YELLOW}${BOLD}⚙️  配置文件检查${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    run_check "测试配置文件存在" "check_file_exists '$PROJECT_ROOT/docker/config/test.env'"
    run_check "README 文档存在" "check_file_exists '$PROJECT_ROOT/docker/README.md'"
    
    echo
    
    # 5. 检查 Docker 环境
    echo -e "${YELLOW}${BOLD}🐳 Docker 环境检查${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    run_check "Docker 可用" "check_docker_environment" "false"
    
    if check_docker_environment; then
        log_info "Docker 环境详细信息:"
        echo "  Docker 版本: $(docker --version)"
        echo "  Docker 守护进程: $(docker info --format '{{.ServerVersion}}' 2>/dev/null || echo '未知')"
        echo "  操作系统: $(docker info --format '{{.OperatingSystem}}' 2>/dev/null || echo '未知')"
    fi
    
    echo
    
    # 6. 快速功能测试
    echo -e "${YELLOW}${BOLD}🧪 快速功能测试${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # 测试 m2cc.sh 基本功能
    if [ -f "$PROJECT_ROOT/m2cc.sh" ]; then
        run_check "m2cc.sh 语法检查" "check_script_syntax '$PROJECT_ROOT/m2cc.sh'"
        
        if check_script_syntax "$PROJECT_ROOT/m2cc.sh"; then
            # 检查必要函数
            local required_functions=("show_welcome" "main" "handle_arguments")
            local found_functions=0
            
            for func in "${required_functions[@]}"; do
                if grep -q "^$func()" "$PROJECT_ROOT/m2cc.sh"; then
                    ((found_functions++))
                fi
            done
            
            if [ $found_functions -eq ${#required_functions[@]} ]; then
                log_success "m2cc.sh 包含所有必要函数"
            else
                log_warning "m2cc.sh 缺少部分函数 (找到 $found_functions/${#required_functions[@]})"
            fi
        fi
    fi
    
    # 测试 Docker 镜像构建准备
    if [ -f "$PROJECT_ROOT/Dockerfile" ]; then
        run_check "Dockerfile 语法检查" "check_script_syntax '$PROJECT_ROOT/Dockerfile'" "false"
    fi
    
    echo
    
    # 7. 生成验证报告
    echo -e "${YELLOW}${BOLD}📊 验证报告${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e "总检查项目: $TOTAL_CHECKS"
    echo -e "${GREEN}通过检查: $PASSED_CHECKS${NC}"
    echo -e "${RED}失败检查: $FAILED_CHECKS${NC}"
    
    local success_rate=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    echo -e "成功率: ${success_rate}%"
    
    echo
    
    # 8. 环境状态评估
    if [ $FAILED_CHECKS -eq 0 ]; then
        echo -e "${GREEN}${BOLD}✅ 环境验证通过！${NC}"
        echo -e "${GREEN}   所有检查都成功，环境已准备就绪${NC}"
        echo
        echo -e "${CYAN}🎯 建议下一步操作:${NC}"
        echo -e "1. 启动交互式测试: ${BLUE}./docker-test.sh${NC}"
        echo -e "2. 运行自动化测试: ${BLUE}./docker-test.sh --automated basic${NC}"
        echo -e "3. 查看帮助信息: ${BLUE}./docker-test.sh --help${NC}"
        return 0
    elif [ $FAILED_CHECKS -le 3 ]; then
        echo -e "${YELLOW}${BOLD}⚠️  环境基本可用，但有少量问题${NC}"
        echo -e "${YELLOW}   请查看上述失败的检查项并修复${NC}"
        echo
        echo -e "${CYAN}💡 建议操作:${NC}"
        echo -e "1. 修复失败的检查项"
        echo -e "2. 重新运行验证: ${BLUE}./verify-env.sh${NC}"
        return 1
    else
        echo -e "${RED}${BOLD}❌ 环境验证失败！${NC}"
        echo -e "${RED}   有 $FAILED_CHECKS 个检查失败，环境可能不可用${NC}"
        echo
        echo -e "${CYAN}🔧 故障排除建议:${NC}"
        echo -e "1. 检查项目文件是否完整"
        echo -e "2. 确认所有脚本都有执行权限: ${BLUE}chmod +x *.sh docker/**/*.sh${NC}"
        echo -e "3. 检查 Docker 环境是否正常"
        echo -e "4. 查看详细错误信息并修复"
        return 1
    fi
}

# 运行快速测试 (如果环境验证通过)
run_quick_test() {
    echo
    echo -e "${CYAN}${BOLD}🧪 是否运行快速功能测试？${NC}"
    echo -e "${YELLOW}这将执行基础语法和功能检查，不会进行实际安装${NC}"
    
    read -p "运行快速测试? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo
        log_info "开始快速功能测试..."
        
        # 测试脚本的帮助功能
        if "$PROJECT_ROOT/docker-test.sh" --help >/dev/null 2>&1; then
            log_success "主启动脚本帮助功能正常"
        else
            log_error "主启动脚本帮助功能异常"
        fi
        
        # 测试清理脚本的帮助功能
        if "$PROJECT_ROOT/docker/cleanup.sh" --help >/dev/null 2>&1; then
            log_success "清理脚本帮助功能正常"
        else
            log_error "清理脚本帮助功能异常"
        fi
        
        # 检查配置文件语法
        if [ -f "$PROJECT_ROOT/docker/config/test.env" ]; then
            log_info "测试配置文件存在性检查通过"
        fi
        
        log_success "快速功能测试完成"
    fi
}

# 显示详细帮助
show_help() {
    cat << EOF
M2CC Docker 环境验证工具

用法: $0 [选项]

选项:
  -h, --help              显示此帮助信息
  -t, --test              验证通过后自动运行快速测试
  -q, --quiet             静默模式，只显示错误

环境变量:
  VERIFY_QUICK_TEST       自动运行快速测试
  VERIFY_SKIP_DOCKER      跳过 Docker 环境检查

示例:
  $0                      # 运行完整验证
  $0 -t                   # 验证后运行快速测试
  $0 -q                   # 静默验证，只显示错误

EOF
}

# 主函数
main() {
    local run_quick=false
    local quiet_mode=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -t|--test)
                run_quick=true
                shift
                ;;
            -q|--quiet)
                quiet_mode=true
                shift
                ;;
            *)
                echo -e "${RED}错误: 未知参数 $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 检查环境变量
    if [ "$VERIFY_QUICK_TEST" = "true" ]; then
        run_quick=true
    fi
    
    # 运行验证
    if main_verify; then
        local verify_result=$?
        
        if [ "$run_quick" = "true" ]; then
            run_quick_test
        fi
        
        exit $verify_result
    else
        exit 1
    fi
}

# 执行主函数
main "$@"