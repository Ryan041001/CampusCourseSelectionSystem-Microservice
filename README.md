# 项目目录说明

## 目录结构

```
CampusCourseSelectionSystem-Microservice/
├── catalog-service/          # 课程目录服务
├── enrollment-service/       # 选课服务
├── scripts/                  # 工具脚本目录
│   ├── test-all-apis.sh     # 自动化测试脚本
│   ├── cleanup-test-data.sh # 测试数据清理脚本
│   └── add_logging.py       # 日志增强工具
├── docs/                     # 文档目录
│   ├── 功能测试文档.md       # 功能测试文档
│   ├── hw06.md              # 作业6需求文档
│   └── hw07.md              # 作业7需求文档
├── docker-compose.yml        # Docker Compose 配置
└── README.md                 # 项目说明
```

## 快速开始

### 运行测试

```bash
# 清理测试数据并运行所有测试
cd scripts
./cleanup-test-data.sh && ./test-all-apis.sh
```

### 查看文档

- **功能测试文档**: `docs/功能测试文档.md`
- **项目需求**: `docs/hw06.md`, `docs/hw07.md`

## 服务说明

- **Catalog Service**: 端口 8081 - 课程管理服务
- **Enrollment Service**: 端口 8082 - 学生选课服务
- **Nacos**: 端口 8848 - 服务注册与发现
- **MySQL**: 端口 3306 (catalog), 3307 (enrollment)
