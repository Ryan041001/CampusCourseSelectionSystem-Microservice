#!/bin/bash

# ============================================================
# 数据库重置脚本
# 将 catalog_db 和 enrollment_db 重置为初始状态
# ============================================================

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${CYAN}→ $1${NC}"; }

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SQL_DIR="$PROJECT_DIR/mysql"

# 数据库配置
CATALOG_CONTAINER="mysql-catalog"
ENROLLMENT_CONTAINER="mysql-enrollment"
MYSQL_USER="root"
MYSQL_PASSWORD="password"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           数据库重置脚本 - 校园选课系统微服务                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# 确认操作
if [ "$1" != "-y" ] && [ "$1" != "--yes" ]; then
    print_warning "此操作将清空并重置以下数据库："
    echo "  • catalog_db (课程数据)"
    echo "  • enrollment_db (学生和选课数据)"
    echo ""
    read -p "确定要继续吗? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "操作已取消"
        exit 0
    fi
fi

echo ""

# 检查容器是否运行
print_info "检查数据库容器状态..."

if ! docker ps --format '{{.Names}}' | grep -q "^${CATALOG_CONTAINER}$"; then
    print_error "容器 $CATALOG_CONTAINER 未运行"
    exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "^${ENROLLMENT_CONTAINER}$"; then
    print_error "容器 $ENROLLMENT_CONTAINER 未运行"
    exit 1
fi

print_success "数据库容器正在运行"

# 检查 SQL 文件
print_info "检查 SQL 文件..."

if [ ! -f "$SQL_DIR/init-catalog.sql" ]; then
    print_error "找不到文件: $SQL_DIR/init-catalog.sql"
    exit 1
fi

if [ ! -f "$SQL_DIR/init-enrollment.sql" ]; then
    print_error "找不到文件: $SQL_DIR/init-enrollment.sql"
    exit 1
fi

print_success "SQL 文件已就绪"

# 重置 catalog_db
echo ""
print_info "重置 catalog_db..."

# 删除并重建数据库
docker exec -i "$CATALOG_CONTAINER" mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "DROP DATABASE IF EXISTS catalog_db;" 2>/dev/null

# 执行初始化脚本
if docker exec -i "$CATALOG_CONTAINER" mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" < "$SQL_DIR/init-catalog.sql" 2>/dev/null; then
    print_success "catalog_db 重置成功"
    
    # 显示数据统计
    COURSE_COUNT=$(docker exec -i "$CATALOG_CONTAINER" mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -N -e "SELECT COUNT(*) FROM catalog_db.courses;" 2>/dev/null)
    print_info "已导入 $COURSE_COUNT 门课程"
else
    print_error "catalog_db 重置失败"
    exit 1
fi

# 重置 enrollment_db
echo ""
print_info "重置 enrollment_db..."

# 删除并重建数据库
docker exec -i "$ENROLLMENT_CONTAINER" mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "DROP DATABASE IF EXISTS enrollment_db;" 2>/dev/null

# 执行初始化脚本
if docker exec -i "$ENROLLMENT_CONTAINER" mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" < "$SQL_DIR/init-enrollment.sql" 2>/dev/null; then
    print_success "enrollment_db 重置成功"
    
    # 显示数据统计
    STUDENT_COUNT=$(docker exec -i "$ENROLLMENT_CONTAINER" mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -N -e "SELECT COUNT(*) FROM enrollment_db.students;" 2>/dev/null)
    ENROLLMENT_COUNT=$(docker exec -i "$ENROLLMENT_CONTAINER" mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -N -e "SELECT COUNT(*) FROM enrollment_db.enrollments;" 2>/dev/null)
    print_info "已导入 $STUDENT_COUNT 名学生, $ENROLLMENT_COUNT 条选课记录"
else
    print_error "enrollment_db 重置失败"
    exit 1
fi

# 完成
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    数据库重置完成                            ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  catalog_db:                                                 ║"
echo "║    • 课程: CS101 (数据结构与算法)                            ║"
echo "║    • 课程: CS102 (操作系统原理)                              ║"
echo "║    • 课程: CS201 (计算机网络)                                ║"
echo "║                                                              ║"
echo "║  enrollment_db:                                              ║"
echo "║    • 学生: S2024001 (张三), S2024002 (李四)                  ║"
echo "║    • 选课: 2条记录                                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

print_info "提示: 运行 ./scripts/test-services.sh 验证数据"
