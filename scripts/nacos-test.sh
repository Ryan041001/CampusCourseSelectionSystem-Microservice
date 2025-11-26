#!/bin/bash

echo "=========================================="
echo "Nacos 服务注册与发现测试脚本"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函数：打印带颜色的消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 函数：检查服务是否启动
check_service() {
    local service_name=$1
    local url=$2
    local max_attempts=30
    local attempt=1
    
    print_message $YELLOW "检查 $service_name 服务状态..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f $url > /dev/null 2>&1; then
            print_message $GREEN "✓ $service_name 服务已启动"
            return 0
        fi
        echo "  尝试 $attempt/$max_attempts: 等待 $service_name 启动..."
        sleep 2
        ((attempt++))
    done
    
    print_message $RED "✗ $service_name 服务启动失败"
    return 1
}

# 函数：测试负载均衡
get_mapped_ports() {
    # get mapped host ports for containers whose name contains $1 and that map to the given internal port $2
    # returns space separated unique ports
    local service_name=$1
    local internal_port=$2
    docker ps --format "{{.Names}}\t{{.Ports}}" | grep "$service_name" | grep -oE "0\.0\.0\.0:[0-9]+->${internal_port}/tcp" | sed 's/0\.0\.0\.0:\([0-9]*\)->.*/\1/' | sort -u | tr '\n' ' '
}

test_load_balancing() {
    local service_url=$1
    local test_count=10
    
    print_message $BLUE "测试负载均衡效果 ($test_count 次请求)..."
    echo "服务地址: $service_url"
    echo ""
    
    for i in $(seq 1 $test_count); do
        echo "第 $i 次请求:"
        response=$(curl -s $service_url 2>/dev/null)
        if [ $? -eq 0 ]; then
            # 尝试用 python3 解析常见返回格式 {"data":{"port":"8082","catalog_hostname":"..."}}
            if echo "$response" | python3 -c "import sys, json
try:
    data=json.load(sys.stdin)
    if isinstance(data, dict) and 'data' in data and isinstance(data['data'], dict):
        sys.exit(0)
except Exception:
    pass
sys.exit(1)
" >/dev/null 2>&1; then
                echo "$response" | python3 -c "import sys, json; data=json.load(sys.stdin); d=data.get('data', {}); print('  port: %s, catalog_hostname: %s' % (d.get('port', '<n/a>'), d.get('catalog_hostname', '<n/a>')))" || echo "  响应: $response"
            else
                echo "$response" | grep -o '"port":"[^"]*"' || echo "  响应: $response"
            fi
        else
            echo "  请求失败"
        fi
        echo ""
        sleep 1
    done
}

# 函数：测试故障转移
test_failover() {
    local service_url=$1
    local container_name=$2
    
    print_message $BLUE "测试故障转移效果..."
    echo "停止容器: $container_name"
    
    # 停止一个实例
    docker stop $container_name
    
    print_message $YELLOW "等待 15 秒让 Nacos 检测到实例下线..."
    sleep 15
    
    print_message $BLUE "测试服务是否仍然可用..."
    for i in {1..5}; do
        echo "故障后测试 $i:"
        response=$(curl -s $service_url 2>/dev/null)
        if [ $? -eq 0 ]; then
            print_message $GREEN "✓ 请求成功: $response"
        else
            print_message $RED "✗ 请求失败"
        fi
        sleep 1
    done
    
    # 重新启动容器
    print_message $YELLOW "重新启动容器: $container_name"
    docker start $container_name
    sleep 5
}

# 开始测试
print_message $GREEN "开始 Nacos 集成测试..."

# 1. 启动所有服务
print_message $YELLOW "步骤 1: 启动所有服务 (扩展 catalog-service 到 3 个实例)..."
docker compose up -d --scale catalog-service=3

# 2. 等待服务启动
print_message $YELLOW "步骤 2: 等待服务启动..."
sleep 20

# 3. 检查各个服务状态
print_message $YELLOW "步骤 3: 检查服务状态..."

# 检查 Nacos (API 端口 8848)
check_service "Nacos" "http://localhost:8848/nacos/"

# 检查 Catalog Service (检查所有可能的端口: 8082, 8083 等)
if curl -s -f "http://localhost:8082/actuator/health" > /dev/null 2>&1; then
    check_service "Catalog Service" "http://localhost:8082/actuator/health"
elif curl -s -f "http://localhost:8083/actuator/health" > /dev/null 2>&1; then
    check_service "Catalog Service" "http://localhost:8083/actuator/health"
else
    print_message $YELLOW "Catalog Service 可能在其他端口启动，尝试检查所有catalog-service容器..."
    # 获取所有catalog-service容器的端口映射
    catalog_ports=$(docker ps --format "table {{.Names}}\t{{.Ports}}" | grep catalog-service | grep -o ':[0-9]*->8081' | grep -o '[0-9]*' | head -1)
    if [ ! -z "$catalog_ports" ]; then
        check_service "Catalog Service" "http://localhost:$catalog_ports/actuator/health"
    else
        print_message $RED "✗ 无法找到可用的 Catalog Service 端口"
    fi
fi

# 检查 Enrollment Service (端口 8085 优先)
if curl -s -f "http://localhost:8085/actuator/health" > /dev/null 2>&1; then
    check_service "Enrollment Service" "http://localhost:8085/actuator/health"
elif curl -s -f "http://localhost:8086/actuator/health" > /dev/null 2>&1; then
    check_service "Enrollment Service" "http://localhost:8086/actuator/health"
else
    print_message $YELLOW "Enrollment Service 可能在其他端口启动..."
    enrollment_ports=$(docker ps --format "table {{.Names}}\t{{.Ports}}" | grep enrollment-service | grep -o ':[0-9]*->8082' | grep -o '[0-9]*' | head -1)
    if [ ! -z "$enrollment_ports" ]; then
        check_service "Enrollment Service" "http://localhost:$enrollment_ports/actuator/health"
    else
        print_message $RED "✗ 无法找到可用的 Enrollment Service 端口"
    fi
fi

# 4. 检查服务注册情况
print_message $YELLOW "步骤 4: 检查服务注册情况..."

echo "检查 catalog-service 注册情况:"
curl -s -X GET "http://localhost:8848/nacos/v1/ns/instance/list?groupName=COURSEHUB_GROUP&serviceName=catalog-service" | python3 -m json.tool 2>/dev/null || curl -s -X GET "http://localhost:8848/nacos/v1/ns/instance/list?groupName=COURSEHUB_GROUP&serviceName=catalog-service"
echo ""

echo "检查 enrollment-service 注册情况:"
curl -s -X GET "http://localhost:8848/nacos/v1/ns/instance/list?groupName=COURSEHUB_GROUP&serviceName=enrollment-service" | python3 -m json.tool 2>/dev/null || curl -s -X GET "http://localhost:8848/nacos/v1/ns/instance/list?groupName=COURSEHUB_GROUP&serviceName=enrollment-service"
echo ""

# 5. 测试服务调用和负载均衡
print_message $YELLOW "步骤 5: 测试服务调用和负载均衡..."

# 动态获取enrollment-service的端口
enrollment_port=$(docker ps --format "table {{.Names}}\t{{.Ports}}" | grep enrollment-service | grep -o ':[0-9]*->8082' | grep -o '[0-9]*' | head -1)
if [ -z "$enrollment_port" ]; then
    enrollment_port="8085"  # 默认端口 (docker-compose 映射 8085-8086:8082)
fi

echo "测试 enrollment-service 通过服务名调用 catalog-service:"
test_load_balancing "http://localhost:$enrollment_port/api/enrollments/test"

# 6. 测试故障转移
print_message $YELLOW "步骤 6: 测试故障转移..."

# 注意：这里支持多实例，优先停止一个catalog-service实例来观察Nacos上报的故障转移
if docker ps --format "table {{.Names}}" | grep -q "catalog-service"; then
    # 列出所有 catalog-service 容器
    catalog_containers=( $(docker ps --format "{{.Names}}" | grep catalog-service) )
    # 选择第一个实例作为要停止的目标（可按需更改为随机或用户选择）
    catalog_container=${catalog_containers[0]}
    print_message $YELLOW "将停止容器：$catalog_container (其他实例应继续提供服务)"
    test_failover "http://localhost:$enrollment_port/api/enrollments/test" "$catalog_container"
else
    print_message $YELLOW "跳过故障转移测试（没有找到 catalog-service 容器）"
fi

# 7. 查看容器状态
print_message $YELLOW "步骤 7: 查看容器状态..."
docker compose ps

# 8. 测试总结
print_message $GREEN "=========================================="
print_message $GREEN "测试完成！"
print_message $GREEN "=========================================="

echo ""
print_message $BLUE "Nacos 控制台访问地址:"
echo "  URL: http://localhost:8848"
echo "  用户名: nacos"
echo "  密码: nacos"
echo ""

print_message $BLUE "服务访问地址 (检测到的 host 映射端口):"
# 尝试检测 catalog 和 enrollment 的映射端口
catalog_detected_ports=$(get_mapped_ports "catalog-service" 8081 | tr '\n' ' ')
enrollment_detected_ports=$(get_mapped_ports "enrollment-service" 8082 | tr '\n' ' ')

if [ -n "$catalog_detected_ports" ]; then
    echo "  Catalog Service (mapped host ports): $catalog_detected_ports"
else
    echo "  Catalog Service: http://localhost:8082 (默认)"
fi

if [ -n "$enrollment_detected_ports" ]; then
    echo "  Enrollment Service (mapped host ports): $enrollment_detected_ports"
else
    echo "  Enrollment Service: http://localhost:8082 (默认)"
fi
echo ""

print_message $BLUE "测试端点:"
if [ -n "$catalog_detected_ports" ]; then
    for p in $catalog_detected_ports; do
        echo "  Catalog Service 端口: http://localhost:$p/api/courses/port"
    done
else
    echo "  Catalog Service 端口: http://localhost:8082/api/courses/port"
fi

if [ -n "$enrollment_detected_ports" ]; then
    for p in $enrollment_detected_ports; do
        echo "  Enrollment Service 端口: http://localhost:$p/api/enrollments/port"
    done
    # 使用第一个作为默认负载均衡测试入口
    first_enrollment_port=$(echo $enrollment_detected_ports | awk '{print $1}')
    echo "  负载均衡测试: http://localhost:$first_enrollment_port/api/enrollments/test (首选映射端口)"
else
    echo "  Enrollment Service 端口: http://localhost:8085/api/enrollments/port"
    echo "  负载均衡测试: http://localhost:8085/api/enrollments/test"
fi
echo ""

print_message $YELLOW "提示: 访问 Nacos 控制台查看服务注册和实例详情"
