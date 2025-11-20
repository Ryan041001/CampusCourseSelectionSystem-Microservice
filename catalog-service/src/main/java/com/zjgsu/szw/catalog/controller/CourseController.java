package com.zjgsu.szw.catalog.controller;

import com.zjgsu.szw.catalog.common.ApiResponse;
import com.zjgsu.szw.catalog.exception.ResourceNotFoundException;
import com.zjgsu.szw.catalog.model.Course;
import com.zjgsu.szw.catalog.service.CourseService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 课程管理Controller
 * 演示RESTful API的CRUD操作
 */
@RestController
@RequestMapping("/api/courses")
public class CourseController {

    private final CourseService courseService;

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
     * 根据ID查询课程
     * GET /api/courses/{id}
     */
    @GetMapping("/{id}")
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
