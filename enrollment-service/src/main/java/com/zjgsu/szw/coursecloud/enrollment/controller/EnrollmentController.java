package com.zjgsu.szw.coursecloud.enrollment.controller;

import com.zjgsu.szw.coursecloud.enrollment.client.CatalogClient;
import com.zjgsu.szw.coursecloud.enrollment.client.dto.ApiResponseWrapper;
import com.zjgsu.szw.coursecloud.enrollment.common.ApiResponse;
import com.zjgsu.szw.coursecloud.enrollment.model.Enrollment;
import com.zjgsu.szw.coursecloud.enrollment.service.EnrollmentService;
import org.springframework.beans.factory.annotation.Value;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 选课管理Controller
 * 演示RESTful API的CRUD操作和资源嵌套
 */
@RestController
@RequestMapping("/api/enrollments")
public class EnrollmentController {

    private final EnrollmentService enrollmentService;
    private final CatalogClient catalogClient;

    @Value("${server.port}")
    private String serverPort;

    public EnrollmentController(EnrollmentService enrollmentService, CatalogClient catalogClient) {
        this.enrollmentService = enrollmentService;
        this.catalogClient = catalogClient;
    }

    /**
     * 查询所有选课记录
     * GET /api/enrollments
     */
    @GetMapping
    public ResponseEntity<ApiResponse<List<Enrollment>>> getAllEnrollments() {
        List<Enrollment> enrollments = enrollmentService.findAll();
        return ResponseEntity.ok(ApiResponse.success(enrollments));
    }

    /**
     * 测试端点：返回服务端口号
     * GET /api/enrollments/port
     */
    @GetMapping("/port")
    public ResponseEntity<ApiResponse<Map<String, String>>> getPort() {
        Map<String, String> response = new HashMap<>();
        response.put("service", "enrollment-service");
        response.put("port", serverPort);
        response.put("timestamp", String.valueOf(System.currentTimeMillis()));
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * 测试端点：测试服务发现和负载均衡（使用OpenFeign）
     * GET /api/enrollments/test
     */
    @GetMapping("/test")
    public ResponseEntity<ApiResponse<Map<String, Object>>> testServiceDiscovery() {
        Map<String, Object> response = new HashMap<>();
        response.put("service", "enrollment-service");
        response.put("port", serverPort);
        response.put("timestamp", String.valueOf(System.currentTimeMillis()));
        response.put("message", "OpenFeign + LoadBalancer test");
        
        try {
            // 使用OpenFeign调用catalog-service的端口端点来测试服务发现和负载均衡
            ApiResponseWrapper<Map<String, String>> catalogResponse = catalogClient.getServicePort();
            if (catalogResponse.isSuccess() && catalogResponse.getData() != null) {
                Map<String, String> catalogData = catalogResponse.getData();
                response.put("catalog_port", catalogData.get("port"));
                response.put("catalog_hostname", catalogData.get("hostname"));
                response.put("feign_call_status", "SUCCESS");
            } else {
                response.put("feign_call_status", "FAILED: " + catalogResponse.getMessage());
            }
        } catch (Exception e) {
            response.put("catalog_port", "Error");
            response.put("feign_call_status", "ERROR: " + e.getMessage());
        }
        
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * 测试端点：多次调用测试负载均衡效果
     * GET /api/enrollments/test/loadbalancer?count=5
     */
    @GetMapping("/test/loadbalancer")
    public ResponseEntity<ApiResponse<Map<String, Object>>> testLoadBalancer(
            @RequestParam(value = "count", defaultValue = "5") int count) {
        Map<String, Object> response = new HashMap<>();
        response.put("service", "enrollment-service");
        response.put("port", serverPort);
        response.put("test_description", "多次调用catalog-service测试负载均衡");
        response.put("call_count", count);
        
        Map<String, Integer> portDistribution = new HashMap<>();
        List<Map<String, String>> callResults = new java.util.ArrayList<>();
        
        for (int i = 0; i < count; i++) {
            Map<String, String> callResult = new HashMap<>();
            callResult.put("call_number", String.valueOf(i + 1));
            
            try {
                ApiResponseWrapper<Map<String, String>> catalogResponse = catalogClient.getServicePort();
                if (catalogResponse.isSuccess() && catalogResponse.getData() != null) {
                    String port = catalogResponse.getData().get("port");
                    String hostname = catalogResponse.getData().get("hostname");
                    callResult.put("catalog_port", port);
                    callResult.put("catalog_hostname", hostname);
                    callResult.put("status", "SUCCESS");
                    
                    // 统计端口分布
                    portDistribution.merge(port, 1, Integer::sum);
                } else {
                    callResult.put("status", "FAILED: " + catalogResponse.getMessage());
                }
            } catch (Exception e) {
                callResult.put("status", "ERROR: " + e.getMessage());
            }
            
            callResults.add(callResult);
        }
        
        response.put("call_results", callResults);
        response.put("port_distribution", portDistribution);
        response.put("load_balance_analysis", portDistribution.size() > 1 
                ? "负载均衡生效！请求被分发到 " + portDistribution.size() + " 个不同的实例" 
                : "当前只有1个catalog-service实例运行");
        
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * 根据ID查询选课记录
     * GET /api/enrollments/{id}
     */
    @GetMapping("/{id:[a-fA-F0-9\\-]+}")
    public ResponseEntity<ApiResponse<Enrollment>> getEnrollmentById(@PathVariable String id) {
        return enrollmentService.findById(id)
                .map(enrollment -> ResponseEntity.ok(ApiResponse.success(enrollment)))
                .orElse(ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(ApiResponse.notFound("Enrollment not found with id: " + id)));
    }

    /**
     * 按课程查询选课记录
     * GET /api/enrollments/course/{courseId}
     */
    @GetMapping("/course/{courseId}")
    public ResponseEntity<ApiResponse<List<Enrollment>>> getEnrollmentsByCourseId(@PathVariable String courseId) {
        List<Enrollment> enrollments = enrollmentService.findByCourseId(courseId);
        return ResponseEntity.ok(ApiResponse.success(enrollments));
    }

    /**
     * 按学生查询选课记录
     * GET /api/enrollments/student/{studentId}
     */
    @GetMapping("/student/{studentId}")
    public ResponseEntity<ApiResponse<List<Enrollment>>> getEnrollmentsByStudentId(@PathVariable String studentId) {
        List<Enrollment> enrollments = enrollmentService.findByStudentId(studentId);
        return ResponseEntity.ok(ApiResponse.success(enrollments));
    }

    /**
     * 学生选课
     * POST /api/enrollments
     */
    @PostMapping
    public ResponseEntity<ApiResponse<Enrollment>> createEnrollment(@RequestBody Enrollment enrollment) {
        Enrollment created = enrollmentService.createEnrollment(enrollment);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(created));
    }

    /**
     * 学生退课
     * DELETE /api/enrollments/{id}
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteEnrollment(@PathVariable String id) {
        enrollmentService.deleteEnrollment(id);
        return ResponseEntity.ok(ApiResponse.success("Enrollment deleted successfully"));
    }
}
