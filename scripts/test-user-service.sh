#!/bin/bash

# ============================================================
# User Service 综合测试脚本
# 测试特性: CRUD操作 + 软删除 + 数据验证 + Nacos集成
# ============================================================

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 服务地址配置
USER_SERVICE_URL="http://localhost:8079"
NACOS_URL="http://localhost:8848"
NACOS_GROUP="COURSEHUB_GROUP"

# 测试计数器
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 测试数据存储
TEST_USER_ID=""
TEST_STUDENT_ID="TEST_$(date +%s)"
TEST_EMAIL="test_${TEST_STUDENT_ID}@zjgsu.edu.cn"

# 打印分隔符
print_separator() {
    echo -e "${BLUE}========================================${NC}"
}

# 打印成功消息
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

# 打印错误消息
print_error() {
    echo -e "${RED}✗ $1${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

# 打印警告消息
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# 打印信息
print_info() {
    echo -e "${CYAN}→ $1${NC}"
}

# 打印标题
print_title() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# 检查服务是否运行
check_service() {
    local service_name=$1
    local url=$2
    
    if curl -s --connect-timeout 3 "$url/actuator/health" > /dev/null 2>&1; then
        print_success "$service_name 正在运行"
        return 0
    else
        print_error "$service_name 未运行"
        return 1
    fi
}

# 检查 Nacos
check_nacos() {
    if curl -s --connect-timeout 3 "$NACOS_URL/nacos/" > /dev/null 2>&1; then
        print_success "Nacos 正在运行"
        return 0
    else
        print_error "Nacos 未运行"
        return 1
    fi
}

# 测试 API 调用
test_api() {
    local test_name=$1
    local method=$2
    local endpoint=$3
    local data=$4
    local expected_code=$5
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    local response
    local http_code
    
    if [ "$method" = "GET" ] || [ "$method" = "DELETE" ]; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$USER_SERVICE_URL$endpoint")
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$USER_SERVICE_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data")
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "$expected_code" ]; then
        print_success "$test_name (HTTP $http_code)"
        echo "$body"
        return 0
    else
        print_error "$test_name (Expected HTTP $expected_code, got $http_code)"
        echo "$body"
        return 1
    fi
}

# ============================================================
# 测试开始
# ============================================================

print_title "User Service 综合测试 (v1.0.0)"
echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
print_separator

# 1. 检查服务状态
print_title "1. 检查服务状态"
check_nacos
check_service "user-service" "$USER_SERVICE_URL"

# 检查健康端点
print_info "检查健康端点详情..."
HEALTH_RESPONSE=$(curl -s "$USER_SERVICE_URL/actuator/health")
echo "$HEALTH_RESPONSE" | jq '.'

# 2. 测试 Nacos 服务发现
print_title "2. 测试 Nacos 服务发现"
print_info "查询 user-service 注册信息..."
NACOS_RESPONSE=$(curl -s "$NACOS_URL/nacos/v1/ns/instance/list?serviceName=user-service&groupName=$NACOS_GROUP")
echo "$NACOS_RESPONSE" | jq '.'

if echo "$NACOS_RESPONSE" | grep -q '"healthy":true'; then
    print_success "user-service 已成功注册到 Nacos 且状态健康"
else
    print_warning "user-service 可能未正确注册到 Nacos"
fi

# 3. 测试获取所有用户
print_title "3. 测试获取所有用户 (GET /api/users)"
ALL_USERS_RESPONSE=$(curl -s "$USER_SERVICE_URL/api/users")
echo "$ALL_USERS_RESPONSE" | jq '.data[:3]'  # 显示前3个用户

USER_COUNT=$(echo "$ALL_USERS_RESPONSE" | jq '.data | length')
if [ "$USER_COUNT" -gt 0 ]; then
    print_success "成功获取 $USER_COUNT 个用户"
else
    print_warning "用户列表为空"
fi

# 4. 测试创建用户
print_title "4. 测试创建用户 (POST /api/users)"

NEW_USER="{
  \"studentId\": \"$TEST_STUDENT_ID\",
  \"name\": \"测试用户\",
  \"major\": \"软件工程\",
  \"grade\": 2024,
  \"email\": \"$TEST_EMAIL\"
}"

print_info "创建测试用户: $TEST_STUDENT_ID"
CREATE_RESPONSE=$(curl -s -X POST "$USER_SERVICE_URL/api/users" \
    -H "Content-Type: application/json" \
    -d "$NEW_USER")
echo "$CREATE_RESPONSE" | jq '.'

TEST_USER_ID=$(echo "$CREATE_RESPONSE" | jq -r '.data.id // empty')
if [ -n "$TEST_USER_ID" ] && [ "$TEST_USER_ID" != "null" ]; then
    print_success "创建用户成功，ID: ${TEST_USER_ID:0:8}..."
else
    print_error "创建用户失败"
    exit 1
fi

# 5. 测试根据 ID 获取用户
print_title "5. 测试根据 ID 获取用户 (GET /api/users/{id})"
print_info "获取用户 ID: ${TEST_USER_ID:0:8}..."
GET_RESPONSE=$(curl -s "$USER_SERVICE_URL/api/users/$TEST_USER_ID")
echo "$GET_RESPONSE" | jq '.data'

if echo "$GET_RESPONSE" | jq -e '.data.id' > /dev/null; then
    print_success "成功获取用户信息"
else
    print_error "获取用户信息失败"
fi

# 6. 测试根据学号获取用户
print_title "6. 测试根据学号获取用户 (GET /api/users/student/{studentId})"
print_info "获取学号: $TEST_STUDENT_ID"
STUDENT_RESPONSE=$(curl -s "$USER_SERVICE_URL/api/users/student/$TEST_STUDENT_ID")
echo "$STUDENT_RESPONSE" | jq '.data'

if echo "$STUDENT_RESPONSE" | jq -e '.data.studentId' > /dev/null; then
    print_success "成功根据学号获取用户"
else
    print_error "根据学号获取用户失败"
fi

# 7. 测试更新用户
print_title "7. 测试更新用户 (PUT /api/users/{id})"

UPDATE_USER="{
  \"studentId\": \"$TEST_STUDENT_ID\",
  \"name\": \"测试用户-已更新\",
  \"major\": \"计算机科学与技术\",
  \"grade\": 2024,
  \"email\": \"$TEST_EMAIL\"
}"

print_info "更新用户信息..."
UPDATE_RESPONSE=$(curl -s -X PUT "$USER_SERVICE_URL/api/users/$TEST_USER_ID" \
    -H "Content-Type: application/json" \
    -d "$UPDATE_USER")
echo "$UPDATE_RESPONSE" | jq '.data'

UPDATED_NAME=$(echo "$UPDATE_RESPONSE" | jq -r '.data.name // empty')
if [ "$UPDATED_NAME" = "测试用户-已更新" ]; then
    print_success "用户信息更新成功"
else
    print_error "用户信息更新失败"
fi

# 8. 测试重复学号验证
print_title "8. 测试重复学号验证"

DUPLICATE_USER="{
  \"studentId\": \"$TEST_STUDENT_ID\",
  \"name\": \"重复学号测试\",
  \"major\": \"软件工程\",
  \"grade\": 2024,
  \"email\": \"duplicate_test@zjgsu.edu.cn\"
}"

print_info "尝试创建重复学号的用户..."
DUP_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$USER_SERVICE_URL/api/users" \
    -H "Content-Type: application/json" \
    -d "$DUPLICATE_USER")

DUP_CODE=$(echo "$DUP_RESPONSE" | tail -n1)
DUP_BODY=$(echo "$DUP_RESPONSE" | sed '$d')

if [ "$DUP_CODE" = "400" ] || [ "$DUP_CODE" = "409" ]; then
    print_success "正确拒绝重复学号 (HTTP $DUP_CODE)"
    echo "$DUP_BODY" | jq '.'
else
    print_error "未正确处理重复学号 (HTTP $DUP_CODE)"
fi

# 9. 测试重复邮箱验证
print_title "9. 测试重复邮箱验证"

DUPLICATE_EMAIL_USER="{
  \"studentId\": \"TEST_DUP_EMAIL_$(date +%s)\",
  \"name\": \"重复邮箱测试\",
  \"major\": \"软件工程\",
  \"grade\": 2024,
  \"email\": \"$TEST_EMAIL\"
}"

print_info "尝试创建重复邮箱的用户..."
DUP_EMAIL_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$USER_SERVICE_URL/api/users" \
    -H "Content-Type: application/json" \
    -d "$DUPLICATE_EMAIL_USER")

DUP_EMAIL_CODE=$(echo "$DUP_EMAIL_RESPONSE" | tail -n1)
DUP_EMAIL_BODY=$(echo "$DUP_EMAIL_RESPONSE" | sed '$d')

if [ "$DUP_EMAIL_CODE" = "400" ] || [ "$DUP_EMAIL_CODE" = "409" ]; then
    print_success "正确拒绝重复邮箱 (HTTP $DUP_EMAIL_CODE)"
    echo "$DUP_EMAIL_BODY" | jq '.'
else
    print_error "未正确处理重复邮箱 (HTTP $DUP_EMAIL_CODE)"
fi

# 10. 测试软删除功能
print_title "10. 测试软删除功能 (DELETE /api/users/{id})"

print_info "执行软删除操作..."
DELETE_RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "$USER_SERVICE_URL/api/users/$TEST_USER_ID")
DELETE_CODE=$(echo "$DELETE_RESPONSE" | tail -n1)
DELETE_BODY=$(echo "$DELETE_RESPONSE" | sed '$d')

if [ "$DELETE_CODE" = "200" ]; then
    print_success "软删除执行成功 (HTTP $DELETE_CODE)"
    echo "$DELETE_BODY" | jq '.'
else
    print_error "软删除执行失败 (HTTP $DELETE_CODE)"
fi

# 11. 验证软删除后无法获取
print_title "11. 验证软删除后用户不可见"

print_info "尝试获取已删除的用户..."
DELETED_GET_RESPONSE=$(curl -s -w "\n%{http_code}" "$USER_SERVICE_URL/api/users/$TEST_USER_ID")
DELETED_GET_CODE=$(echo "$DELETED_GET_RESPONSE" | tail -n1)
DELETED_GET_BODY=$(echo "$DELETED_GET_RESPONSE" | sed '$d')

if [ "$DELETED_GET_CODE" = "404" ]; then
    print_success "已删除用户正确返回 404"
    echo "$DELETED_GET_BODY" | jq '.'
else
    print_warning "已删除用户返回码: HTTP $DELETED_GET_CODE (预期 404)"
fi

# 12. 验证软删除后可以重用学号
print_title "12. 验证软删除后可以重用学号和邮箱"

REUSE_USER="{
  \"studentId\": \"$TEST_STUDENT_ID\",
  \"name\": \"重用学号测试\",
  \"major\": \"数据科学\",
  \"grade\": 2024,
  \"email\": \"$TEST_EMAIL\"
}"

print_info "尝试创建相同学号的新用户..."
REUSE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$USER_SERVICE_URL/api/users" \
    -H "Content-Type: application/json" \
    -d "$REUSE_USER")

REUSE_CODE=$(echo "$REUSE_RESPONSE" | tail -n1)
REUSE_BODY=$(echo "$REUSE_RESPONSE" | sed '$d')

if [ "$REUSE_CODE" = "201" ]; then
    print_success "软删除后成功重用学号和邮箱 (HTTP $REUSE_CODE)"
    echo "$REUSE_BODY" | jq '.data'
    NEW_TEST_USER_ID=$(echo "$REUSE_BODY" | jq -r '.data.id // empty')
else
    print_warning "重用学号失败 (HTTP $REUSE_CODE) - 可能需要检查软删除实现"
    echo "$REUSE_BODY" | jq '.'
fi

# 13. 测试无效请求
print_title "13. 测试数据验证 - 缺少必填字段"

INVALID_USER="{
  \"studentId\": \"INVALID_TEST\",
  \"name\": \"\"
}"

print_info "尝试创建缺少必填字段的用户..."
INVALID_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$USER_SERVICE_URL/api/users" \
    -H "Content-Type: application/json" \
    -d "$INVALID_USER")

INVALID_CODE=$(echo "$INVALID_RESPONSE" | tail -n1)
INVALID_BODY=$(echo "$INVALID_RESPONSE" | sed '$d')

if [ "$INVALID_CODE" = "400" ]; then
    print_success "正确拒绝无效数据 (HTTP $INVALID_CODE)"
    echo "$INVALID_BODY" | jq '.'
else
    print_warning "无效数据处理返回: HTTP $INVALID_CODE (预期 400)"
fi

# 14. 测试不存在的用户
print_title "14. 测试获取不存在的用户"

print_info "尝试获取不存在的用户 ID..."
NOT_FOUND_RESPONSE=$(curl -s -w "\n%{http_code}" "$USER_SERVICE_URL/api/users/non-existent-id-12345")
NOT_FOUND_CODE=$(echo "$NOT_FOUND_RESPONSE" | tail -n1)
NOT_FOUND_BODY=$(echo "$NOT_FOUND_RESPONSE" | sed '$d')

if [ "$NOT_FOUND_CODE" = "404" ]; then
    print_success "不存在的用户正确返回 404"
    echo "$NOT_FOUND_BODY" | jq '.'
else
    print_error "不存在的用户返回码: HTTP $NOT_FOUND_CODE (预期 404)"
fi

# 15. 清理测试数据
print_title "15. 清理测试数据"

if [ -n "$NEW_TEST_USER_ID" ] && [ "$NEW_TEST_USER_ID" != "null" ]; then
    print_info "删除测试用户: ${NEW_TEST_USER_ID:0:8}..."
    curl -s -X DELETE "$USER_SERVICE_URL/api/users/$NEW_TEST_USER_ID" > /dev/null
    print_success "测试数据清理完成"
fi

# 测试总结
print_separator
print_title "测试完成总结"
echo ""
echo -e "${CYAN}总测试数: $TOTAL_TESTS${NC}"
echo -e "${GREEN}通过: $PASSED_TESTS${NC}"
echo -e "${RED}失败: $FAILED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ 所有测试通过！${NC}"
else
    echo -e "${YELLOW}⚠ 部分测试失败，请检查日志${NC}"
fi

print_separator

echo -e "\n${CYAN}测试覆盖范围:${NC}"
echo "  ✓ 服务健康检查"
echo "  ✓ Nacos 服务发现"
echo "  ✓ 用户 CRUD 操作"
echo "  ✓ 软删除功能验证"
echo "  ✓ 数据唯一性验证 (学号、邮箱)"
echo "  ✓ 数据验证 (必填字段)"
echo "  ✓ 错误处理 (404, 400)"
echo "  ✓ 软删除后数据重用"

echo -e "\n${CYAN}提示:${NC}"
echo "  • User Service API: $USER_SERVICE_URL"
echo "  • Nacos 控制台: http://localhost:8080 (nacos/nacos)"
echo "  • 查看日志: docker compose logs -f user-service"
echo "  • 查看数据库: docker exec -it mysql mysql -uroot -ppassword user_db"
echo ""
