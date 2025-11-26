package com.zjgsu.szw.coursecloud.catalog.controller;

import com.zjgsu.szw.coursecloud.catalog.common.ApiResponse;
import com.zjgsu.szw.coursecloud.catalog.exception.ResourceNotFoundException;
import com.zjgsu.szw.coursecloud.catalog.model.Course;
import com.zjgsu.szw.coursecloud.catalog.service.CourseService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.net.InetAddress;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 课程管理Controller
 * 演示RESTful API的CRUD操作
 */
@RestController
@RequestMapping("/api/courses")
public class CourseController {

    private final CourseService courseService;

    @Value("${server.port}")
    private String serverPort;

    public CourseController(CourseService courseService) {
        this.courseService = courseService;
    }

    /**
     * 查询所有课程
     * GET /api/courses
     */
    @GetMapping
    public ResponseEntity<ApiResponse<List<Course>>> getAllCourses() {
        List<Course> courses = courseService.findAll();
        return ResponseEntity.ok(ApiResponse.success(courses));
    }

    /**
     * 根据课程代码查询课程
     * GET /api/courses/code/{code}
     */
    @GetMapping("/code/{code}")
    public ResponseEntity<ApiResponse<Course>> getCourseByCode(@PathVariable String code) {
        Course course = courseService.findByCode(code)
                .orElseThrow(() -> new ResourceNotFoundException("Course not found with code: " + code));
        return ResponseEntity.ok(ApiResponse.success(course));
    }

    /**
     * 测试端点：返回服务端口号和主机名
     * GET /api/courses/port
     */
    @GetMapping("/port")
    public ResponseEntity<ApiResponse<Map<String, String>>> getPort() {
        Map<String, String> response = new HashMap<>();
        response.put("service", "catalog-service");
        response.put("port", serverPort);
        try {
            String hostname = InetAddress.getLocalHost().getHostName();
            response.put("hostname", hostname);
        } catch (Exception e) {
            response.put("hostname", "unknown");
        }
        response.put("timestamp", String.valueOf(System.currentTimeMillis()));
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * 根据ID查询课程
     * GET /api/courses/{id}
     */
    @GetMapping("/{id:[a-zA-Z0-9\\-]+}")
    public ResponseEntity<ApiResponse<Course>> getCourseById(@PathVariable String id) {
        Course course = courseService.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Course not found with id: " + id));
        return ResponseEntity.ok(ApiResponse.success(course));
    }

    /**
     * 创建课程
     * POST /api/courses
     */
    @PostMapping
    public ResponseEntity<ApiResponse<Course>> createCourse(@RequestBody Course course) {
        Course created = courseService.createCourse(course);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(created));
    }

    /**
     * 更新课程
     * PUT /api/courses/{id}
     */
    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<Course>> updateCourse(
            @PathVariable String id,
            @RequestBody Course course) {
        Course updated = courseService.updateCourse(id, course);
        return ResponseEntity.ok(ApiResponse.success(updated));
    }

    /**
     * 删除课程
     * DELETE /api/courses/{id}
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteCourse(@PathVariable String id) {
        courseService.deleteCourse(id);
        return ResponseEntity.ok(ApiResponse.success(null));
    }

    /**
     * 增加课程选课人数
     * POST /api/courses/{id}/increment
     */
    @PostMapping("/{id}/increment")
    public ResponseEntity<ApiResponse<Void>> incrementEnrolled(@PathVariable String id) {
        courseService.incrementEnrolled(id);
        return ResponseEntity.ok(ApiResponse.success(null));
    }

    /**
     * 减少课程选课人数
     * POST /api/courses/{id}/decrement
     */
    @PostMapping("/{id}/decrement")
    public ResponseEntity<ApiResponse<Void>> decrementEnrolled(@PathVariable String id) {
        courseService.decrementEnrolled(id);
        return ResponseEntity.ok(ApiResponse.success(null));
    }
}
