# hw08 实现说明：服务间通信与负载均衡

**实现状态**：✅ 已完成

## 实现概述

本文档记录了 hw08 作业的实现细节，在 Nacos 注册中心基础上，使用 OpenFeign 实现声明式服务调用，使用 Spring Cloud LoadBalancer 实现客户端负载均衡。

---

## 1. OpenFeign 依赖 ✅

在 `enrollment-service/pom.xml` 中添加了：

```xml
<!-- OpenFeign for declarative service calls -->
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-openfeign</artifactId>
    <version>4.2.0</version>
</dependency>
```

---

## 2. 启用 Feign Client ✅

在 `EnrollmentServiceApplication.java` 中添加了 `@EnableFeignClients` 注解：

```java
@SpringBootApplication
@EnableDiscoveryClient
@LoadBalancerClients
@EnableFeignClients
public class EnrollmentServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(EnrollmentServiceApplication.class, args);
    }
}
```

---

## 3. Feign Client 接口 ✅

### CatalogClient.java

```java
@FeignClient(name = "catalog-service", fallbackFactory = CatalogClientFallbackFactory.class)
public interface CatalogClient {
    @GetMapping("/api/courses/{courseId}")
    ApiResponseWrapper<CourseDTO> getCourseById(@PathVariable("courseId") String courseId);

    @GetMapping("/api/courses")
    ApiResponseWrapper<List<CourseDTO>> getAllCourses();

    @PostMapping("/api/courses/{courseId}/increment")
    ApiResponseWrapper<Void> incrementEnrolled(@PathVariable("courseId") String courseId);

    @PostMapping("/api/courses/{courseId}/decrement")
    ApiResponseWrapper<Void> decrementEnrolled(@PathVariable("courseId") String courseId);

    @GetMapping("/api/courses/port")
    ApiResponseWrapper<Map<String, String>> getServicePort();
}
```

---

## 4. 降级处理 ✅

### CatalogClientFallbackFactory.java

当 catalog-service 不可用时，提供降级响应：

```java
@Component
public class CatalogClientFallbackFactory implements FallbackFactory<CatalogClient> {
    @Override
    public CatalogClient create(Throwable cause) {
        return new CatalogClient() {
            @Override
            public ApiResponseWrapper<CourseDTO> getCourseById(String courseId) {
                ApiResponseWrapper<CourseDTO> response = new ApiResponseWrapper<>();
                response.setCode(503);
                response.setMessage("Catalog service is unavailable: " + cause.getMessage());
                return response;
            }
            // ... 其他方法的降级处理
        };
    }
}
```

---

## 5. 负载均衡配置 ✅

在 `application.yml` 中配置 Spring Cloud LoadBalancer：

```yaml
spring:
  cloud:
    loadbalancer:
      ribbon:
        enabled: false  # 禁用Ribbon，使用Spring Cloud LoadBalancer
      cache:
        enabled: true
        ttl: 35s
        capacity: 256
```

---

## 6. Feign 配置 ✅

```yaml
feign:
  client:
    config:
      default:
        connectTimeout: 5000
        readTimeout: 5000
        loggerLevel: BASIC
      catalog-service:
        connectTimeout: 5000
        readTimeout: 10000
        loggerLevel: FULL
  compression:
    request:
      enabled: true
      mime-types: text/xml,application/xml,application/json
      min-request-size: 2048
    response:
      enabled: true

logging:
  level:
    com.zjgsu.szw.coursecloud.enrollment.client: DEBUG
```

---

## 7. DTO 类 ✅

### CourseDTO.java
用于接收 catalog-service 的课程响应。

### ApiResponseWrapper.java
用于解析 catalog-service 的统一响应格式。

### InstructorDTO.java / ScheduleSlotDTO.java
辅助 DTO 类。

---

## 8. 自定义异常 ✅

- **CourseNotFoundException**: 课程未找到
- **CourseNotAvailableException**: 课程已满或不可选
- **CatalogServiceUnavailableException**: Catalog 服务不可用

---

## 9. EnrollmentService 重构 ✅

使用 CatalogClient 替代 RestTemplate：

```java
@Service
public class EnrollmentService {
    private final CatalogClient catalogClient;

    @Transactional
    public Enrollment createEnrollment(Enrollment enrollment) {
        // 1. 验证学生是否存在
        // 2. 使用Feign Client调用catalog-service获取课程信息
        CourseDTO course = getCourseFromCatalogService(courseId);
        
        // 3. 检查课程是否可选
        if (!course.isAvailable()) {
            throw new CourseNotAvailableException(...);
        }
        
        // 4. 创建选课记录
        // 5. 使用Feign Client更新课程选课人数
        incrementCourseEnrolledCount(courseId);
        
        return saved;
    }
}
```

---

## 10. 测试端点 ✅

### 服务发现测试
```bash
curl http://localhost:8082/api/enrollments/test
```

### 负载均衡测试
```bash
curl "http://localhost:8082/api/enrollments/test/loadbalancer?count=10"
```

---

## 目录结构

```
enrollment-service/
  src/main/java/com/zjgsu/szw/coursecloud/enrollment/
    client/
      CatalogClient.java                  # Feign Client接口
      CatalogClientFallbackFactory.java   # 降级处理
      dto/
        ApiResponseWrapper.java           # API响应包装器
        CourseDTO.java                    # 课程DTO
        InstructorDTO.java                # 教师DTO
        ScheduleSlotDTO.java              # 时间段DTO
    exception/
      CourseNotFoundException.java        # 课程未找到异常
      CourseNotAvailableException.java    # 课程不可选异常
      CatalogServiceUnavailableException.java # 服务不可用异常
    service/
      EnrollmentService.java              # 使用Feign调用catalog-service
    controller/
      EnrollmentController.java           # 包含负载均衡测试端点
```

---

## 完成情况

- [x] OpenFeign 依赖与配置
- [x] Feign Client 接口定义
- [x] Spring Cloud LoadBalancer 配置
- [x] 降级处理 (FallbackFactory)
- [x] 自定义异常处理
- [x] EnrollmentService 重构
- [x] 测试端点
- [x] 文档
