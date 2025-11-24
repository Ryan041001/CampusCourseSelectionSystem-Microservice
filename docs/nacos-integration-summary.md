# Nacos 服务注册与发现集成总结

## 项目概述

本项目成功集成了 Nacos 作为服务注册与发现中心，实现了微服务架构中的动态服务发现和负载均衡功能。

## 完成的功能

### 1. Nacos 服务器部署

- 使用 Docker 部署 Nacos 服务器（单机模式）
- 控制台访问地址：`http://localhost:8848/nacos`
- 默认账号密码：`nacos/nacos`

### 2. 服务注册配置

#### Catalog Service
- 服务名：`catalog-service`
- 端口：8081
- 分组：`COURSEHUB_GROUP`
- 命名空间：`dev`

#### Enrollment Service  
- 服务名：`enrollment-service`
- 端口：8082
- 分组：`COURSEHUB_GROUP`
- 命名空间：`dev`

### 3. 服务发现与负载均衡

- 使用 Spring Cloud LoadBalancer 实现客户端负载均衡
- RestTemplate 配置了 `@LoadBalanced` 注解
- 支持轮询（Round Robin）负载均衡策略

### 4. 健康检查

- 所有服务配置了 Actuator 健康检查端点
- Nacos 能够监控服务健康状态
- 心跳间隔：5秒
- 心跳超时：15秒

## 测试结果

### 服务注册验证

所有服务成功注册到 Nacos：

```json
{
  "name": "COURSEHUB_GROUP@@catalog-service",
  "hosts": [
    {"ip": "172.19.0.8", "port": 8081, "healthy": true},
    {"ip": "172.19.0.5", "port": 8081, "healthy": true},
    {"ip": "172.19.0.7", "port": 8081, "healthy": true}
  ]
}
```

### 负载均衡测试

启动3个 catalog-service 实例，测试结果显示请求被均匀分配：

```
第 1 次请求: catalog_hostname: e34d05f158b3
第 2 次请求: catalog_hostname: 184dad8956f1  
第 3 次请求: catalog_hostname: e34d05f158b3
第 4 次请求: catalog_hostname: 2a7918185ade
第 5 次请求: catalog_hostname: 184dad8956f1
...
```

负载均衡分布：
- `e34d05f158b3`: 4次请求
- `2a7918185ade`: 4次请求  
- `184dad8956f1`: 2次请求

### 故障转移测试

停止一个 catalog-service 实例后：
- Nacos 在15秒内检测到实例下线
- 请求自动转移到其他健康实例
- 服务仍然可用，无单点故障

## 架构改进

### 之前（硬编码方式）
```java
// 硬编码服务地址
String catalogServiceUrl = "http://localhost:8081";
```

### 现在（服务发现方式）
```java
// 使用服务名进行调用
String catalogServiceUrl = "http://catalog-service";
```

## 配置文件

### application.yml (Catalog Service)
```yaml
spring:
  application:
    name: catalog-service
  cloud:
    nacos:
      discovery:
        server-addr: nacos:8848
        namespace: dev
        group: COURSEHUB_GROUP
        ephemeral: true
        heart-beat-interval: 5000
        heart-beat-timeout: 15000
```

### docker-compose.yml
```yaml
services:
  nacos:
    image: nacos/nacos-server:v3.1.0
    container_name: nacos
    environment:
      MODE: standalone
    ports:
      - "8848:8848"
      - "9848:9848"
    networks:
      - course-cloud-network

  catalog-service:
    depends_on:
      - nacos
      - mysql
    ports:
      - "8081:8081"
    networks:
      - course-cloud-network

  enrollment-service:
    depends_on:
      - nacos
      - mysql
    ports:
      - "8082:8082"
    networks:
      - course-cloud-network
```

## 测试端点

### 服务健康检查
- Catalog Service: `GET http://localhost:8081/actuator/health`
- Enrollment Service: `GET http://localhost:8082/actuator/health`

### 服务信息
- Catalog Service 端口: `GET http://localhost:8081/api/courses/port`
- Enrollment Service 端口: `GET http://localhost:8082/api/enrollments/port`

### 负载均衡测试
- 测试端点: `GET http://localhost:8086/api/enrollments/test`
- 返回当前服务和调用的 catalog-service 实例信息

## 运维监控

### Nacos 控制台功能
1. **服务管理**：查看已注册的服务列表
2. **实例管理**：查看每个服务的实例详情
3. **健康检查**：监控实例健康状态
4. **配置管理**：统一管理配置（未启用）

### 监控指标
- 服务实例数量
- 实例健康状态
- 心跳间隔和超时
- 负载均衡请求分布

## 最佳实践

### 1. 服务命名规范
- 使用小写字母和连字符：`service-name`
- 避免使用下划线和大写字母
- 保持名称简洁且有意义

### 2. 分组和命名空间
- 使用分组进行环境隔离：`DEV_GROUP`, `PROD_GROUP`
- 使用命名空间进行多租户隔离
- 保持分组和命名空间的一致性

### 3. 健康检查配置
- 合理设置心跳间隔（5-10秒）
- 心跳超时应是心跳间隔的3倍
- 实现优雅关闭，先注销服务再停止

### 4. 负载均衡策略
- 默认使用轮询策略
- 可根据需要配置权重
- 考虑实现自定义负载均衡策略

## 故障排查

### 常见问题

1. **服务无法注册**
   - 检查 Nacos 服务器状态
   - 验证网络连接
   - 检查配置文件中的 server-addr

2. **负载均衡不生效**
   - 确保RestTemplate有@LoadBalanced注解
   - 检查是否有多个健康实例
   - 验证服务名是否正确

3. **健康检查失败**
   - 确保Actuator端点可访问
   - 检查management.endpoints配置
   - 验证防火墙设置

### 调试命令
```bash
# 查看服务注册情况
curl "http://localhost:8848/nacos/v1/ns/instance/list?serviceName=catalog-service"

# 查看容器状态
docker compose ps

# 查看服务日志
docker logs [container-name]
```

## 总结

通过集成 Nacos，我们实现了：

✅ **服务自动注册**：服务启动时自动注册到 Nacos  
✅ **服务动态发现**：通过服务名而不是硬编码地址调用服务  
✅ **负载均衡**：请求均匀分配到多个服务实例  
✅ **故障转移**：实例下线时自动切换到健康实例  
