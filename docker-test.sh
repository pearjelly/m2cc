#!/bin/bash

# M2CC Docker 测试环境启动脚本
# 提供多种启动方式和测试模式

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

# 脚本路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$SCRIPT_DIR"

# 帮助信息
show_help() {
    cat << EOF
M2CC Docker 测试环境启动器

用法: $0 [选项]

选项:
  -h, --help              显示此帮助信息
  -i, --interactive       启动交互式测试环境 (默认)
  -a, --automated MODE    启动自动化测试 (MODE: basic|full|stress|all)
  -b, --build             构建 Docker 镜像
  -r, --run [MODE]        构建并运行容器 (MODE: interactive|automated)
  -c, --cleanup           清理 Docker 资源
  -l, --logs              显示最近的测试日志
  -s, --status            显示容器状态

环境变量:
  DOCKER_IMAGE           Docker 镜像名 [默认: m2cc-test]
  DOCKER_TAG             Docker 标签 [默认: latest]
  TEST_ITERATIONS        自动化测试迭代次数
  SKIP_NETWORK_TESTS     跳过网络测试

示例:
  $0                      # 启动交互式测试
  $0 -i                   # 交互式测试
  $0 -a basic             # 运行基础自动化测试
  $0 -a stress -e TEST_ITERATIONS=5  # 5轮压力测试
  $0 -r automated -a full # 构建并运行完整测试
  $0 -c                   # 清理所有资源

EOF
}

# 检查 Docker 是否可用
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}错误: Docker 未安装或不可用${NC}"
        echo "请安装 Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}错误: Docker 守护进程未运行${NC}"
        echo "请启动 Docker 守护进程"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Docker 环境检查通过${NC}"
}

# 构建 Docker 镜像
build_image() {
    local image_name="${DOCKER_IMAGE:-m2cc-test}"
    local tag="${DOCKER_TAG:-latest}"
    local full_name="$image_name:$tag"
    
    echo -e "${BLUE}[BUILD]${NC} 构建 Docker 镜像: $full_name"
    
    # 确保 m2cc.sh 在构建目录中
    if [ -f "$PROJECT_ROOT/m2cc.sh" ]; then
        echo -e "${CYAN}确认 m2cc.sh 在构建目录中${NC}"
        # m2cc.sh 已经在正确位置，无需复制
    else
        echo -e "${RED}错误: 未找到 m2cc.sh 文件${NC}"
        return 1
    fi
    
    # 构建镜像
    if docker build -t "$full_name" "$PROJECT_ROOT"; then
        echo -e "${GREEN}✓ Docker 镜像构建成功: $full_name${NC}"
        echo "$full_name" > /tmp/m2cc_docker_image
        return 0
    else
        echo -e "${RED}✗ Docker 镜像构建失败${NC}"
        return 1
    fi
}

# 启动交互式容器
run_interactive() {
    local image_name="${DOCKER_IMAGE:-m2cc-test}"
    local tag="${DOCKER_TAG:-latest}"
    local full_name="$image_name:$tag"
    
    # 确保镜像存在
    if [ "$(docker images -q $full_name 2>/dev/null)" = "" ]; then
        echo -e "${YELLOW}镜像 $full_name 不存在，正在构建...${NC}"
        if ! build_image; then
            exit 1
        fi
    fi
    
    echo -e "${BLUE}[RUN]${NC} 启动交互式测试容器"
    echo -e "${CYAN}镜像: $full_name${NC}"
    echo -e "${CYAN}工作目录: $PROJECT_ROOT${NC}"
    echo
    
    # 运行容器
    docker run -it --rm \
        -v "$PROJECT_ROOT:/host-workspace" \
        -v "$(realpath ~/.claude):/home/testuser/.claude:ro" \
        -v "$(realpath ~/.nvm):/home/testuser/.nvm:ro" \
        -w /workspace \
        --name "m2cc-test-$(date +%s)" \
        "$full_name" \
        bash -c "cp /host-workspace/m2cc.sh /workspace/ && /workspace/test-scripts/interactive-test.sh"
}

# 启动自动化测试
run_automated() {
    local mode="${1:-basic}"
    local image_name="${DOCKER_IMAGE:-m2cc-test}"
    local tag="${DOCKER_TAG:-latest}"
    local full_name="$image_name:$tag"
    local container_name="m2cc-auto-test-$(date +%s)"
    
    # 确保镜像存在
    if [ "$(docker images -q $full_name 2>/dev/null)" = "" ]; then
        echo -e "${YELLOW}镜像 $full_name 不存在，正在构建...${NC}"
        if ! build_image; then
            exit 1
        fi
    fi
    
    echo -e "${BLUE}[RUN]${NC} 启动自动化测试容器"
    echo -e "${CYAN}镜像: $full_name${NC}"
    echo -e "${CYAN}模式: $mode${NC}"
    echo -e "${CYAN}容器名: $container_name${NC}"
    echo
    
    # 运行自动化测试
    local test_exit_code=0
    docker run \
        -v "$PROJECT_ROOT:/host-workspace" \
        -v "$(realpath ~/.claude):/home/testuser/.claude:ro" \
        -v "$(realpath ~/.nvm):/home/testuser/.nvm:ro" \
        -w /workspace \
        -e TEST_MODE="$mode" \
        -e TEST_ITERATIONS="${TEST_ITERATIONS:-3}" \
        -e SKIP_NETWORK_TESTS="${SKIP_NETWORK_TESTS:-false}" \
        --name "$container_name" \
        "$full_name" \
        bash -c "cp /host-workspace/m2cc.sh /workspace/ && /workspace/test-scripts/automated-test.sh"
    test_exit_code=$?
    
    # 复制测试报告到宿主机
    echo -e "${CYAN}复制测试报告...${NC}"
    docker cp "$container_name:/workspace/test-output" "$PROJECT_ROOT/docker/test-output" 2>/dev/null || true
    docker cp "$container_name:/workspace/test-logs" "$PROJECT_ROOT/docker/test-logs" 2>/dev/null || true
    
    # 删除容器
    docker stop "$container_name" >/dev/null 2>&1 || true
    docker rm "$container_name" >/dev/null 2>&1 || true
    
    if [ $test_exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ 自动化测试完成${NC}"
        return 0
    else
        echo -e "${RED}✗ 自动化测试失败${NC}"
        return 1
    fi
}

# 清理 Docker 资源
cleanup() {
    echo -e "${YELLOW}[CLEANUP]${NC} 清理 Docker 资源"
    
    # 停止并删除测试容器
    local containers=$(docker ps -a --filter "name=m2cc-test" --format "{{.Names}}" 2>/dev/null || true)
    if [ -n "$containers" ]; then
        echo -e "${CYAN}停止测试容器...${NC}"
        echo "$containers" | xargs -r docker stop >/dev/null 2>&1 || true
        echo "$containers" | xargs -r docker rm >/dev/null 2>&1 || true
    fi
    
    # 删除镜像
    local image_name="${DOCKER_IMAGE:-m2cc-test}"
    local tag="${DOCKER_TAG:-latest}"
    local full_name="$image_name:$tag"
    
    if docker images -q "$full_name" >/dev/null 2>&1; then
        echo -e "${CYAN}删除镜像: $full_name${NC}"
        docker rmi "$full_name" >/dev/null 2>&1 || true
    fi
    
    # 清理构建缓存
    echo -e "${CYAN}清理构建缓存...${NC}"
    docker builder prune -f >/dev/null 2>&1 || true
    
    # 清理临时文件
    rm -f /tmp/m2cc_docker_image
    
    echo -e "${GREEN}✓ Docker 资源清理完成${NC}"
}

# 显示日志
show_logs() {
    local log_dir="$PROJECT_ROOT/docker/test-logs"
    if [ ! -d "$log_dir" ] || [ -z "$(ls -A "$log_dir" 2>/dev/null)" ]; then
        echo -e "${YELLOW}没有找到测试日志${NC}"
        return 0
    fi
    
    echo -e "${CYAN}${BOLD}最近的测试日志:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # 显示最新的日志文件
    local latest_log=$(ls -t "$log_dir"/*.log 2>/dev/null | head -1)
    if [ -n "$latest_log" ]; then
        echo -e "${YELLOW}最新日志: $(basename "$latest_log")${NC}"
        echo
        tail -50 "$latest_log"
    else
        echo "没有日志文件"
    fi
}

# 显示状态
show_status() {
    local image_name="${DOCKER_IMAGE:-m2cc-test}"
    local tag="${DOCKER_TAG:-latest}"
    local full_name="$image_name:$tag"
    
    echo -e "${CYAN}${BOLD}M2CC Docker 测试环境状态:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # 镜像状态
    if docker images -q "$full_name" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} 镜像存在: $full_name"
        local image_size=$(docker images "$full_name" --format "{{.Size}}")
        echo -e "   大小: $image_size"
    else
        echo -e "${RED}✗${NC} 镜像不存在: $full_name"
    fi
    
    # 容器状态
    local running_containers=$(docker ps --filter "name=m2cc-test" --format "{{.Names}} ({{.Status}})" 2>/dev/null || true)
    if [ -n "$running_containers" ]; then
        echo -e "${GREEN}✓${NC} 运行中的容器:"
        echo "$running_containers" | sed 's/^/   /'
    else
        echo -e "${YELLOW}ℹ${NC} 没有运行中的容器"
    fi
    
    local stopped_containers=$(docker ps -a --filter "name=m2cc-test" --format "{{.Names}} ({{.Status}})" 2>/dev/null || true)
    if [ -n "$stopped_containers" ]; then
        echo -e "${YELLOW}ℹ${NC} 已停止的容器:"
        echo "$stopped_containers" | sed 's/^/   /'
    fi
    
    # 测试输出状态
    local output_dir="$PROJECT_ROOT/docker/test-output"
    local log_dir="$PROJECT_ROOT/docker/test-logs"
    
    if [ -d "$output_dir" ] && [ -n "$(ls -A "$output_dir" 2>/dev/null)" ]; then
        local report_count=$(ls -1 "$output_dir"/*.json 2>/dev/null | wc -l)
        echo -e "${GREEN}✓${NC} 测试报告: $report_count 个文件"
    else
        echo -e "${YELLOW}ℹ${NC} 没有测试报告"
    fi
    
    if [ -d "$log_dir" ] && [ -n "$(ls -A "$log_dir" 2>/dev/null)" ]; then
        local log_count=$(ls -1 "$log_dir"/*.log 2>/dev/null | wc -l)
        echo -e "${GREEN}✓${NC} 测试日志: $log_count 个文件"
    else
        echo -e "${YELLOW}ℹ${NC} 没有测试日志"
    fi
}

# 主函数
main() {
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -i|--interactive)
            check_docker
            run_interactive
            ;;
        -a|--automated)
            check_docker
            run_automated "${2:-basic}"
            ;;
        -b|--build)
            check_docker
            build_image
            ;;
        -r|--run)
            check_docker
            local mode="${2:-interactive}"
            if [ "$mode" = "interactive" ]; then
                run_interactive
            else
                run_automated "$mode"
            fi
            ;;
        -c|--cleanup)
            check_docker
            cleanup
            ;;
        -l|--logs)
            show_logs
            ;;
        -s|--status)
            check_docker
            show_status
            ;;
        "")
            # 默认启动交互式测试
            check_docker
            run_interactive
            ;;
        *)
            echo -e "${RED}错误: 未知参数 $1${NC}"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"