#!/bin/bash
# cleanup-test-data.sh
# 清理测试数据，为自动化测试做准备

BASE_URL_CATALOG="http://localhost:8081"
BASE_URL_ENROLLMENT="http://localhost:8082"

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

# 删除所有学生
echo ">>> 删除所有学生..."
STUDENTS=$(curl -s $BASE_URL_ENROLLMENT/api/students | jq -r '.data[].id')
for student_id in $STUDENTS; do
    if [ ! -z "$student_id" ]; then
        echo "删除学生: $student_id"
        curl -s -X DELETE $BASE_URL_ENROLLMENT/api/students/$student_id > /dev/null
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
