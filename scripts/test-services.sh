#!/bin/bash

# ============================================================
# 校园选课系统微服务 - 综合服务测试脚本
# 测试特性: API Gateway + JWT认证 + OpenFeign + LoadBalancer + Nacos
# ============================================================

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 服务地址配置
GATEWAY_URL="http://localhost:8090"
NACOS_URL="http://localhost:8848"
NACOS_GROUP="COURSEHUB_GROUP"

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
CATALOG_URL="http://localhost:$CATALOG_PORT"
ENROLLMENT_URL="http://localhost:$ENROLLMENT_PORT"

# 测试账号
ADMIN_USER="admin"
ADMIN_PASS="admin123"
STUDENT_USER="student1"
STUDENT_PASS="123456"

# Token 存储
TOKEN=""

# 打印分隔符
print_separator() {
    echo -e "${BLUE}========================================${NC}"
}

# 打印成功消息
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# 打印错误消息
print_error() {
    echo -e "${RED}✗ $1${NC}"
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
}

# 检查服务是否运行
check_service() {
    local service_name=$1
    local port=$2

    if curl -s --connect-timeout 3 "http://localhost:$port/actuator/health" > /dev/null 2>&1 || \
       curl -s --connect-timeout 3 "http://localhost:$port" > /dev/null 2>&1; then
        print_success "$service_name 正在运行，端口 $port"
        return 0
    else
        print_error "$service_name 未运行，端口 $port"
        return 1
    fi
}

# 检查 Nacos
check_nacos() {
    if curl -s --connect-timeout 3 "$NACOS_URL/nacos/" > /dev/null 2>&1; then
        print_success "Nacos 正在运行 (API: 8848, gRPC: 9848, 控制台: 8080)"
        return 0
    else
        print_error "Nacos 未运行"
        return 1
    fi
}

# 登录获取 Token
do_login() {
    local username=$1
    local password=$2
    
    local response=$(curl -s -X POST "$GATEWAY_URL/api/auth/login" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"$username\",\"password\":\"$password\"}")
    
    TOKEN=$(echo "$response" | jq -r '.data.token // empty')
    
    if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
        return 0
    else
        return 1
    fi
}

# ============================================================
# 测试开始
# ============================================================

print_title "校园选课系统微服务 - 综合测试 (v1.0.0)"
echo "测试特性: API Gateway + JWT认证 + OpenFeign + LoadBalancer + Nacos"
echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
print_separator

# 1. 检查所有服务状态
print_title "1. 检查服务状态"
check_nacos
check_service "gateway-service" 8090
check_service "catalog-service" $CATALOG_PORT
check_service "enrollment-service" $ENROLLMENT_PORT

# 2. 测试 Nacos 服务发现
print_title "2. 测试 Nacos 服务发现"

print_info "查询已注册的服务..."
SERVICES=$(curl -s "$NACOS_URL/nacos/v1/ns/service/list?pageNo=1&pageSize=10&groupName=$NACOS_GROUP")
echo "$SERVICES" | jq '.'

if echo "$SERVICES" | grep -q "gateway-service"; then
    print_success "gateway-service 已注册到 Nacos"
else
    print_error "gateway-service 未注册到 Nacos"
fi

if echo "$SERVICES" | grep -q "catalog-service"; then
    print_success "catalog-service 已注册到 Nacos"
else
    print_error "catalog-service 未注册到 Nacos"
fi

if echo "$SERVICES" | grep -q "enrollment-service"; then
    print_success "enrollment-service 已注册到 Nacos"
else
    print_error "enrollment-service 未注册到 Nacos"
fi

# 3. 测试 Gateway 认证
print_title "3. 测试 Gateway JWT 认证"

echo "3.1 测试未认证访问（预期 401）"
RESPONSE=$(curl -s -w "\n%{http_code}" "$GATEWAY_URL/api/courses")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "401" ]; then
    print_success "未认证访问被正确拦截 (HTTP 401)"
else
    print_error "未认证访问未被拦截 (HTTP $HTTP_CODE)"
fi

echo -e "\n3.2 测试管理员登录 ($ADMIN_USER)"
LOGIN_RESPONSE=$(curl -s -X POST "$GATEWAY_URL/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$ADMIN_USER\",\"password\":\"$ADMIN_PASS\"}")
echo "$LOGIN_RESPONSE" | jq '.'

TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.data.token // empty')
if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
    print_success "登录成功，获取到 Token"
    print_info "Token: ${TOKEN:0:50}..."
else
    print_error "登录失败"
    exit 1
fi

echo -e "\n3.3 测试无效 Token"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/api/courses" \
    -H "Authorization: Bearer invalid_token_here")
if [ "$RESPONSE" = "401" ]; then
    print_success "无效 Token 被正确拒绝 (HTTP 401)"
else
    print_error "无效 Token 未被拒绝 (HTTP $RESPONSE)"
fi

echo -e "\n3.4 测试用户信息接口 (/api/auth/me)"
curl -s "$GATEWAY_URL/api/auth/me" -H "Authorization: Bearer $TOKEN" | jq '.'

# 4. 测试 Catalog Service API（通过 Gateway）
print_title "4. 测试 Catalog Service API（通过 Gateway）"

echo "4.1 获取所有课程"
COURSES_RESPONSE=$(curl -s "$GATEWAY_URL/api/courses" -H "Authorization: Bearer $TOKEN")
echo "$COURSES_RESPONSE" | jq '.data[:2]'  # 只显示前2个
COURSE_COUNT=$(echo "$COURSES_RESPONSE" | jq '.data | length')
print_success "获取到 $COURSE_COUNT 门课程"

# 提取第一个课程 ID
COURSE_ID=$(echo "$COURSES_RESPONSE" | jq -r '.data[0].id')
print_info "使用课程 ID: $COURSE_ID"

echo -e "\n4.2 创建新课程"
NEW_COURSE='{
  "code": "TEST001",
  "title": "测试课程-服务测试",
  "instructor": {"id": "T999", "name": "测试教授", "email": "test@zjgsu.edu.cn"},
  "schedule": {"dayOfWeek": "FRIDAY", "startTime": "14:00", "endTime": "16:00"},
  "capacity": 30,
  "enrolled": 0,
  "expectedAttendance": 25
}'
CREATE_RESPONSE=$(curl -s -X POST "$GATEWAY_URL/api/courses" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$NEW_COURSE")
echo "$CREATE_RESPONSE" | jq '.'

NEW_COURSE_ID=$(echo "$CREATE_RESPONSE" | jq -r '.data.id // empty')
if [ -n "$NEW_COURSE_ID" ] && [ "$NEW_COURSE_ID" != "null" ]; then
    print_success "创建课程成功，ID: $NEW_COURSE_ID"
else
    print_warning "创建课程失败（可能课程代码已存在）"
    # 尝试获取已存在的课程
    NEW_COURSE_ID=$(curl -s "$GATEWAY_URL/api/courses/code/TEST001" \
        -H "Authorization: Bearer $TOKEN" | jq -r '.data.id // empty')
fi

echo -e "\n4.3 根据课程代码查询"
curl -s "$GATEWAY_URL/api/courses/code/CS101" -H "Authorization: Bearer $TOKEN" | jq '.data | {code, title, instructor: .instructor.name}'

# 5. 测试 Enrollment Service API（通过 Gateway）
print_title "5. 测试 Enrollment Service API（通过 Gateway）"

echo "5.1 获取所有学生"
STUDENTS_RESPONSE=$(curl -s "$GATEWAY_URL/api/students" -H "Authorization: Bearer $TOKEN")
STUDENT_COUNT=$(echo "$STUDENTS_RESPONSE" | jq '.data | length')
print_success "获取到 $STUDENT_COUNT 名学生"

# 提取学生 ID
STUDENT_UUID=$(echo "$STUDENTS_RESPONSE" | jq -r '.data[0].id // empty')
STUDENT_ID=$(echo "$STUDENTS_RESPONSE" | jq -r '.data[0].studentId // "S2024001"')
print_info "使用学生: $STUDENT_ID (UUID: ${STUDENT_UUID:0:8}...)"

echo -e "\n5.2 获取所有选课记录"
ENROLLMENTS_RESPONSE=$(curl -s "$GATEWAY_URL/api/enrollments" -H "Authorization: Bearer $TOKEN")
ENROLLMENT_COUNT=$(echo "$ENROLLMENTS_RESPONSE" | jq '.data | length')
print_success "获取到 $ENROLLMENT_COUNT 条选课记录"

# 6. 测试 OpenFeign 服务间通信
print_title "6. 测试 OpenFeign 服务间通信"

echo "6.1 测试选课功能（Enrollment -> Catalog 服务调用）"
print_info "选课时 enrollment-service 会通过 Feign 调用 catalog-service 验证课程"

if [ -n "$NEW_COURSE_ID" ] && [ "$NEW_COURSE_ID" != "null" ]; then
    ENROLL_RESPONSE=$(curl -s -X POST "$GATEWAY_URL/api/enrollments" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"courseId\": \"$NEW_COURSE_ID\", \"studentId\": \"$STUDENT_ID\"}")
    echo "$ENROLL_RESPONSE" | jq '.'
    
    if echo "$ENROLL_RESPONSE" | grep -q '"code":201'; then
        print_success "选课成功！OpenFeign 服务间调用正常"
        ENROLLMENT_ID=$(echo "$ENROLL_RESPONSE" | jq -r '.data.id')
    elif echo "$ENROLL_RESPONSE" | grep -q 'Already enrolled'; then
        print_info "学生已选过该课程（重复选课检查正常）"
    else
        print_warning "选课返回: $(echo "$ENROLL_RESPONSE" | jq -r '.message // .error')"
    fi
else
    print_warning "没有可用的测试课程，跳过选课测试"
fi

echo -e "\n6.2 测试选课不存在的课程（异常场景）"
FAIL_RESPONSE=$(curl -s -X POST "$GATEWAY_URL/api/enrollments" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"courseId": "non-existent-course-id", "studentId": "S2024001"}')

if echo "$FAIL_RESPONSE" | grep -qE '"code":(404|503|500)'; then
    print_success "正确处理了不存在的课程（Feign 错误处理正常）"
else
    print_info "响应: $(echo "$FAIL_RESPONSE" | jq -r '.message // .error')"
fi

# 7. 测试负载均衡
print_title "7. 测试 Spring Cloud LoadBalancer"

echo "7.1 检查 catalog-service 实例数量"
INSTANCES=$(curl -s "$NACOS_URL/nacos/v1/ns/instance/list?serviceName=catalog-service&groupName=$NACOS_GROUP" 2>/dev/null)
INSTANCE_COUNT=$(echo "$INSTANCES" | jq '.hosts | length' 2>/dev/null || echo "1")
print_info "当前 catalog-service 实例数: $INSTANCE_COUNT"

echo -e "\n7.2 连续请求测试负载均衡（10次）"
print_info "通过 Gateway 发送 10 次请求..."

SUCCESS_COUNT=0
for i in {1..10}; do
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/api/courses" \
        -H "Authorization: Bearer $TOKEN")
    if [ "$RESPONSE" = "200" ]; then
        echo -n -e "${GREEN}.${NC}"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo -n -e "${RED}x${NC}"
    fi
done
echo ""
print_success "完成 $SUCCESS_COUNT/10 次成功请求"

if [ "$INSTANCE_COUNT" -gt 1 ]; then
    print_info "多实例环境下，请求会被轮询分发到不同实例"
else
    print_info "当前单实例环境，如需测试负载均衡请扩容: docker compose up -d --scale catalog-service=3"
fi

# 8. 测试基于角色的访问控制
print_title "8. 测试基于角色的访问控制 (RBAC)"

echo "8.1 测试学生角色登录"
if do_login "$STUDENT_USER" "$STUDENT_PASS"; then
    print_success "学生 $STUDENT_USER 登录成功"
    STUDENT_TOKEN="$TOKEN"
    
    # 学生访问课程列表
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/api/courses" \
        -H "Authorization: Bearer $STUDENT_TOKEN")
    if [ "$RESPONSE" = "200" ]; then
        print_success "学生可以查看课程列表"
    else
        print_error "学生无法查看课程列表 (HTTP $RESPONSE)"
    fi
else
    print_error "学生登录失败"
fi

echo -e "\n8.2 测试教师角色登录"
if do_login "teacher" "teacher123"; then
    print_success "教师 teacher 登录成功"
else
    print_warning "教师登录失败（可能账号不存在）"
fi

# 9. 测试熔断器/容错机制
print_title "9. 熔断器/容错机制测试"

# 检查是否启用熔断测试（默认跳过，可通过参数启用）
if [ "$1" = "--circuit-breaker" ] || [ "$1" = "-cb" ]; then
    print_info "开始熔断器测试..."
    
    # 9.1 创建测试数据
    echo "9.1 创建熔断测试专用数据"
    
    # 创建测试课程
    CB_COURSE='{
      "code": "CB_TEST_'$(date +%s)'",
      "title": "熔断器测试课程",
      "instructor": {"id": "T_CB", "name": "熔断测试教授", "email": "cb_test@zjgsu.edu.cn"},
      "schedule": {"dayOfWeek": "MONDAY", "startTime": "08:00", "endTime": "10:00"},
      "capacity": 30,
      "enrolled": 0,
      "expectedAttendance": 25
    }'
    CB_COURSE_RESPONSE=$(curl -s -X POST "$CATALOG_URL/api/courses" \
        -H "Content-Type: application/json" \
        -d "$CB_COURSE")
    CB_COURSE_ID=$(echo "$CB_COURSE_RESPONSE" | jq -r '.data.id // empty')
    
    if [ -n "$CB_COURSE_ID" ] && [ "$CB_COURSE_ID" != "null" ]; then
        print_success "创建熔断测试课程成功，ID: ${CB_COURSE_ID:0:8}..."
    else
        print_error "创建熔断测试课程失败"
        CB_COURSE_ID=""
    fi
    
    # 创建测试学生
    CB_STUDENT='{
      "studentId": "CB_STU_'$(date +%s)'",
      "name": "熔断测试学生",
      "email": "cb_student_'$(date +%s)'@zjgsu.edu.cn",
      "password": "password123",
      "major": "计算机科学",
      "grade": 2024
    }'
    CB_STUDENT_RESPONSE=$(curl -s -X POST "$ENROLLMENT_URL/api/students" \
        -H "Content-Type: application/json" \
        -d "$CB_STUDENT")
    CB_STUDENT_ID=$(echo "$CB_STUDENT_RESPONSE" | jq -r '.data.studentId // empty')
    
    if [ -n "$CB_STUDENT_ID" ] && [ "$CB_STUDENT_ID" != "null" ]; then
        print_success "创建熔断测试学生成功，学号: $CB_STUDENT_ID"
    else
        print_error "创建熔断测试学生失败"
        CB_STUDENT_ID=""
    fi
    
    # 9.2 正常选课测试
    echo -e "\n9.2 正常选课测试（服务正常时）"
    if [ -n "$CB_COURSE_ID" ] && [ -n "$CB_STUDENT_ID" ]; then
        NORMAL_ENROLL=$(curl -s -X POST "$ENROLLMENT_URL/api/enrollments" \
            -H "Content-Type: application/json" \
            -d "{\"courseId\": \"$CB_COURSE_ID\", \"studentId\": \"$CB_STUDENT_ID\"}")
        
        if echo "$NORMAL_ENROLL" | grep -q '"code":201'; then
            print_success "正常选课成功 - OpenFeign 调用 catalog-service 正常"
            CB_ENROLLMENT_ID=$(echo "$NORMAL_ENROLL" | jq -r '.data.id // empty')
        else
            print_warning "正常选课响应: $(echo "$NORMAL_ENROLL" | jq -r '.message // .error')"
        fi
    fi
    
    # 9.3 停止 catalog-service 模拟故障
    echo -e "\n9.3 模拟服务故障 - 停止 catalog-service"
    CATALOG_CONTAINER=$(docker ps --format '{{.Names}}' | grep catalog-service | head -1)
    
    if [ -n "$CATALOG_CONTAINER" ]; then
        docker stop "$CATALOG_CONTAINER" > /dev/null 2>&1
        print_success "已停止容器: $CATALOG_CONTAINER"
        sleep 3  # 等待服务下线
        
        # 9.4 测试熔断机制
        echo -e "\n9.4 测试熔断机制 - 选课请求应快速失败"
        
        # 创建另一个测试学生用于熔断测试
        CB_STUDENT2='{
          "studentId": "CB_STU2_'$(date +%s)'",
          "name": "熔断测试学生2",
          "email": "cb_student2_'$(date +%s)'@zjgsu.edu.cn",
          "password": "password123",
          "major": "软件工程",
          "grade": 2024
        }'
        CB_STUDENT2_RESPONSE=$(curl -s -X POST "$ENROLLMENT_URL/api/students" \
            -H "Content-Type: application/json" \
            -d "$CB_STUDENT2")
        CB_STUDENT2_ID=$(echo "$CB_STUDENT2_RESPONSE" | jq -r '.data.studentId // empty')
        
        CIRCUIT_RESPONSE=$(curl -s -X POST "$ENROLLMENT_URL/api/enrollments" \
            -H "Content-Type: application/json" \
            -d "{\"courseId\": \"$CB_COURSE_ID\", \"studentId\": \"$CB_STUDENT2_ID\"}")
        
        CIRCUIT_CODE=$(echo "$CIRCUIT_RESPONSE" | jq -r '.code // 0')
        CIRCUIT_MSG=$(echo "$CIRCUIT_RESPONSE" | jq -r '.message // empty')
        
        if [ "$CIRCUIT_CODE" = "503" ]; then
            print_success "熔断机制正常触发！返回 503 快速失败"
            print_info "错误信息: $CIRCUIT_MSG"
        elif [ "$CIRCUIT_CODE" = "500" ] || [ "$CIRCUIT_CODE" = "502" ]; then
            print_warning "服务返回错误码 $CIRCUIT_CODE（熔断触发但可能未配置降级）"
        else
            print_error "熔断机制未正常工作，返回码: $CIRCUIT_CODE"
        fi
        
        # 9.5 重启 catalog-service
        echo -e "\n9.5 恢复服务 - 重启 catalog-service"
        docker start "$CATALOG_CONTAINER" > /dev/null 2>&1
        print_success "已重启容器: $CATALOG_CONTAINER"
        
        # 等待服务恢复
        print_info "等待服务重新注册到 Nacos..."
        sleep 15
        
        # 9.6 验证服务恢复
        echo -e "\n9.6 验证服务恢复"
        
        # 更新端口（可能变化）
        CATALOG_PORT=$(get_service_port "catalog-service" "8081" "8081")
        CATALOG_URL="http://localhost:$CATALOG_PORT"
        
        HEALTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" "$CATALOG_URL/api/courses" --connect-timeout 5)
        if [ "$HEALTH_CHECK" = "200" ]; then
            print_success "catalog-service 已恢复正常"
        else
            print_warning "catalog-service 可能仍在启动中 (HTTP $HEALTH_CHECK)"
        fi
        
        # 清理熔断测试数据
        if [ -n "$CB_ENROLLMENT_ID" ]; then
            curl -s -X DELETE "$ENROLLMENT_URL/api/enrollments/$CB_ENROLLMENT_ID" > /dev/null 2>&1
        fi
        if [ -n "$CB_STUDENT2_ID" ]; then
            # 删除第二个测试学生的选课记录（如果有）
            curl -s -X DELETE "$ENROLLMENT_URL/api/enrollments/student/$CB_STUDENT2_ID" > /dev/null 2>&1
        fi
        
    else
        print_error "未找到 catalog-service 容器"
    fi
    
    echo ""
    print_success "熔断器测试完成"
    
else
    print_info "熔断器测试已跳过（避免影响服务稳定性）"
    echo ""
    echo "  启用熔断测试: $0 --circuit-breaker"
    echo "  或简写:       $0 -cb"
    echo ""
    echo "  测试步骤（手动）："
    echo "    1. 停止 catalog-service: docker stop \$(docker ps -q --filter name=catalog-service)"
    echo "    2. 尝试选课，观察是否返回 503 快速失败"
    echo "    3. 重启服务: docker start \$(docker ps -aq --filter name=catalog-service)"
fi

# 10. 清理测试数据
print_title "10. 清理测试数据"

# 恢复管理员 Token
do_login "$ADMIN_USER" "$ADMIN_PASS"

# 删除测试选课记录
if [ -n "$ENROLLMENT_ID" ] && [ "$ENROLLMENT_ID" != "null" ]; then
    print_info "删除测试选课记录: $ENROLLMENT_ID"
    curl -s -X DELETE "$GATEWAY_URL/api/enrollments/$ENROLLMENT_ID" \
        -H "Authorization: Bearer $TOKEN" > /dev/null
    print_success "选课记录已删除"
fi

# 删除测试课程
if [ -n "$NEW_COURSE_ID" ] && [ "$NEW_COURSE_ID" != "null" ]; then
    print_info "删除测试课程: $NEW_COURSE_ID"
    curl -s -X DELETE "$GATEWAY_URL/api/courses/$NEW_COURSE_ID" \
        -H "Authorization: Bearer $TOKEN" > /dev/null
    print_success "测试课程已删除"
fi

# 测试总结
print_separator
print_title "测试完成总结"
echo "✓ 服务状态检查完成"
echo "✓ Nacos 服务发现验证完成"
echo "✓ Gateway JWT 认证测试完成"
echo "✓ Catalog Service API 测试完成"
echo "✓ Enrollment Service API 测试完成"
echo "✓ OpenFeign 服务间通信测试完成"
echo "✓ LoadBalancer 负载均衡测试完成"
echo "✓ RBAC 角色访问控制测试完成"
if [ "$1" = "--circuit-breaker" ] || [ "$1" = "-cb" ]; then
    echo "✓ 熔断器/容错机制测试完成"
else
    echo "○ 熔断器测试已跳过 (使用 -cb 参数启用)"
fi
echo "✓ 测试数据清理完成"
print_separator

echo -e "\n${CYAN}提示:${NC}"
echo "  • Nacos 控制台: http://localhost:8080 (nacos/nacos)"
echo "  • Gateway API: http://localhost:8090"
echo "  • 直接访问 Catalog: http://localhost:$CATALOG_PORT"
echo "  • 直接访问 Enrollment: http://localhost:$ENROLLMENT_PORT"
echo ""
echo "  扩容命令: docker compose up -d --scale catalog-service=3"
echo "  查看日志: docker compose logs -f gateway-service"
