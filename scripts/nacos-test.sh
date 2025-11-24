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
            echo "$response" | grep -o '"port":"[^"]*"' || echo "  响应: $response"
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
    
    print_message $YELLOW "等待 10 秒让 Nacos 检测到实例下线..."
    sleep 10
    
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
print_message $YELLOW "步骤 1: 启动所有服务..."
docker-compose up -d

# 2. 等待服务启动
print_message $YELLOW "步骤 2: 等待服务启动..."
sleep 30

# 3. 检查各个服务状态
print_message $YELLOW "步骤 3: 检查服务状态..."

# 检查 Nacos
check_service "Nacos" "http://localhost:8848/nacos/"

# 检查 Catalog Service
check_service "Catalog Service" "http://localhost:8081/actuator/health"

# 检查 Enrollment Service
check_service "Enrollment Service" "http://localhost:8082/actuator/health"

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

echo "测试 enrollment-service 通过服务名调用 catalog-service:"
test_load_balancing "http://localhost:8082/api/enrollments/test"

# 6. 测试故障转移
print_message $YELLOW "步骤 6: 测试故障转移..."

# 注意：这里假设只有一个 catalog-service 实例
# 如果有多个实例，需要根据实际情况调整
if docker ps --format "table {{.Names}}" | grep -q "catalog-service"; then
    test_failover "http://localhost:8082/api/enrollments/test" "catalog-service"
else
    print_message $YELLOW "跳过故障转移测试（没有找到 catalog-service 容器）"
fi

# 7. 查看容器状态
print_message $YELLOW "步骤 7: 查看容器状态..."
docker-compose ps

# 8. 测试总结
print_message $GREEN "=========================================="
print_message $GREEN "测试完成！"
print_message $GREEN "=========================================="

echo ""
print_message $BLUE "Nacos 控制台访问地址:"
echo "  URL: http://localhost:8848/nacos"
echo "  用户名: nacos"
echo "  密码: nacos"
echo ""

print_message $BLUE "服务访问地址:"
echo "  Catalog Service: http://localhost:8081"
echo "  Enrollment Service: http://localhost:8082"
echo ""

print_message $BLUE "测试端点:"
echo "  Catalog Service 端口: http://localhost:8081/api/courses/port"
echo "  Enrollment Service 端口: http://localhost:8082/api/enrollments/port"
echo "  负载均衡测试: http://localhost:8082/api/enrollments/test"
echo ""

print_message $YELLOW "提示: 访问 Nacos 控制台查看服务注册和实例详情"
