#!/bin/bash

# 快速重建脚本
# 用于代码修改后快速重新构建和部署服务

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
    echo "用法: $0 [选项] [服务名...]"
    echo ""
    echo "选项:"
    echo "  -h, --help      显示帮助信息"
    echo "  -a, --all       重建所有服务"
    echo "  -g, --gateway   重建 gateway-service"
    echo "  -c, --catalog   重建 catalog-service"
    echo "  -e, --enrollment 重建 enrollment-service"
    echo "  -n, --no-cache  不使用缓存构建"
    echo "  -r, --restart   仅重启服务（不重新构建）"
    echo "  -l, --logs      构建后显示日志"
    echo ""
    echo "示例:"
    echo "  $0 -g           # 只重建 gateway-service"
    echo "  $0 -c -e        # 重建 catalog 和 enrollment"
    echo "  $0 -a           # 重建所有服务"
    echo "  $0 -a -n        # 重建所有服务（不使用缓存）"
    echo "  $0 -r -g        # 仅重启 gateway-service"
}

# 默认值
SERVICES=()
NO_CACHE=""
RESTART_ONLY=false
SHOW_LOGS=false

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -a|--all)
            SERVICES=("gateway-service" "catalog-service" "enrollment-service")
            shift
            ;;
        -g|--gateway)
            SERVICES+=("gateway-service")
            shift
            ;;
        -c|--catalog)
            SERVICES+=("catalog-service")
            shift
            ;;
        -e|--enrollment)
            SERVICES+=("enrollment-service")
            shift
            ;;
        -n|--no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        -r|--restart)
            RESTART_ONLY=true
            shift
            ;;
        -l|--logs)
            SHOW_LOGS=true
            shift
            ;;
        *)
            error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 如果没有指定服务，显示帮助
if [ ${#SERVICES[@]} -eq 0 ]; then
    warn "未指定服务，请选择要构建的服务"
    echo ""
    show_help
    exit 1
fi

# 去重
SERVICES=($(echo "${SERVICES[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

echo "=========================================="
echo "       快速重建脚本"
echo "=========================================="
echo ""
info "目标服务: ${SERVICES[*]}"
echo ""

# 仅重启模式
if [ "$RESTART_ONLY" = true ]; then
    info "重启模式：仅重启服务，不重新构建"
    for service in "${SERVICES[@]}"; do
        info "重启 $service..."
        $DOCKER_COMPOSE restart "$service"
        success "$service 已重启"
    done
    
    if [ "$SHOW_LOGS" = true ]; then
        info "显示日志..."
        $DOCKER_COMPOSE logs -f "${SERVICES[@]}"
    fi
    exit 0
fi

# 构建流程
START_TIME=$(date +%s)

for service in "${SERVICES[@]}"; do
    echo ""
    echo "=========================================="
    info "构建 $service"
    echo "=========================================="
    
    # 1. 停止旧容器
    info "停止 $service 容器..."
    $DOCKER_COMPOSE stop "$service" 2>/dev/null || true
    
    # 2. 删除旧容器
    info "删除 $service 旧容器..."
    $DOCKER_COMPOSE rm -f "$service" 2>/dev/null || true
    
    # 3. 重新构建
    info "构建 $service 镜像..."
    if $DOCKER_COMPOSE build $NO_CACHE "$service"; then
        success "$service 镜像构建成功"
    else
        error "$service 镜像构建失败"
        exit 1
    fi
    
    # 4. 启动服务
    info "启动 $service..."
    if $DOCKER_COMPOSE up -d "$service"; then
        success "$service 已启动"
    else
        error "$service 启动失败"
        exit 1
    fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "=========================================="
success "构建完成！耗时: ${DURATION}秒"
echo "=========================================="

# 显示服务状态
echo ""
info "服务状态:"
$DOCKER_COMPOSE ps "${SERVICES[@]}"

# 等待服务启动
echo ""
info "等待服务启动..."
sleep 5

# 健康检查
echo ""
info "健康检查:"

# 动态获取服务端口的函数
get_service_port() {
    local service=$1
    local internal_port=$2
    # 从 docker compose ps 输出中提取映射的主机端口
    docker compose ps --format "table {{.Names}}\t{{.Ports}}" 2>/dev/null | \
        grep "$service" | \
        grep -oE "0\.0\.0\.0:[0-9]+->${internal_port}/tcp" | \
        head -1 | \
        sed 's/0\.0\.0\.0:\([0-9]*\)->.*/\1/'
}

for service in "${SERVICES[@]}"; do
    case $service in
        gateway-service)
            PORT=8090
            ;;
        catalog-service)
            # 动态获取端口 (内部端口 8081)
            PORT=$(get_service_port "catalog-service" "8081")
            PORT=${PORT:-8082}  # 默认值
            ;;
        enrollment-service)
            # 动态获取端口 (内部端口 8082)
            PORT=$(get_service_port "enrollment-service" "8082")
            PORT=${PORT:-8085}  # 默认值
            ;;
    esac
    
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/actuator/health" | grep -q "200"; then
        success "$service (端口 $PORT) - 健康"
    else
        warn "$service (端口 $PORT) - 可能仍在启动中..."
    fi
done

# 显示日志
if [ "$SHOW_LOGS" = true ]; then
    echo ""
    info "显示日志 (Ctrl+C 退出)..."
    $DOCKER_COMPOSE logs -f "${SERVICES[@]}"
fi

echo ""
info "提示: 使用 '$DOCKER_COMPOSE logs -f ${SERVICES[*]}' 查看日志"
