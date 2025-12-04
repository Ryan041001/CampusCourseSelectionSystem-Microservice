#!/bin/bash
# test-all-apis.sh
# 自动化测试脚本 - 覆盖所有API端点

# set -e  # 遇到错误立即退出

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

# 服务端口配置 (动态检测)
CATALOG_PORT=$(get_service_port "catalog-service" "8081" "8081")
ENROLLMENT_PORT=$(get_service_port "enrollment-service" "8082" "8085")
USER_PORT=$(get_service_port "user-service" "8080" "8079")
BASE_URL_CATALOG="http://localhost:$CATALOG_PORT"
BASE_URL_ENROLLMENT="http://localhost:$ENROLLMENT_PORT"
BASE_URL_USER="http://localhost:$USER_PORT"

echo "========================================="
echo "  校园选课系统微服务 - 自动化测试套件"
echo "========================================="
echo ""

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 测试计数器
PASSED=0
FAILED=0

# 辅助函数：打印API请求详情
print_request() {
    local method=$1
    local url=$2
    local data=$3
    echo -e "${CYAN}[请求] ${method} ${url}${NC}"
    if [ -n "$data" ]; then
        echo -e "${BLUE}[请求体]${NC}"
        echo "$data" | jq '.' 2>/dev/null || echo "$data"
    fi
}

echo "═══════════════════════════════════════"
echo "第一部分: User Service API 测试"
echo "═══════════════════════════════════════"
echo ""

TEST_STUDENT_ID="STU$(date +%s)"

# TC-US-001: 创建学生
echo ">>> TC-US-001: 创建学生"
REQUEST_DATA=$(cat <<EOF
{
  "studentId": "$TEST_STUDENT_ID",
  "name": "张三",
  "major": "计算机科学与技术",
  "grade": 2024,
  "email": "zhangsan+$TEST_STUDENT_ID@zjgsu.edu.cn"
}
EOF
)
print_request "POST" "$BASE_URL_USER/api/users" "$REQUEST_DATA"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $BASE_URL_USER/api/users \
-H "Content-Type: application/json" \
-d "$REQUEST_DATA")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" == "201" ]; then
    echo -e "${GREEN}✓ TC-US-001 PASSED (HTTP: $HTTP_CODE)${NC}"
    PASSED=$((PASSED+1))
    USER_ID=$(echo "$RESPONSE_BODY" | jq -r '.data.id')
    USER_STUDENT_ID=$(echo "$RESPONSE_BODY" | jq -r '.data.studentId')
else
    echo -e "${RED}✗ TC-US-001 FAILED (HTTP: $HTTP_CODE)${NC}"
    FAILED=$((FAILED+1))
    echo "$RESPONSE_BODY"
    exit 1
fi
echo ""

# TC-US-002: 查询所有学生
echo ">>> TC-US-002: 查询所有学生"
print_request "GET" "$BASE_URL_USER/api/users"
RESPONSE=$(curl -s -w "\n%{http_code}" $BASE_URL_USER/api/users)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ TC-US-002 PASSED (HTTP: $HTTP_CODE)${NC}"
    PASSED=$((PASSED+1))
else
    echo -e "${RED}✗ TC-US-002 FAILED (HTTP: $HTTP_CODE)${NC}"
    FAILED=$((FAILED+1))
fi
echo ""

# TC-US-003: 根据学号查询
echo ">>> TC-US-003: 根据学号查询学生"
print_request "GET" "$BASE_URL_USER/api/users/student/$USER_STUDENT_ID"
RESPONSE=$(curl -s -w "\n%{http_code}" $BASE_URL_USER/api/users/student/$USER_STUDENT_ID)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ TC-US-003 PASSED (HTTP: $HTTP_CODE)${NC}"
    PASSED=$((PASSED+1))
else
    echo -e "${RED}✗ TC-US-003 FAILED (HTTP: $HTTP_CODE)${NC}"
    FAILED=$((FAILED+1))
fi
echo ""

# TC-US-004: 更新学生
echo ">>> TC-US-004: 更新学生信息"
REQUEST_DATA=$(cat <<EOF
{
  "studentId": "$USER_STUDENT_ID",
  "name": "张三",
  "major": "软件工程",
  "grade": 2025,
  "email": "zhangsan+$USER_STUDENT_ID@zjgsu.edu.cn"
}
EOF
)
print_request "PUT" "$BASE_URL_USER/api/users/$USER_ID" "$REQUEST_DATA"
RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT $BASE_URL_USER/api/users/$USER_ID \
-H "Content-Type: application/json" \
-d "$REQUEST_DATA")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ TC-US-004 PASSED (HTTP: $HTTP_CODE)${NC}"
    PASSED=$((PASSED+1))
else
    echo -e "${RED}✗ TC-US-004 FAILED (HTTP: $HTTP_CODE)${NC}"
    FAILED=$((FAILED+1))
fi
echo ""

echo "═══════════════════════════════════════"
echo "第二部分: Catalog Service API 测试"
echo "═══════════════════════════════════════"
echo ""

# TC-CS-001: 创建课程
echo ">>> TC-CS-001: 创建课程"
REQUEST_DATA='{
  "code": "CS101",
  "title": "计算机科学导论",
  "instructor": {
    "id": "T001",
    "name": "张教授",
    "email": "zhang@zjgsu.edu.cn"
  },
  "schedule": {
    "dayOfWeek": "MONDAY",
    "startTime": "08:00",
    "endTime": "10:00"
  },
  "capacity": 60,
  "enrolled": 0,
  "expectedAttendance": 50
}'
print_request "POST" "$BASE_URL_CATALOG/api/courses" "$REQUEST_DATA"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $BASE_URL_CATALOG/api/courses \
-H "Content-Type: application/json" \
-d "$REQUEST_DATA")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" == "201" ]; then
    echo -e "${GREEN}✓ TC-CS-001 PASSED (HTTP: $HTTP_CODE)${NC}"
    PASSED=$((PASSED+1))
    echo -e "${GREEN}[响应]${NC}"
    echo "$RESPONSE_BODY" | jq '.'
else
    echo -e "${RED}✗ TC-CS-001 FAILED (HTTP: $HTTP_CODE)${NC}"
    FAILED=$((FAILED+1))
    echo "$RESPONSE_BODY"
fi
echo ""

# TC-CS-002: 获取所有课程
echo ">>> TC-CS-002: 获取所有课程"
print_request "GET" "$BASE_URL_CATALOG/api/courses"
RESPONSE=$(curl -s -w "\n%{http_code}" $BASE_URL_CATALOG/api/courses)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ TC-CS-002 PASSED (HTTP: $HTTP_CODE)${NC}"
    PASSED=$((PASSED+1))
    # 保存课程ID供后续测试使用
    COURSE_ID=$(echo "$RESPONSE_BODY" | jq -r '.data[0].id')
    echo "课程数量: $(echo "$RESPONSE_BODY" | jq '.data | length')"
else
    echo -e "${RED}✗ TC-CS-002 FAILED (HTTP: $HTTP_CODE)${NC}"
    FAILED=$((FAILED+1))
fi
echo ""

# TC-CS-003: 根据课程代码查询
echo ">>> TC-CS-003: 根据课程代码查询"
print_request "GET" "$BASE_URL_CATALOG/api/courses/code/CS101"
RESPONSE=$(curl -s -w "\n%{http_code}" $BASE_URL_CATALOG/api/courses/code/CS101)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ TC-CS-003 PASSED (HTTP: $HTTP_CODE)${NC}"
    PASSED=$((PASSED+1))
else
    echo -e "${RED}✗ TC-CS-003 FAILED (HTTP: $HTTP_CODE)${NC}"
    FAILED=$((FAILED+1))
fi
echo ""

# TC-CS-004: 根据ID查询课程
echo ">>> TC-CS-004: 根据ID查询课程"
print_request "GET" "$BASE_URL_CATALOG/api/courses/$COURSE_ID"
RESPONSE=$(curl -s -w "\n%{http_code}" $BASE_URL_CATALOG/api/courses/$COURSE_ID)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ TC-CS-004 PASSED (HTTP: $HTTP_CODE)${NC}"
    PASSED=$((PASSED+1))
else
    echo -e "${RED}✗ TC-CS-004 FAILED (HTTP: $HTTP_CODE)${NC}"
    FAILED=$((FAILED+1))
fi
echo ""

# TC-CS-005: 更新课程
echo ">>> TC-CS-005: 更新课程信息"
REQUEST_DATA='{
  "code": "CS101",
  "title": "计算机科学导论(更新)",
  "instructor": {
    "id": "T001",
    "name": "张教授",
    "email": "zhang@zjgsu.edu.cn"
  },
  "schedule": {
    "dayOfWeek": "TUESDAY",
    "startTime": "10:00",
    "endTime": "12:00"
  },
  "capacity": 80,
  "enrolled": 0,
  "expectedAttendance": 70
}'
print_request "PUT" "$BASE_URL_CATALOG/api/courses/$COURSE_ID" "$REQUEST_DATA"
RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT $BASE_URL_CATALOG/api/courses/$COURSE_ID \
-H "Content-Type: application/json" \
-d "$REQUEST_DATA")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ TC-CS-005 PASSED (HTTP: $HTTP_CODE)${NC}"
    PASSED=$((PASSED+1))
else
    echo -e "${RED}✗ TC-CS-005 FAILED (HTTP: $HTTP_CODE)${NC}"
    FAILED=$((FAILED+1))
fi
echo ""

# TC-CS-006: 增加选课人数
echo ">>> TC-CS-006: 增加选课人数"
print_request "POST" "$BASE_URL_CATALOG/api/courses/$COURSE_ID/increment"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $BASE_URL_CATALOG/api/courses/$COURSE_ID/increment)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ TC-CS-006 PASSED (HTTP: $HTTP_CODE)${NC}"
    PASSED=$((PASSED+1))
else
    echo -e "${RED}✗ TC-CS-006 FAILED (HTTP: $HTTP_CODE)${NC}"
    FAILED=$((FAILED+1))
fi
echo ""

# TC-CS-007: 减少选课人数
echo ">>> TC-CS-007: 减少选课人数"
print_request "POST" "$BASE_URL_CATALOG/api/courses/$COURSE_ID/decrement"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $BASE_URL_CATALOG/api/courses/$COURSE_ID/decrement)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ TC-CS-007 PASSED (HTTP: $HTTP_CODE)${NC}"
    PASSED=$((PASSED+1))
else
    echo -e "${RED}✗ TC-CS-007 FAILED (HTTP: $HTTP_CODE)${NC}"
    FAILED=$((FAILED+1))
fi
echo ""

# TC-CS-009: 查询不存在的课程
echo ">>> TC-CS-009: 查询不存在的课程(异常场景)"
print_request "GET" "$BASE_URL_CATALOG/api/courses/non-existent-id"
RESPONSE=$(curl -s -w "\n%{http_code}" $BASE_URL_CATALOG/api/courses/non-existent-id)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" == "404" ]; then
    echo -e "${GREEN}✓ TC-CS-009 PASSED (HTTP: $HTTP_CODE)${NC}"
    PASSED=$((PASSED+1))
else
    echo -e "${RED}✗ TC-CS-009 FAILED (HTTP: $HTTP_CODE, 期望: 404)${NC}"
    FAILED=$((FAILED+1))
fi
echo ""

echo "═══════════════════════════════════════"
echo "第三部分: Enrollment Service - 选课管理测试"
echo "═══════════════════════════════════════"
echo ""

# TC-ES-006: 学生选课 (服务间通信测试)
echo ">>> TC-ES-006: 学生选课 (验证服务间通信)"
REQUEST_DATA="{\"courseId\": \"$COURSE_ID\", \"studentId\": \"$USER_STUDENT_ID\"}"
print_request "POST" "$BASE_URL_ENROLLMENT/api/enrollments" "$REQUEST_DATA"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $BASE_URL_ENROLLMENT/api/enrollments \
-H "Content-Type: application/json" \
-d "$REQUEST_DATA")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" == "201" ]; then
    echo -e "${GREEN}✓ TC-ES-006 PASSED (HTTP: $HTTP_CODE, 服务间通信成功)${NC}"
    PASSED=$((PASSED+1))
    ENROLLMENT_ID=$(echo "$RESPONSE_BODY" | jq -r '.data.id')
    echo -e "${GREEN}[响应]${NC}"
    echo "$RESPONSE_BODY" | jq '.'
else
    echo -e "${RED}✗ TC-ES-006 FAILED (HTTP: $HTTP_CODE)${NC}"
    FAILED=$((FAILED+1))
    echo "$RESPONSE_BODY"
fi
echo ""

# TC-ES-007: 获取所有选课记录
echo ">>> TC-ES-007: 获取所有选课记录"
print_request "GET" "$BASE_URL_ENROLLMENT/api/enrollments"
RESPONSE=$(curl -s -w "\n%{http_code}" $BASE_URL_ENROLLMENT/api/enrollments)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ TC-ES-007 PASSED (HTTP: $HTTP_CODE)${NC}"
    PASSED=$((PASSED+1))
    echo "选课记录数量: $(echo "$RESPONSE_BODY" | jq '.data | length')"
else
    echo -e "${RED}✗ TC-ES-007 FAILED (HTTP: $HTTP_CODE)${NC}"
    FAILED=$((FAILED+1))
fi
echo ""

# TC-ES-008: 按课程查询选课记录
echo ">>> TC-ES-008: 按课程查询选课记录"
print_request "GET" "$BASE_URL_ENROLLMENT/api/enrollments/course/$COURSE_ID"
RESPONSE=$(curl -s -w "\n%{http_code}" $BASE_URL_ENROLLMENT/api/enrollments/course/$COURSE_ID)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ TC-ES-008 PASSED (HTTP: $HTTP_CODE)${NC}"
    PASSED=$((PASSED+1))
else
    echo -e "${RED}✗ TC-ES-008 FAILED (HTTP: $HTTP_CODE)${NC}"
    FAILED=$((FAILED+1))
fi
echo ""

# TC-ES-009: 按学生查询选课记录
echo ">>> TC-ES-009: 按学生查询选课记录"
print_request "GET" "$BASE_URL_ENROLLMENT/api/enrollments/student/$USER_STUDENT_ID"
RESPONSE=$(curl -s -w "\n%{http_code}" $BASE_URL_ENROLLMENT/api/enrollments/student/$USER_STUDENT_ID)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ TC-ES-009 PASSED (HTTP: $HTTP_CODE)${NC}"
    PASSED=$((PASSED+1))
else
    echo -e "${RED}✗ TC-ES-009 FAILED (HTTP: $HTTP_CODE)${NC}"
    FAILED=$((FAILED+1))
fi
echo ""

# TC-ES-012: 选课时课程不存在 (异常场景)
echo ">>> TC-ES-012: 选课时课程不存在(异常场景 - 服务间错误处理)"
REQUEST_DATA='{
  "courseId": "non-existent-course-id",
  "studentId": "non-existent-student"
}'
print_request "POST" "$BASE_URL_ENROLLMENT/api/enrollments" "$REQUEST_DATA"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $BASE_URL_ENROLLMENT/api/enrollments \
-H "Content-Type: application/json" \
-d "$REQUEST_DATA")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

# 404 (课程不存在) 或 503 (服务间通信错误) 都是可接受的响应
if [ "$HTTP_CODE" == "404" ] || [ "$HTTP_CODE" == "503" ]; then
    echo -e "${GREEN}✓ TC-ES-012 PASSED (HTTP: $HTTP_CODE, 正确处理课程不存在错误)${NC}"
    PASSED=$((PASSED+1))
else
    echo -e "${RED}✗ TC-ES-012 FAILED (HTTP: $HTTP_CODE, 期望: 404 或 503)${NC}"
    FAILED=$((FAILED+1))
fi
echo ""

# TC-ES-010: 学生退课
echo ">>> TC-ES-010: 学生退课"
print_request "DELETE" "$BASE_URL_ENROLLMENT/api/enrollments/$ENROLLMENT_ID"
RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE $BASE_URL_ENROLLMENT/api/enrollments/$ENROLLMENT_ID)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ TC-ES-010 PASSED (HTTP: $HTTP_CODE)${NC}"
    PASSED=$((PASSED+1))
else
    echo -e "${RED}✗ TC-ES-010 FAILED (HTTP: $HTTP_CODE)${NC}"
    FAILED=$((FAILED+1))
fi
echo ""

# TC-CS-008: 删除课程 (放到最后执行)
echo ">>> TC-CS-008: 删除课程"
print_request "DELETE" "$BASE_URL_CATALOG/api/courses/$COURSE_ID"
RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE $BASE_URL_CATALOG/api/courses/$COURSE_ID)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ TC-CS-008 PASSED (HTTP: $HTTP_CODE)${NC}"
    PASSED=$((PASSED+1))
else
    echo -e "${RED}✗ TC-CS-008 FAILED (HTTP: $HTTP_CODE)${NC}"
    FAILED=$((FAILED+1))
fi
echo ""

# TC-US-005: 删除学生（软删除）
echo ">>> TC-US-005: 删除学生"
print_request "DELETE" "$BASE_URL_USER/api/users/$USER_ID"
RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE $BASE_URL_USER/api/users/$USER_ID)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ TC-US-005 PASSED (HTTP: $HTTP_CODE)${NC}"
    PASSED=$((PASSED+1))
else
    echo -e "${RED}✗ TC-US-005 FAILED (HTTP: $HTTP_CODE)${NC}"
    FAILED=$((FAILED+1))
fi
echo ""

# 测试总结
echo ""
echo "========================================="
echo "           测试结果汇总"
echo "========================================="
echo -e "总测试数: $((PASSED + FAILED))"
echo -e "${GREEN}通过: $PASSED${NC}"
echo -e "${RED}失败: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 所有测试通过!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ 有测试失败，请检查日志${NC}"
    exit 1
fi
