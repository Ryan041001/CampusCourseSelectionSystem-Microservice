#!/bin/bash

# Docker 停止脚本
# 用于停止所有服务并释放端口

set -e

PROJECT_ROOT="/home/ryan/CampusCourseSelectionSystem-Microservice"
cd "$PROJECT_ROOT"

# 检测 docker compose 命令
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    echo "错误: 未找到 docker-compose 或 docker compose 命令"
    exit 1
fi

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 打印带颜色的信息
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help      显示帮助信息"
    echo "  -a, --all       停止所有服务并删除容器、网络（默认）"
    echo "  -s, --stop      仅停止服务（不删除容器）"
    echo "  -r, --remove    停止并删除容器、网络、卷"
    echo "  -v, --volumes   同时删除数据卷（与 -r 一起使用）"
    echo "  -p, --prune     清理未使用的 Docker 资源"
    echo ""
    echo "示例:"
    echo "  $0              # 停止所有服务并删除容器"
    echo "  $0 -s           # 仅停止服务"
    echo "  $0 -r -v        # 停止并删除容器、网络和数据卷"
    echo "  $0 -p           # 清理未使用的 Docker 资源"
    exit 0
}

# 显示当前运行的容器
show_running_containers() {
    info "当前运行的容器:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(NAME|nacos|gateway|catalog|enrollment|mysql)" || echo "  (无相关容器)"
    echo ""
}

# 显示端口占用情况
show_ports() {
    info "相关端口占用情况:"
    echo "  端口 8848 (Nacos HTTP):    $(lsof -i :8848 2>/dev/null | grep LISTEN | awk '{print $1, $2}' || echo '空闲')"
    echo "  端口 9848 (Nacos gRPC):    $(lsof -i :9848 2>/dev/null | grep LISTEN | awk '{print $1, $2}' || echo '空闲')"
    echo "  端口 8080 (Nacos Console): $(lsof -i :8080 2>/dev/null | grep LISTEN | awk '{print $1, $2}' || echo '空闲')"
    echo "  端口 8090 (Gateway):       $(lsof -i :8090 2>/dev/null | grep LISTEN | awk '{print $1, $2}' || echo '空闲')"
    echo "  端口 8081-8083 (Catalog):  $(lsof -i :8081 2>/dev/null | grep LISTEN | awk '{print $1, $2}' || echo '空闲')"
    echo "  端口 8086 (Enrollment):    $(lsof -i :8086 2>/dev/null | grep LISTEN | awk '{print $1, $2}' || echo '空闲')"
    echo "  端口 3307 (MySQL Catalog): $(lsof -i :3307 2>/dev/null | grep LISTEN | awk '{print $1, $2}' || echo '空闲')"
    echo "  端口 3308 (MySQL Enroll):  $(lsof -i :3308 2>/dev/null | grep LISTEN | awk '{print $1, $2}' || echo '空闲')"
    echo ""
}

# 仅停止服务
stop_services() {
    info "停止所有服务..."
    $DOCKER_COMPOSE stop
    success "所有服务已停止"
}

# 停止并删除容器和网络
down_services() {
    info "停止并删除容器和网络..."
    $DOCKER_COMPOSE down
    success "所有容器和网络已删除"
}

# 停止并删除容器、网络和卷
down_with_volumes() {
    warn "停止并删除容器、网络和数据卷..."
    warn "警告: 这将删除所有数据库数据！"
    read -p "确定要继续吗? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        $DOCKER_COMPOSE down -v
        success "所有容器、网络和数据卷已删除"
    else
        info "操作已取消"
    fi
}

# 清理未使用的 Docker 资源
prune_resources() {
    warn "清理未使用的 Docker 资源..."
    
    info "清理停止的容器..."
    docker container prune -f
    
    info "清理未使用的网络..."
    docker network prune -f
    
    info "清理悬空镜像..."
    docker image prune -f
    
    success "Docker 资源清理完成"
}

# 解析参数
ACTION="down"  # 默认动作
REMOVE_VOLUMES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -a|--all)
            ACTION="down"
            shift
            ;;
        -s|--stop)
            ACTION="stop"
            shift
            ;;
        -r|--remove)
            ACTION="down"
            shift
            ;;
        -v|--volumes)
            REMOVE_VOLUMES=true
            shift
            ;;
        -p|--prune)
            ACTION="prune"
            shift
            ;;
        *)
            error "未知选项: $1"
            show_help
            ;;
    esac
done

# 主逻辑
echo ""
echo "==========================================="
echo "       Docker 服务停止脚本"
echo "==========================================="
echo ""

show_running_containers

case $ACTION in
    stop)
        stop_services
        ;;
    down)
        if $REMOVE_VOLUMES; then
            down_with_volumes
        else
            down_services
        fi
        ;;
    prune)
        down_services
        prune_resources
        ;;
esac

echo ""
show_ports
success "操作完成！端口已释放。"
