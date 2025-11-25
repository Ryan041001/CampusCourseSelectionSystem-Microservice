package com.zjgsu.szw.coursecloud.enrollment.client;

import com.zjgsu.szw.coursecloud.enrollment.client.dto.ApiResponseWrapper;
import com.zjgsu.szw.coursecloud.enrollment.client.dto.CourseDTO;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;

import java.util.List;
import java.util.Map;

/**
 * Catalog Service Feign Client
 * 使用OpenFeign声明式调用catalog-service
 * 
 * @FeignClient(name = "catalog-service") 
 *   - name: 对应Nacos注册的服务名
 *   - 会自动通过Nacos进行服务发现
 *   - 配合Spring Cloud LoadBalancer实现客户端负载均衡
 */
@FeignClient(name = "catalog-service", fallbackFactory = CatalogClientFallbackFactory.class)
public interface CatalogClient {

    /**
     * 根据课程ID获取课程信息
     * GET /api/courses/{id}
     */
    @GetMapping("/api/courses/{courseId}")
    ApiResponseWrapper<CourseDTO> getCourseById(@PathVariable("courseId") String courseId);

    /**
     * 获取所有课程列表
     * GET /api/courses
     */
    @GetMapping("/api/courses")
    ApiResponseWrapper<List<CourseDTO>> getAllCourses();

    /**
     * 根据课程代码获取课程信息
     * GET /api/courses/code/{code}
     */
    @GetMapping("/api/courses/code/{code}")
    ApiResponseWrapper<CourseDTO> getCourseByCode(@PathVariable("code") String code);

    /**
     * 增加课程选课人数
     * POST /api/courses/{id}/increment
     */
    @PostMapping("/api/courses/{courseId}/increment")
    ApiResponseWrapper<Void> incrementEnrolled(@PathVariable("courseId") String courseId);

    /**
     * 减少课程选课人数
     * POST /api/courses/{id}/decrement
     */
    @PostMapping("/api/courses/{courseId}/decrement")
    ApiResponseWrapper<Void> decrementEnrolled(@PathVariable("courseId") String courseId);

    /**
     * 获取服务端口信息（用于测试负载均衡）
     * GET /api/courses/port
     */
    @GetMapping("/api/courses/port")
    ApiResponseWrapper<Map<String, String>> getServicePort();
}
