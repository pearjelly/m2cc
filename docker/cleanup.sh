#!/bin/bash

# M2CC Docker 测试环境清理脚本
# 彻底清理测试环境中的所有资源

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${BLUE}[CLEANUP]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 脚本路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 默认配置
DOCKER_IMAGE="${DOCKER_IMAGE:-m2cc-test}"
DOCKER_TAG="${DOCKER_TAG:-latest}"
FULL_IMAGE_NAME="$DOCKER_IMAGE:$DOCKER_TAG"
KEEP_IMAGES="${KEEP_IMAGES:-false}"
CLEANUP_DATA="${CLEANUP_DATA:-true}"
CLEANUP_LOGS="${CLEANUP_LOGS:-true}"
CLEANUP_CONTAINERS="${CLEANUP_CONTAINERS:-true}"
CLEANUP_IMAGES="${CLEANUP_IMAGES:-true}"
DRY_RUN="${DRY_RUN:-false}"

# 显示帮助
show_help() {
    cat << EOF
M2CC Docker 测试环境清理脚本

用法: $0 [选项]

选项:
  -h, --help              显示此帮助信息
  -a, --all               清理所有资源 (默认)
  -c, --containers        只清理容器
  -i, --images            只清理镜像
  -d, --data              只清理数据和日志
  -l, --logs              只清理日志文件
  --keep-images           保留镜像，不删除
  --dry-run               模拟执行，不实际删除
  -f, --force             强制清理，跳过确认

环境变量:
  DOCKER_IMAGE            Docker 镜像名 [默认: m2cc-test]
  DOCKER_TAG              Docker 标签 [默认: latest]
  KEEP_IMAGES             保留镜像 [默认: false]
  CLEANUP_DATA            清理数据 [默认: true]
  CLEANUP_LOGS            清理日志 [默认: true]
  CLEANUP_CONTAINERS      清理容器 [默认: true]
  CLEANUP_IMAGES          清理镜像 [默认: true]

示例:
  $0                      # 清理所有资源
  $0 --keep-images        # 保留镜像，清理其他
  $0 --dry-run            # 模拟清理过程
  $0 -c -i                # 只清理容器和镜像
  $0 -d                   # 只清理数据和日志

EOF
}

# 确认操作
confirm_action() {
    local message="$1"
    if [ "$DRY_RUN" = "true" ] || [ "$2" = "force" ]; then
        return 0
    fi
    
    echo -e "${YELLOW}警告: $message${NC}"
    read -p "确认继续? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "操作已取消"
        return 1
    fi
    return 0
}

# 检查 Docker 环境
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker 未安装或不可用"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker 守护进程未运行"
        exit 1
    fi
}

# 清理容器
cleanup_containers() {
    if [ "$CLEANUP_CONTAINERS" != "true" ]; then
        log_info "跳过容器清理"
        return 0
    fi
    
    log_info "清理 M2CC 测试容器..."
    
    # 查找所有相关的容器
    local containers=$(docker ps -a --filter "name=m2cc" --format "{{.Names}}" 2>/dev/null || true)
    
    if [ -z "$containers" ]; then
        log_info "没有找到 M2CC 相关容器"
        return 0
    fi
    
    echo "找到容器:"
    echo "$containers" | sed 's/^/  - /'
    
    if ! confirm_action "将删除这些容器"; then
        return 0
    fi
    
    # 停止运行中的容器
    local running_containers=$(docker ps --filter "name=m2cc" --format "{{.Names}}" 2>/dev/null || true)
    if [ -n "$running_containers" ]; then
        if [ "$DRY_RUN" = "true" ]; then
            log_info "[DRY-RUN] 将停止容器: $running_containers"
        else
            echo "$running_containers" | xargs -r docker stop >/dev/null 2>&1
            log_success "已停止运行中的容器"
        fi
    fi
    
    # 删除所有容器
    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY-RUN] 将删除容器: $containers"
    else
        echo "$containers" | xargs -r docker rm >/dev/null 2>&1
        log_success "已删除容器: $containers"
    fi
}

# 清理镜像
cleanup_images() {
    if [ "$CLEANUP_IMAGES" != "true" ]; then
        log_info "跳过镜像清理"
        return 0
    fi
    
    if [ "$KEEP_IMAGES" = "true" ]; then
        log_info "根据配置保留镜像"
        return 0
    fi
    
    log_info "清理 M2CC 测试镜像..."
    
    # 检查镜像是否存在
    if ! docker images -q "$FULL_IMAGE_NAME" >/dev/null 2>&1; then
        log_info "镜像 $FULL_IMAGE_NAME 不存在"
        return 0
    fi
    
    local image_size=$(docker images "$FULL_IMAGE_NAME" --format "{{.Size}}")
    echo "找到镜像: $FULL_IMAGE_NAME (大小: $image_size)"
    
    if ! confirm_action "将删除镜像 $FULL_IMAGE_NAME"; then
        return 0
    fi
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY-RUN] 将删除镜像: $FULL_IMAGE_NAME"
    else
        if docker rmi "$FULL_IMAGE_NAME" >/dev/null 2>&1; then
            log_success "已删除镜像: $FULL_IMAGE_NAME"
        else
            log_error "删除镜像失败: $FULL_IMAGE_NAME"
        fi
    fi
    
    # 清理相关构建缓存
    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY-RUN] 将清理构建缓存"
    else
        docker builder prune -f >/dev/null 2>&1
        log_success "已清理构建缓存"
    fi
}

# 清理数据和日志
cleanup_data() {
    if [ "$CLEANUP_DATA" != "true" ]; then
        log_info "跳过数据清理"
        return 0
    fi
    
    log_info "清理测试数据和日志..."
    
    local cleanup_dirs=()
    local cleanup_files=()
    
    # 定义需要清理的目录和文件
    cleanup_dirs+=("$PROJECT_ROOT/docker/test-output")
    cleanup_dirs+=("$PROJECT_ROOT/docker/test-logs")
    cleanup_files+=("/tmp/m2cc_docker_image")
    
    # 清理目录
    for dir in "${cleanup_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local file_count=$(find "$dir" -type f 2>/dev/null | wc -l)
            if [ "$file_count" -gt 0 ]; then
                echo "找到目录: $dir ($file_count 个文件)"
                if [ "$DRY_RUN" = "true" ]; then
                    log_info "[DRY-RUN] 将清理目录: $dir"
                else
                    rm -rf "$dir"/*
                    log_success "已清理目录: $dir"
                fi
            else
                log_info "目录为空或不存在: $dir"
            fi
        fi
    done
    
    # 清理文件
    for file in "${cleanup_files[@]}"; do
        if [ -f "$file" ]; then
            echo "找到文件: $file"
            if [ "$DRY_RUN" = "true" ]; then
                log_info "[DRY-RUN] 将删除文件: $file"
            else
                rm -f "$file"
                log_success "已删除文件: $file"
            fi
        fi
    done
}

# 清理日志文件 (可选)
cleanup_logs() {
    if [ "$CLEANUP_LOGS" != "true" ]; then
        log_info "跳过日志清理"
        return 0
    fi
    
    if [ "$CLEANUP_DATA" = "true" ]; then
        log_info "数据清理已包含日志清理"
        return 0
    fi
    
    log_info "清理日志文件..."
    
    local log_dir="$PROJECT_ROOT/docker/test-logs"
    if [ -d "$log_dir" ]; then
        local log_count=$(find "$log_dir" -name "*.log" 2>/dev/null | wc -l)
        if [ "$log_count" -gt 0 ]; then
            echo "找到日志文件: $log_count 个"
            if [ "$DRY_RUN" = "true" ]; then
                log_info "[DRY-RUN] 将清理日志目录: $log_dir"
            else
                find "$log_dir" -name "*.log" -delete 2>/dev/null || true
                log_success "已清理日志文件"
            fi
        else
            log_info "没有找到日志文件"
        fi
    fi
}

# 清理 Docker 网络
cleanup_networks() {
    log_info "清理 Docker 网络..."
    
    # 查找相关网络
    local networks=$(docker network ls --filter "name=m2cc" --format "{{.Name}}" 2>/dev/null || true)
    
    if [ -z "$networks" ]; then
        log_info "没有找到 M2CC 相关网络"
        return 0
    fi
    
    for network in $networks; do
        echo "找到网络: $network"
        if [ "$DRY_RUN" = "true" ]; then
            log_info "[DRY-RUN] 将删除网络: $network"
        else
            if docker network rm "$network" >/dev/null 2>&1; then
                log_success "已删除网络: $network"
            else
                log_warning "无法删除网络 (可能被使用): $network"
            fi
        fi
    done
}

# 清理 Docker 卷
cleanup_volumes() {
    log_info "清理 Docker 卷..."
    
    # 查找相关卷
    local volumes=$(docker volume ls --filter "name=m2cc" --format "{{.Name}}" 2>/dev/null || true)
    
    if [ -z "$volumes" ]; then
        log_info "没有找到 M2CC 相关卷"
        return 0
    fi
    
    for volume in $volumes; do
        echo "找到卷: $volume"
        if [ "$DRY_RUN" = "true" ]; then
            log_info "[DRY-RUN] 将删除卷: $volume"
        else
            if docker volume rm "$volume" >/dev/null 2>&1; then
                log_success "已删除卷: $volume"
            else
                log_warning "无法删除卷 (可能被使用): $volume"
            fi
        fi
    done
}

# 显示清理摘要
show_summary() {
    echo
    echo -e "${CYAN}${BOLD}清理摘要:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e "${YELLOW}配置信息:${NC}"
    echo -e "  镜像: $FULL_IMAGE_NAME"
    echo -e "  保留镜像: $KEEP_IMAGES"
    echo -e "  清理容器: $CLEANUP_CONTAINERS"
    echo -e "  清理镜像: $CLEANUP_IMAGES"
    echo -e "  清理数据: $CLEANUP_DATA"
    echo -e "  清理日志: $CLEANUP_LOGS"
    echo -e "  模拟执行: $DRY_RUN"
    echo
    
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}⚠ 这只是模拟执行，没有实际删除任何资源${NC}"
    fi
}

# 主函数
main() {
    # 解析命令行参数
    case "${1:-all}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -a|--all)
            CLEANUP_CONTAINERS="true"
            CLEANUP_IMAGES="true"
            CLEANUP_DATA="true"
            CLEANUP_LOGS="true"
            ;;
        -c|--containers)
            CLEANUP_CONTAINERS="true"
            CLEANUP_IMAGES="false"
            CLEANUP_DATA="false"
            CLEANUP_LOGS="false"
            ;;
        -i|--images)
            CLEANUP_CONTAINERS="false"
            CLEANUP_IMAGES="true"
            CLEANUP_DATA="false"
            CLEANUP_LOGS="false"
            ;;
        -d|--data)
            CLEANUP_CONTAINERS="false"
            CLEANUP_IMAGES="false"
            CLEANUP_DATA="true"
            CLEANUP_LOGS="true"
            ;;
        -l|--logs)
            CLEANUP_CONTAINERS="false"
            CLEANUP_IMAGES="false"
            CLEANUP_DATA="false"
            CLEANUP_LOGS="true"
            ;;
        --keep-images)
            KEEP_IMAGES="true"
            shift
            main "$@"
            exit 0
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            main "$@"
            exit 0
            ;;
        -f|--force)
            shift
            main "$@" 2>/dev/null || true
            exit 0
            ;;
        *)
            echo -e "${RED}错误: 未知参数 $1${NC}"
            show_help
            exit 1
            ;;
    esac
    
    # 检查 Docker 环境
    check_docker
    
    # 显示摘要
    show_summary
    
    # 执行清理操作
    if [ "$DRY_RUN" != "true" ]; then
        if ! confirm_action "将执行清理操作"; then
            exit 0
        fi
    fi
    
    echo
    log_info "开始清理 M2CC Docker 测试环境..."
    
    cleanup_containers
    cleanup_images
    cleanup_data
    cleanup_logs
    cleanup_networks
    cleanup_volumes
    
    echo
    log_success "清理操作完成！"
    
    # 清理后状态检查
    echo
    echo -e "${CYAN}${BOLD}清理后状态:${NC}"
    
    if docker ps -a --filter "name=m2cc" --format "{{.Names}}" 2>/dev/null | grep -q .; then
        log_warning "仍有 M2CC 相关容器存在"
    else
        log_success "没有 M2CC 相关容器"
    fi
    
    if docker images "$FULL_IMAGE_NAME" 2>/dev/null | grep -q "$DOCKER_IMAGE"; then
        if [ "$KEEP_IMAGES" = "true" ]; then
            log_info "镜像按配置保留"
        else
            log_warning "仍有 M2CC 镜像存在"
        fi
    else
        log_success "没有 M2CC 镜像"
    fi
}

# 执行主函数
main "$@"