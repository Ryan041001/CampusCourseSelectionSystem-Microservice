package com.zjgsu.szw.enrollment.controller;

import com.zjgsu.szw.enrollment.common.ApiResponse;
import com.zjgsu.szw.enrollment.model.Enrollment;
import com.zjgsu.szw.enrollment.service.EnrollmentService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 选课管理Controller
 * 演示RESTful API的CRUD操作和资源嵌套
 */
@RestController
@RequestMapping("/api/enrollments")
public class EnrollmentController {

    private final EnrollmentService enrollmentService;

    public EnrollmentController(EnrollmentService enrollmentService) {
        this.enrollmentService = enrollmentService;
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
     * 根据ID查询选课记录
     * GET /api/enrollments/{id}
     */
    @GetMapping("/{id}")
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
