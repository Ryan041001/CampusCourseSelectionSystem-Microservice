package com.zjgsu.szw.coursecloud.enrollment.controller;

import com.zjgsu.szw.coursecloud.enrollment.common.ApiResponse;
import com.zjgsu.szw.coursecloud.enrollment.model.Enrollment;
import com.zjgsu.szw.coursecloud.enrollment.service.EnrollmentService;
import org.springframework.beans.factory.annotation.Value;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;

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
    private final RestTemplate restTemplate;

    @Value("${server.port}")
    private String serverPort;

    public EnrollmentController(EnrollmentService enrollmentService, RestTemplate restTemplate) {
        this.enrollmentService = enrollmentService;
        this.restTemplate = restTemplate;
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
     * 测试端点：测试服务发现和负载均衡
     * GET /api/enrollments/test
     */
    @GetMapping("/test")
    public ResponseEntity<ApiResponse<Map<String, Object>>> testServiceDiscovery() {
        Map<String, Object> response = new HashMap<>();
        response.put("service", "enrollment-service");
        response.put("port", serverPort);
        response.put("timestamp", String.valueOf(System.currentTimeMillis()));
        response.put("message", "Service discovery and load balancing test");
        
        try {
            // 调用catalog-service的端口端点来测试服务发现
            String catalogServiceUrl = "http://catalog-service/api/courses/port";
            Map<String, Object> catalogResponse = restTemplate.getForObject(catalogServiceUrl, Map.class);
            if (catalogResponse != null && catalogResponse.containsKey("data")) {
                Map<String, Object> catalogData = (Map<String, Object>) catalogResponse.get("data");
                response.put("catalog_port", catalogData.get("port"));
                response.put("catalog_hostname", catalogData.get("hostname"));
            }
        } catch (Exception e) {
            response.put("catalog_port", "Error: " + e.getMessage());
        }
        
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
