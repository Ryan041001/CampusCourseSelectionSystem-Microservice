# 校园选课系统 - 微服务架构

## 项目概述

本项目是一个基于微服务架构的校园选课系统，采用Spring Boot、Docker、Nacos等技术栈实现服务注册与发现、负载均衡、容器化部署等功能。

## 目录结构

```
CampusCourseSelectionSystem-Microservice/
├── catalog-service/          # 课程目录服务
├── enrollment-service/       # 选课服务
├── scripts/                  # 工具脚本目录
│   ├── test-all-apis.sh     # 自动化测试脚本
│   ├── cleanup-test-data.sh # 测试数据清理脚本
│   ├── nacos-test.sh        # Nacos集成测试脚本
│   └── add_logging.py       # 日志增强工具
├── docs/                     # 文档目录
│   ├── 功能测试文档.md       # 功能测试文档
│   ├── hw06.md              # 作业6需求文档
│   └── hw07.md              # 作业7需求文档
├── mysql/                    # 数据库初始化脚本
├── docker-compose.yml        # Docker Compose 配置
└── README.md                 # 项目说明
```

## 快速开始

### 环境要求

- Docker & Docker Compose
- Java 17+
- Maven 3.6+

### 启动服务

```bash
# 启动所有服务（包括Nacos）
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f
```

### 运行测试

```bash
# 运行Nacos集成测试
cd scripts
./nacos-test.sh

# 清理测试数据并运行所有API测试
./cleanup-test-data.sh && ./test-all-apis.sh
```

## Nacos 服务注册与发现

### 部署配置

本项目已集成Nacos作为服务注册与发现中心：

- **Nacos控制台**: http://localhost:8848/nacos
- **默认账号**: nacos / nacos

### 服务配置

所有微服务都配置了Nacos客户端，自动注册到Nacos：

```yaml
spring:
  application:
    name: catalog-service  # 或 enrollment-service
  cloud:
    nacos:
      discovery:
        server-addr: nacos:8848
        group: COURSEHUB_GROUP
        ephemeral: true
        heart-beat-interval: 5000
        heart-beat-timeout: 15000
```

### 负载均衡

服务间调用通过`@LoadBalanced` RestTemplate实现客户端负载均衡：

```java
@Bean
@LoadBalanced
public RestTemplate restTemplate() {
    return new RestTemplate();
}
```

### 健康检查

所有服务都配置了Actuator健康检查端点：
- **健康检查地址**: `/actuator/health`
- **Nacos监控**: Nacos通过此端点监控服务健康状态

### 测试验证

#### 1. 服务注册验证

访问Nacos控制台查看服务注册情况：
1. 打开 http://localhost:8848/nacos
2. 登录账号: nacos / nacos
3. 进入"服务管理" -> "服务列表"
4. 查看注册的服务实例

#### 2. 负载均衡测试

```bash
# 测试端点（返回端口号验证负载均衡）
curl http://localhost:8081/api/courses/port
curl http://localhost:8082/api/enrollments/port

# 多次请求观察端口号变化（多实例部署时）
for i in {1..10}; do
  curl http://localhost:8082/api/enrollments/test
done
```

#### 3. 故障转移测试

```bash
# 停止一个服务实例
docker stop catalog-service

# 测试服务是否仍然可用
curl http://localhost:8082/api/enrollments/test

# 重新启动服务
docker start catalog-service
```

## 服务说明

### 核心服务

| 服务名 | 端口 | 描述 | 健康检查 |
|--------|------|------|----------|
| Catalog Service | 8081 | 课程管理服务 | http://localhost:8081/actuator/health |
| Enrollment Service | 8082 | 学生选课服务 | http://localhost:8082/actuator/health |

### 基础设施

| 服务 | 端口 | 描述 | 访问地址 |
|------|------|------|----------|
| Nacos | 8848 | 服务注册与发现 | http://localhost:8848/nacos |
| MySQL Catalog | 3307 | 课程数据库 | - |
| MySQL Enrollment | 3308 | 选课数据库 | - |

### API端点

#### Catalog Service
- `GET /api/courses` - 查询所有课程
- `GET /api/courses/{id}` - 查询指定课程
- `POST /api/courses` - 创建课程
- `PUT /api/courses/{id}` - 更新课程
- `DELETE /api/courses/{id}` - 删除课程
- `GET /api/courses/port` - 获取服务端口（测试用）

#### Enrollment Service
- `GET /api/enrollments` - 查询所有选课记录
- `GET /api/enrollments/{id}` - 查询指定选课记录
- `POST /api/enrollments` - 学生选课
- `DELETE /api/enrollments/{id}` - 学生退课
- `GET /api/enrollments/port` - 获取服务端口（测试用）
- `GET /api/enrollments/test` - 服务发现测试（测试用）

## 开发指南

### 项目结构规范

所有代码包名遵循规范：`com.zjgsu.szw.coursecloud.*`

### 服务间调用

服务间调用使用服务名而非硬编码IP地址：

```java
// 使用服务名调用
private final String catalogServiceUrl = "http://catalog-service";

// 通过RestTemplate调用
Course course = restTemplate.getForObject(catalogServiceUrl + "/api/courses/" + courseId, Course.class);
```

### 多实例部署

启动多个服务实例进行负载均衡测试：

```bash
# 启动不同端口的catalog-service实例
docker run -d --name catalog-service-8081 -p 8081:8081 catalog-service
docker run -d --name catalog-service-8084 -p 8084:8081 catalog-service
docker run -d --name catalog-service-8085 -p 8085:8081 catalog-service
```

## 查看文档

- **功能测试文档**: `docs/功能测试文档.md`
- **项目需求**: `docs/hw06.md`, `docs/hw07.md`
- **Nacos集成**: `docs/hw07.md`

## 故障排除

### 常见问题

1. **服务无法注册到Nacos**
   - 检查Nacos是否启动：`docker logs nacos`
   - 检查网络连接：确保服务在同一个Docker网络中
   - 检查配置：确认`server-addr`配置正确

2. **服务间调用失败**
   - 确认目标服务已注册到Nacos
   - 检查服务名是否正确（大小写敏感）
   - 验证RestTemplate是否添加了`@LoadBalanced`注解

3. **健康检查失败**
   - 检查Actuator端点是否暴露：`/actuator/health`
   - 确认服务完全启动后再进行健康检查
   - 增加启动等待时间

### 日志查看

```bash
# 查看所有服务日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f catalog-service
docker-compose logs -f enrollment-service
docker-compose logs -f nacos
```
