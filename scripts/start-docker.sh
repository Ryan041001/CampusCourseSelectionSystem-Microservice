#!/bin/bash

# 启动脚本
# 启动所有 Docker 服务，并可选择性地扩容 catalog-service 实例以测试负载均衡

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
CYAN='\033[0;36m'
NC='\033[0m'

# 打印带颜色的信息
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
header() { echo -e "${CYAN}$1${NC}"; }

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help              显示帮助信息"
    echo "  -s, --scale <数量>      设置 catalog-service 实例数量 (默认: 3)"
    echo "  -b, --build             启动前重新构建镜像"
    echo "  -c, --clean             清理后重新启动（删除旧容器）"
    echo "  -t, --test              启动后运行所有测试脚本"
    echo "  -w, --wait <秒数>       等待服务就绪的超时时间 (默认: 120)"
    echo "  -q, --quick             快速模式：不等待健康检查"
    echo ""
    echo "示例:"
    echo "  $0                      # 启动所有服务，catalog-service 3 实例"
    echo "  $0 -s 1                 # 启动所有服务，catalog-service 1 实例"
    echo "  $0 -b -s 3              # 重新构建并启动，3 个 catalog 实例"
    echo "  $0 -t                   # 启动后运行测试"
    echo "  $0 -c -b -t             # 清理、重建、启动并测试"
    exit 0
}

# 默认值
CATALOG_SCALE=3
BUILD_FLAG=""
CLEAN_START=false
RUN_TESTS=false
WAIT_TIMEOUT=120
QUICK_MODE=false

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -s|--scale)
            CATALOG_SCALE="$2"
            shift 2
            ;;
        -b|--build)
            BUILD_FLAG="--build"
            shift
            ;;
        -c|--clean)
            CLEAN_START=true
            shift
            ;;
        -t|--test)
            RUN_TESTS=true
            shift
            ;;
        -w|--wait)
            WAIT_TIMEOUT="$2"
            shift 2
            ;;
        -q|--quick)
            QUICK_MODE=true
            shift
            ;;
        *)
            error "未知选项: $1"
            show_help
            ;;
    esac
done

# 等待服务就绪
wait_for_service() {
    local service_name=$1
    local url=$2
    local timeout=$3
    local elapsed=0
    
    info "等待 $service_name 就绪..."
    while [[ $elapsed -lt $timeout ]]; do
        if curl -s "$url" > /dev/null 2>&1; then
            success "$service_name 已就绪"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
        echo -ne "\r  已等待 ${elapsed}s / ${timeout}s"
    done
    echo ""
    error "$service_name 在 ${timeout}s 内未就绪"
    return 1
}

# 显示服务状态
show_status() {
    echo ""
    header "=============================================="
    header "              服务状态"
    header "=============================================="
    echo ""
    
    info "运行中的容器:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(NAME|nacos|gateway|catalog|enrollment|mysql)" || echo "  (无相关容器)"
    
    echo ""
    info "Catalog Service 实例数量:"
    local catalog_count=$(docker ps --filter "name=catalog-service" --format "{{.Names}}" | wc -l)
    echo "  当前运行: $catalog_count 个实例"
    
    echo ""
    info "服务访问地址:"
    echo "  - Nacos 控制台:       http://localhost:8848/nacos"
    echo "  - Gateway Service:    http://localhost:8090"
    echo "  - Catalog Service:    http://localhost:8081-8083 (直接访问，取决于实例)"
    echo "  - Enrollment Service: http://localhost:8086 (直接访问)"
    echo ""
}

# 运行测试脚本
run_tests() {
    echo ""
    header "=============================================="
    header "              运行测试脚本"
    header "=============================================="
    echo ""
    
    local test_scripts=(
        "test-services.sh"
        "test-gateway.sh"
        "test-feign-loadbalancer.sh"
        "test-all-apis.sh"
    )
    
    local passed=0
    local failed=0
    
    for script in "${test_scripts[@]}"; do
        local script_path="$PROJECT_ROOT/scripts/$script"
        if [[ -f "$script_path" ]]; then
            echo ""
            header ">>> 运行 $script"
            echo ""
            if bash "$script_path"; then
                success "$script 完成"
                ((passed++))
            else
                error "$script 失败"
                ((failed++))
            fi
        else
            warn "脚本不存在: $script"
        fi
    done
    
    echo ""
    header "=============================================="
    header "              测试汇总"
    header "=============================================="
    echo ""
    echo "  通过: $passed"
    echo "  失败: $failed"
    echo ""
    
    if [[ $failed -gt 0 ]]; then
        return 1
    fi
    return 0
}

# 主逻辑
main() {
    echo ""
    header "=============================================="
    header "       Docker 服务启动脚本"
    header "=============================================="
    echo ""
    
    info "配置信息:"
    echo "  - Catalog Service 实例数: $CATALOG_SCALE"
    echo "  - 重新构建: $([ -n "$BUILD_FLAG" ] && echo '是' || echo '否')"
    echo "  - 清理启动: $([ "$CLEAN_START" = true ] && echo '是' || echo '否')"
    echo "  - 运行测试: $([ "$RUN_TESTS" = true ] && echo '是' || echo '否')"
    echo ""
    
    # 清理旧容器
    if $CLEAN_START; then
        info "清理旧容器..."
        $DOCKER_COMPOSE down
        success "旧容器已清理"
    fi
    
    # 启动服务
    info "启动 Docker 服务..."
    $DOCKER_COMPOSE up -d $BUILD_FLAG --scale catalog-service=$CATALOG_SCALE
    
    if ! $QUICK_MODE; then
        echo ""
        info "等待服务启动..."
        
        # 等待 Nacos
        wait_for_service "Nacos" "http://localhost:8848/nacos/" $WAIT_TIMEOUT || {
            error "Nacos 启动失败，查看日志: docker logs nacos"
            exit 1
        }
        
        # 等待 Catalog Service (尝试多个可能的端口)
        local catalog_ready=false
        for port in 8081 8082 8083; do
            if curl -s "http://localhost:$port/api/courses" > /dev/null 2>&1; then
                success "Catalog Service 已就绪 (端口 $port)"
                catalog_ready=true
                break
            fi
        done
        if ! $catalog_ready; then
            wait_for_service "Catalog Service" "http://localhost:8082/api/courses" $WAIT_TIMEOUT || {
                warn "Catalog Service 可能还在启动中..."
            }
        fi
        
        # 等待 Enrollment Service (端口 8086)
        wait_for_service "Enrollment Service" "http://localhost:8086/api/enrollments" $WAIT_TIMEOUT || {
            warn "Enrollment Service 可能还在启动中..."
        }
        
        # 等待 Gateway Service
        wait_for_service "Gateway Service" "http://localhost:8090/api/catalog/courses" $WAIT_TIMEOUT || {
            warn "Gateway Service 可能还在启动中..."
        }
    fi
    
    # 显示状态
    show_status
    
    success "所有服务已启动！"
    
    # 运行测试
    if $RUN_TESTS; then
        sleep 5  # 额外等待一下确保服务完全就绪
        run_tests
    fi
    
    echo ""
    info "常用命令:"
    echo "  查看日志:     docker compose logs -f [服务名]"
    echo "  停止服务:     ./scripts/stop-docker.sh"
    echo "  运行测试:     ./scripts/test-feign-loadbalancer.sh"
    echo "  重建服务:     ./scripts/rebuild.sh -a"
    echo ""
}

main
