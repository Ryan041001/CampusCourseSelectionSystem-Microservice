#!/bin/bash

# API Gateway 测试脚本 (增强版)
# 基于第9周要求和最佳实践

# 配置
GATEWAY_URL="http://localhost:8090"
NACOS_URL="http://localhost:8848"  # Nacos HTTP API 端口
NACOS_CONSOLE_URL="http://localhost:8080"  # Nacos 控制台端口 (v3.x)
NACOS_GROUP="COURSEHUB_GROUP"  # 服务注册组

# 动态获取服务端口的函数
get_service_port() {
    local service=$1
    local internal_port=$2
    local default_port=$3
    local port=$(docker compose ps --format "table {{.Names}}\t{{.Ports}}" 2>/dev/null | \
        grep "$service" | \
        grep -oE "0\.0\.0\.0:[0-9]+->${internal_port}/tcp" | \
        head -1 | \
        sed 's/0\.0\.0\.0:\([0-9]*\)->.*/\1/')
    echo "${port:-$default_port}"
}

# 动态获取端口
CATALOG_PORT=$(get_service_port "catalog-service" "8081" "8081")
ENROLLMENT_PORT=$(get_service_port "enrollment-service" "8082" "8085")

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 辅助函数
print_separator() {
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

print_title() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

check_service() {
    local service_name=$1
    local port=$2
    # 尝试 actuator health 接口，然后是根路径
    if curl -s "http://localhost:$port/actuator/health" > /dev/null 2>&1 || \
       curl -s "http://localhost:$port" > /dev/null 2>&1; then
        print_success "$service_name 正在运行，端口 $port"
        return 0
    else
        print_error "$service_name 未运行，端口 $port"
        return 1
    fi
}

check_nacos() {
    if curl -s "$NACOS_URL/nacos/" > /dev/null 2>&1; then
        print_success "Nacos 正在运行 (API: 8848, gRPC: 9848, 控制台: 8080)"
        return 0
    else
        print_error "Nacos 未运行"
        return 1
    fi
}

# 开始测试
print_separator
echo -e "${BLUE}   校园选课系统 - Gateway 测试   ${NC}"
print_separator

# 1. 环境检查
print_title "1. 环境健康检查"
check_nacos
check_service "gateway-service" 8090
# 检查每个下游服务 (使用动态检测的端口)
check_service "catalog-service" $CATALOG_PORT
check_service "enrollment-service" $ENROLLMENT_PORT

# 2. Nacos 注册检查
print_title "2. Nacos 服务发现"
SERVICES=$(curl -s "$NACOS_URL/nacos/v1/ns/service/list?pageNo=1&pageSize=10&groupName=$NACOS_GROUP")
# 检查服务是否在列表中
if echo "$SERVICES" | grep -q "gateway-service"; then print_success "gateway-service 已注册"; else print_error "gateway-service 未注册"; fi
if echo "$SERVICES" | grep -q "catalog-service"; then print_success "catalog-service 已注册"; else print_error "catalog-service 未注册"; fi
if echo "$SERVICES" | grep -q "enrollment-service"; then print_success "enrollment-service 已注册"; else print_error "enrollment-service 未注册"; fi

# 3. 认证流程
print_title "3. 认证流程"

# 3.1 未认证访问
echo "3.1 测试未认证访问 (预期 401)"
RESPONSE=$(curl -s -w "\n%{http_code}" "$GATEWAY_URL/api/courses")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "401" ]; then
    print_success "未认证访问被拦截 (401)"
    echo "$BODY" | jq .
else
    print_error "未能拦截未认证访问。状态码: $HTTP_CODE"
fi

# 3.2 登录
echo -e "\n3.2 测试登录 (admin/admin123)"
LOGIN_RESPONSE=$(curl -s -X POST "$GATEWAY_URL/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"admin123"}')

echo "$LOGIN_RESPONSE" | jq .

TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.data.token // empty')
if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
    print_success "登录成功，获取到 Token"
    print_info "Token: ${TOKEN:0:50}..."
else
    print_error "登录失败"
    exit 1
fi

# 3.3 Token 检查
echo -e "\n3.3 Token 载荷检查"
# 提取 payload (第2部分)，修复填充，解码
PAYLOAD=$(echo "$TOKEN" | cut -d. -f2)
# 如果需要添加填充
MOD=$((${#PAYLOAD} % 4))
if [ $MOD -eq 2 ]; then PAYLOAD="${PAYLOAD}=="; fi
if [ $MOD -eq 3 ]; then PAYLOAD="${PAYLOAD}="; fi
echo "$PAYLOAD" | base64 -d 2>/dev/null | jq . || print_warning "无法解码 Token 载荷"

# 3.4 无效 Token
echo -e "\n3.4 测试无效 Token"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/api/courses" -H "Authorization: Bearer invalid_token")
if [ "$RESPONSE" = "401" ]; then
    print_success "无效 Token 被拒绝 (401)"
else
    print_error "无效 Token 被接受? 状态码: $RESPONSE"
fi

# 4. 路由与业务逻辑
print_title "4. 路由与业务逻辑"

# 4.1 Catalog Service
echo "4.1 测试 Catalog Service 路由 (/api/courses)"
RESPONSE=$(curl -s -w "\n%{http_code}" "$GATEWAY_URL/api/courses" -H "Authorization: Bearer $TOKEN")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "200" ]; then
    print_success "Catalog Service 可访问"
    echo "$BODY" | jq 'del(.data[3:])' # 仅显示前3项以节省空间
else
    print_error "Catalog Service 访问失败。状态码: $HTTP_CODE"
    echo "$BODY" | jq .
fi

# 4.2 Enrollment Service
echo -e "\n4.2 测试 Enrollment Service 路由 (/api/enrollments)"
RESPONSE=$(curl -s -w "\n%{http_code}" "$GATEWAY_URL/api/enrollments" -H "Authorization: Bearer $TOKEN")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "200" ]; then
    print_success "Enrollment Service 可访问"
    echo "$BODY" | jq 'del(.data[3:])'
else
    print_error "Enrollment Service 访问失败。状态码: $HTTP_CODE"
    echo "$BODY" | jq .
fi

# 4.3 用户信息头传递
echo -e "\n4.3 测试用户信息头传递 (/api/auth/me)"
RESPONSE=$(curl -s "$GATEWAY_URL/api/auth/me" -H "Authorization: Bearer $TOKEN")
echo "$RESPONSE" | jq .

# 5. 基于角色的访问控制
print_title "5. 基于角色的访问控制验证"

check_login() {
    local user=$1
    local pass=$2
    local role=$3
    echo -n "测试登录用户 $user ($role)... "
    RES=$(curl -s -X POST "$GATEWAY_URL/api/auth/login" -H "Content-Type: application/json" -d "{\"username\":\"$user\",\"password\":\"$pass\"}")
    GOT_ROLE=$(echo "$RES" | jq -r '.data.user.role // empty')
    if [ "$GOT_ROLE" = "$role" ]; then
        print_success "成功"
    else
        print_error "失败。获取到的角色: $GOT_ROLE"
    fi
}

check_login "student1" "123456" "STUDENT"
check_login "teacher" "teacher123" "TEACHER"

# 6. 负载测试
print_title "6. 简单负载测试 (10 次请求)"
SUCCESS_COUNT=0
for i in {1..10}; do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/api/courses" -H "Authorization: Bearer $TOKEN")
    if [ "$CODE" = "200" ]; then
        echo -n -e "${GREEN}.${NC}"
        ((SUCCESS_COUNT++))
    else
        echo -n -e "${RED}x${NC}"
    fi
done
echo ""
print_success "成功请求数: $SUCCESS_COUNT/10"

print_separator
print_success "测试套件执行完成！"
