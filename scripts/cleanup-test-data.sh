#!/bin/bash
# cleanup-test-data.sh
# 清理测试数据，为自动化测试做准备

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

CATALOG_PORT=$(get_service_port "catalog-service" "8081" "8081")
ENROLLMENT_PORT=$(get_service_port "enrollment-service" "8082" "8085")
USER_PORT=$(get_service_port "user-service" "8080" "8079")

BASE_URL_CATALOG="http://localhost:$CATALOG_PORT"
BASE_URL_ENROLLMENT="http://localhost:$ENROLLMENT_PORT"
BASE_URL_USER="http://localhost:$USER_PORT"

echo "========================================="
echo "  清理测试数据"
echo "========================================="
echo ""

# 删除所有选课记录
echo ">>> 删除所有选课记录..."
ENROLLMENTS=$(curl -s $BASE_URL_ENROLLMENT/api/enrollments | jq -r '.data[].id')
for enrollment_id in $ENROLLMENTS; do
    if [ ! -z "$enrollment_id" ]; then
        echo "删除选课记录: $enrollment_id"
        curl -s -X DELETE $BASE_URL_ENROLLMENT/api/enrollments/$enrollment_id > /dev/null
    fi
done

# 删除所有用户（软删除）
echo ">>> 删除所有学生（User Service）..."
STUDENTS=$(curl -s $BASE_URL_USER/api/users | jq -r '.data[].id')
for user_id in $STUDENTS; do
    if [ ! -z "$user_id" ]; then
        echo "删除学生: $user_id"
        curl -s -X DELETE $BASE_URL_USER/api/users/$user_id > /dev/null
    fi
done

# 删除所有课程
echo ">>> 删除所有课程..."
COURSES=$(curl -s $BASE_URL_CATALOG/api/courses | jq -r '.data[].id')
for course_id in $COURSES; do
    if [ ! -z "$course_id" ]; then
        echo "删除课程: $course_id"
        curl -s -X DELETE $BASE_URL_CATALOG/api/courses/$course_id > /dev/null
    fi
done

echo ""
echo "========================================="
echo "  数据清理完成！"
echo "========================================="
echo "现在可以运行测试脚本: ./test-all-apis.sh"
