#!/bin/bash

# ============================================================
# 服务间通信与负载均衡测试脚本
# 用于测试 OpenFeign + Spring Cloud LoadBalancer 功能
# ============================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 服务地址配置（根据 docker-compose 端口映射）
# Catalog Service: 8081, 8082, 8083 (3个实例)
# Enrollment Service: 8085
CATALOG_SERVICE="http://localhost:8081"
ENROLLMENT_SERVICE="http://localhost:8085"

# 计数器
PASS_COUNT=0
FAIL_COUNT=0

# 打印分隔线
print_separator() {
    echo -e "${BLUE}============================================================${NC}"
}

# 打印标题
print_title() {
    print_separator
    echo -e "${CYAN}$1${NC}"
    print_separator
}

# 打印成功
print_success() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    ((PASS_COUNT++))
}

# 打印失败
print_fail() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    ((FAIL_COUNT++))
}

# 打印信息
print_info() {
    echo -e "${YELLOW}→${NC} $1"
}

# 检查服务是否可用
check_service() {
    local service_name=$1
    local url=$2
    
    print_info "检查 $service_name 是否可用..."
    
    if curl -s --connect-timeout 5 "$url" > /dev/null 2>&1; then
        print_success "$service_name 服务正常运行"
        return 0
    else
        print_fail "$service_name 服务不可用 ($url)"
        return 1
    fi
}

# 测试 Catalog Service 基础功能
test_catalog_service() {
    print_title "测试 1: Catalog Service 基础功能"
    
    # 测试获取所有课程
    print_info "获取所有课程列表..."
    response=$(curl -s "$CATALOG_SERVICE/api/courses")
    
    if echo "$response" | grep -q '"code":200'; then
        print_success "获取课程列表成功"
        echo "$response" | head -c 200
        echo "..."
    else
        print_fail "获取课程列表失败"
        echo "$response"
    fi
    echo ""
    
    # 测试获取服务端口信息
    print_info "获取 Catalog Service 端口信息..."
    response=$(curl -s "$CATALOG_SERVICE/api/courses/port")
    
    if echo "$response" | grep -q '"code":200'; then
        print_success "获取端口信息成功"
        echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
    else
        print_fail "获取端口信息失败"
    fi
    echo ""
}

# 测试 Enrollment Service 基础功能
test_enrollment_service() {
    print_title "测试 2: Enrollment Service 基础功能"
    
    # 测试获取所有选课记录
    print_info "获取所有选课记录..."
    response=$(curl -s "$ENROLLMENT_SERVICE/api/enrollments")
    
    if echo "$response" | grep -q '"code":200'; then
        print_success "获取选课记录成功"
        echo "$response" | head -c 200
        echo "..."
    else
        print_fail "获取选课记录失败"
        echo "$response"
    fi
    echo ""
    
    # 测试获取服务端口信息
    print_info "获取 Enrollment Service 端口信息..."
    response=$(curl -s "$ENROLLMENT_SERVICE/api/enrollments/port")
    
    if echo "$response" | grep -q '"code":200'; then
        print_success "获取端口信息成功"
        echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
    else
        print_fail "获取端口信息失败"
    fi
    echo ""
}

# 测试 OpenFeign 服务间调用
test_feign_service_call() {
    print_title "测试 3: OpenFeign 服务间调用"
    
    print_info "通过 Enrollment Service 调用 Catalog Service..."
    response=$(curl -s "$ENROLLMENT_SERVICE/api/enrollments/test")
    
    if echo "$response" | grep -q '"code":200'; then
        print_success "OpenFeign 服务调用成功"
        echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
        
        # 检查是否成功获取到 catalog 端口
        if echo "$response" | grep -q '"catalog_port"'; then
            catalog_port=$(echo "$response" | grep -o '"catalog_port":"[^"]*"' | sed 's/"catalog_port":"//;s/"//')
            if [ -n "$catalog_port" ] && [ "$catalog_port" != "Error" ]; then
                print_success "Feign 调用成功，Catalog Service 端口: $catalog_port"
            else
                print_fail "Feign 调用返回错误"
            fi
        fi
    else
        print_fail "OpenFeign 服务调用失败"
        echo "$response"
    fi
    echo ""
}

# 测试负载均衡
test_load_balancer() {
    print_title "测试 4: Spring Cloud LoadBalancer 负载均衡"
    
    local call_count=10
    print_info "进行 $call_count 次服务调用测试负载均衡效果..."
    
    # 首先尝试专用的负载均衡测试端点
    response=$(curl -s "$ENROLLMENT_SERVICE/api/enrollments/test/loadbalancer?count=$call_count")
    
    if echo "$response" | grep -q '"code":200'; then
        print_success "负载均衡测试完成（使用专用端点）"
        echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
        
        # 分析端口分布
        print_info "分析负载均衡结果..."
        if echo "$response" | grep -q '"port_distribution"'; then
            distribution=$(echo "$response" | grep -o '"port_distribution":{[^}]*}' || echo "")
            echo -e "${CYAN}端口分布: $distribution${NC}"
        fi
        
        # 检查负载均衡分析结果
        if echo "$response" | grep -q '负载均衡生效'; then
            print_success "负载均衡生效！请求被分发到多个实例"
        elif echo "$response" | grep -q '只有1个'; then
            print_info "当前只有1个 catalog-service 实例运行（这是正常的，如果只启动了一个实例）"
        fi
    else
        # 专用端点不可用，使用多次调用 /test 端点的方式
        print_info "专用负载均衡端点不可用，使用多次调用方式测试..."
        
        # 使用临时文件统计
        port_file=$(mktemp)
        host_file=$(mktemp)
        success_count=0
        
        for i in $(seq 1 $call_count); do
            test_response=$(curl -s "$ENROLLMENT_SERVICE/api/enrollments/test")
            
            if echo "$test_response" | grep -q '"code":200'; then
                catalog_port=$(echo "$test_response" | grep -o '"catalog_port":"[^"]*"' | sed 's/"catalog_port":"//;s/"//')
                catalog_hostname=$(echo "$test_response" | grep -o '"catalog_hostname":"[^"]*"' | sed 's/"catalog_hostname":"//;s/"//')
                
                if [ -n "$catalog_port" ]; then
                    echo "  调用 #$i: Catalog 端口=$catalog_port, 主机=$catalog_hostname"
                    echo "$catalog_port" >> "$port_file"
                    echo "$catalog_hostname" >> "$host_file"
                    success_count=$((success_count + 1))
                fi
            else
                echo "  调用 #$i: 失败"
            fi
        done
        
        echo ""
        if [ $success_count -gt 0 ]; then
            print_success "完成 $success_count/$call_count 次成功调用"
            
            # 显示端口分布
            print_info "端口分布统计:"
            sort "$port_file" | uniq -c | while read count port; do
                echo "    端口 $port: $count 次"
            done
            
            # 显示主机分布
            print_info "主机分布统计（Docker 容器 ID）:"
            sort "$host_file" | uniq -c | while read count host; do
                echo "    主机 $host: $count 次"
            done
            
            unique_ports=$(sort "$port_file" | uniq | wc -l)
            unique_hosts=$(sort "$host_file" | uniq | wc -l)
            
            if [ "$unique_hosts" -gt 1 ]; then
                print_success "负载均衡生效！请求被轮询分发到 $unique_hosts 个不同的容器实例"
            elif [ "$unique_ports" -gt 1 ]; then
                print_success "负载均衡生效！请求被分发到 $unique_ports 个不同的端口"
            else
                print_info "当前只有1个 catalog-service 实例响应"
            fi
        else
            print_fail "所有调用都失败"
        fi
        
        rm -f "$port_file" "$host_file"
    fi
    echo ""
}

# 测试选课功能（包含 Feign 调用）
test_enrollment_with_feign() {
    print_title "测试 5: 选课功能（通过 Feign 验证课程）"
    
    # 首先获取一个课程 ID
    print_info "获取可用课程..."
    courses_response=$(curl -s "$CATALOG_SERVICE/api/courses")
    
    if ! echo "$courses_response" | grep -q '"code":200'; then
        print_fail "无法获取课程列表"
        return
    fi
    
    # 提取第一个课程的 ID（简单的 grep 方式）
    course_id=$(echo "$courses_response" | grep -o '"id":"[^"]*"' | head -1 | sed 's/"id":"//;s/"//')
    
    if [ -z "$course_id" ]; then
        print_info "没有找到可用课程，跳过选课测试"
        return
    fi
    
    print_info "找到课程 ID: $course_id"
    
    # 获取一个学生 ID
    print_info "获取学生信息..."
    students_response=$(curl -s "$ENROLLMENT_SERVICE/api/students")
    student_id=$(echo "$students_response" | grep -o '"studentId":"[^"]*"' | head -1 | sed 's/"studentId":"//;s/"//')
    
    if [ -z "$student_id" ]; then
        student_id="S2024001"
        print_info "使用默认学生 ID: $student_id"
    else
        print_info "找到学生 ID: $student_id"
    fi
    
    # 测试选课（这会触发 Feign 调用 catalog-service）
    print_info "测试选课功能..."
    enrollment_response=$(curl -s -X POST "$ENROLLMENT_SERVICE/api/enrollments" \
        -H "Content-Type: application/json" \
        -d "{\"studentId\": \"$student_id\", \"courseId\": \"$course_id\"}")
    
    echo "$enrollment_response" | python3 -m json.tool 2>/dev/null || echo "$enrollment_response"
    
    if echo "$enrollment_response" | grep -q '"code":201'; then
        print_success "选课成功（Feign 调用正常）"
        
        # 提取选课记录 ID 用于后续清理
        enrollment_id=$(echo "$enrollment_response" | grep -o '"id":"[^"]*"' | head -1 | sed 's/"id":"//;s/"//')
        
        if [ -n "$enrollment_id" ]; then
            print_info "清理测试数据，删除选课记录: $enrollment_id"
            delete_response=$(curl -s -X DELETE "$ENROLLMENT_SERVICE/api/enrollments/$enrollment_id")
            if echo "$delete_response" | grep -q '"code":200'; then
                print_success "测试数据清理成功"
            fi
        fi
    elif echo "$enrollment_response" | grep -q 'Already enrolled'; then
        print_info "学生已选过该课程（重复选课检查正常）"
    elif echo "$enrollment_response" | grep -q '课程已满'; then
        print_info "课程已满（容量检查正常，Feign 调用成功）"
    elif echo "$enrollment_response" | grep -q '课程不存在'; then
        print_fail "课程不存在（Feign 调用正常，但课程验证失败）"
    elif echo "$enrollment_response" | grep -q 'Student not found'; then
        print_info "学生不存在（需要先创建学生）"
    elif echo "$enrollment_response" | grep -q 'Catalog服务不可用'; then
        print_fail "Catalog 服务不可用（Feign 降级触发）"
    else
        print_fail "选课失败，未知错误"
    fi
    echo ""
}

# 测试服务降级
test_fallback() {
    print_title "测试 6: 服务降级（Fallback）"
    
    print_info "服务降级测试说明："
    echo "  要测试服务降级功能，需要停止 catalog-service 后再调用 enrollment-service"
    echo "  当 catalog-service 不可用时，CatalogClientFallbackFactory 会返回降级响应"
    echo ""
    print_info "当前状态检查..."
    
    response=$(curl -s "$ENROLLMENT_SERVICE/api/enrollments/test")
    
    if echo "$response" | grep -q '"code":200'; then
        if echo "$response" | grep -q '"catalog_port"'; then
            catalog_port=$(echo "$response" | grep -o '"catalog_port":"[^"]*"' | sed 's/"catalog_port":"//;s/"//')
            if [ -n "$catalog_port" ] && [ "$catalog_port" != "Error" ]; then
                print_success "Catalog Service 正常运行，Feign 调用成功"
            else
                print_info "Catalog Service 返回错误，可能触发了降级"
            fi
        else
            print_info "响应中没有 catalog_port 字段"
        fi
    elif echo "$response" | grep -q '"code":503'; then
        print_info "Catalog Service 不可用，降级机制已触发"
    else
        print_info "无法确定服务状态"
        echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
    fi
    echo ""
}

# 打印测试总结
print_summary() {
    print_title "测试总结"
    
    local total=$((PASS_COUNT + FAIL_COUNT))
    
    echo -e "总测试项: ${CYAN}$total${NC}"
    echo -e "通过: ${GREEN}$PASS_COUNT${NC}"
    echo -e "失败: ${RED}$FAIL_COUNT${NC}"
    echo ""
    
    if [ $FAIL_COUNT -eq 0 ]; then
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}       所有测试通过！ 🎉              ${NC}"
        echo -e "${GREEN}========================================${NC}"
    else
        echo -e "${YELLOW}========================================${NC}"
        echo -e "${YELLOW}     有 $FAIL_COUNT 个测试失败，请检查    ${NC}"
        echo -e "${YELLOW}========================================${NC}"
    fi
}

# 主函数
main() {
    echo ""
    print_title "OpenFeign + LoadBalancer 功能测试"
    echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # 检查服务可用性
    print_title "前置检查: 服务可用性"
    
    catalog_ok=false
    enrollment_ok=false
    
    if check_service "Catalog Service" "$CATALOG_SERVICE/api/courses"; then
        catalog_ok=true
    fi
    
    if check_service "Enrollment Service" "$ENROLLMENT_SERVICE/api/enrollments"; then
        enrollment_ok=true
    fi
    
    echo ""
    
    if [ "$catalog_ok" = false ] || [ "$enrollment_ok" = false ]; then
        echo -e "${RED}警告: 部分服务不可用，某些测试可能会失败${NC}"
        echo -e "${YELLOW}请确保已启动所有服务: docker-compose up -d${NC}"
        echo ""
    fi
    
    # 执行测试
    if [ "$catalog_ok" = true ]; then
        test_catalog_service
    fi
    
    if [ "$enrollment_ok" = true ]; then
        test_enrollment_service
    fi
    
    if [ "$enrollment_ok" = true ]; then
        test_feign_service_call
        test_load_balancer
        test_enrollment_with_feign
        test_fallback
    fi
    
    # 打印总结
    print_summary
}

# 显示帮助
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo "  -c, --catalog  仅测试 Catalog Service"
    echo "  -e, --enrollment 仅测试 Enrollment Service"
    echo "  -f, --feign    仅测试 Feign 服务调用"
    echo "  -l, --lb       仅测试负载均衡"
    echo ""
    echo "环境变量:"
    echo "  CATALOG_URL    Catalog Service 地址 (默认: http://localhost:8081)"
    echo "  ENROLLMENT_URL Enrollment Service 地址 (默认: http://localhost:8082)"
    echo ""
    echo "示例:"
    echo "  $0              # 运行所有测试"
    echo "  $0 -f           # 仅测试 Feign 调用"
    echo "  $0 -l           # 仅测试负载均衡"
}

# 解析命令行参数
case "$1" in
    -h|--help)
        show_help
        exit 0
        ;;
    -c|--catalog)
        print_title "仅测试 Catalog Service"
        check_service "Catalog Service" "$CATALOG_SERVICE/api/courses"
        test_catalog_service
        print_summary
        ;;
    -e|--enrollment)
        print_title "仅测试 Enrollment Service"
        check_service "Enrollment Service" "$ENROLLMENT_SERVICE/api/enrollments"
        test_enrollment_service
        print_summary
        ;;
    -f|--feign)
        print_title "仅测试 Feign 服务调用"
        check_service "Enrollment Service" "$ENROLLMENT_SERVICE/api/enrollments"
        test_feign_service_call
        print_summary
        ;;
    -l|--lb)
        print_title "仅测试负载均衡"
        check_service "Enrollment Service" "$ENROLLMENT_SERVICE/api/enrollments"
        test_load_balancer
        print_summary
        ;;
    "")
        main
        ;;
    *)
        echo "未知选项: $1"
        show_help
        exit 1
        ;;
esac
