package com.zjgsu.szw.coursecloud.enrollment.service;

import com.zjgsu.szw.coursecloud.enrollment.client.CatalogClient;
import com.zjgsu.szw.coursecloud.enrollment.client.dto.ApiResponseWrapper;
import com.zjgsu.szw.coursecloud.enrollment.client.dto.CourseDTO;
import com.zjgsu.szw.coursecloud.enrollment.exception.CatalogServiceUnavailableException;
import com.zjgsu.szw.coursecloud.enrollment.exception.CourseNotAvailableException;
import com.zjgsu.szw.coursecloud.enrollment.exception.CourseNotFoundException;
import com.zjgsu.szw.coursecloud.enrollment.exception.ResourceNotFoundException;
import com.zjgsu.szw.coursecloud.enrollment.model.Enrollment;
import com.zjgsu.szw.coursecloud.enrollment.model.EnrollmentStatus;
import com.zjgsu.szw.coursecloud.enrollment.repository.EnrollmentRepository;
import com.zjgsu.szw.coursecloud.enrollment.repository.StudentRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * 选课业务逻辑层
 * 使用OpenFeign + Spring Cloud LoadBalancer实现服务间通信与负载均衡
 */
@Service
public class EnrollmentService {

    private static final Logger logger = LoggerFactory.getLogger(EnrollmentService.class);

    private final EnrollmentRepository enrollmentRepository;
    private final StudentRepository studentRepository;
    private final CatalogClient catalogClient;

    public EnrollmentService(EnrollmentRepository enrollmentRepository,
                             StudentRepository studentRepository,
                             CatalogClient catalogClient) {
        this.enrollmentRepository = enrollmentRepository;
        this.studentRepository = studentRepository;
        this.catalogClient = catalogClient;
    }

    /**
     * 查询所有选课记录
     */
    public List<Enrollment> findAll() {
        return enrollmentRepository.findAll();
    }

    /**
     * 根据ID查询选课记录
     */
    public Optional<Enrollment> findById(String id) {
        return enrollmentRepository.findById(id);
    }

    /**
     * 根据课程ID查询选课记录
     */
    public List<Enrollment> findByCourseId(String courseId) {
        return enrollmentRepository.findByCourseId(courseId);
    }

    /**
     * 根据学生ID查询选课记录
     */
    public List<Enrollment> findByStudentId(String studentId) {
        return enrollmentRepository.findByStudentId(studentId);
    }

    /**
     * 学生选课
     * 使用OpenFeign调用catalog-service进行课程验证
     */
    @Transactional
    public Enrollment createEnrollment(Enrollment enrollment) {
        String courseId = enrollment.getCourseId();
        String studentId = enrollment.getStudentId();

        logger.info("开始选课流程 - 学生: {}, 课程: {}", studentId, courseId);

        // 1. 验证学生是否存在
        if (!studentRepository.existsByStudentId(studentId)) {
            logger.warn("学生不存在: {}", studentId);
            throw new ResourceNotFoundException("Student not found with studentId: " + studentId);
        }

        // 2. 使用Feign Client调用catalog-service获取课程信息
        CourseDTO course = getCourseFromCatalogService(courseId);
        logger.info("成功获取课程信息: {} - {}", course.getCode(), course.getTitle());

        // 3. 检查课程是否可选（有剩余容量）
        if (!course.isAvailable()) {
            logger.warn("课程已满: {} (容量: {}, 已选: {})", courseId, course.getCapacity(), course.getEnrolled());
            throw new CourseNotAvailableException(courseId, course.getCapacity(), course.getEnrolled());
        }

        // 4. 检查是否重复选课
        if (enrollmentRepository.existsByCourseIdAndStudentId(courseId, studentId)) {
            logger.warn("重复选课: 学生 {} 已选择课程 {}", studentId, courseId);
            throw new IllegalArgumentException("Already enrolled in this course");
        }

        // 5. 创建选课记录
        enrollment.setId(UUID.randomUUID().toString());
        enrollment.setStatus(EnrollmentStatus.ACTIVE);
        enrollment.setEnrolledAt(LocalDateTime.now());
        Enrollment saved = enrollmentRepository.save(enrollment);
        logger.info("选课记录已创建: {}", saved.getId());

        // 6. 使用Feign Client更新课程的已选人数
        incrementCourseEnrolledCount(courseId);

        logger.info("选课成功 - 学生: {}, 课程: {}, 选课记录: {}", studentId, courseId, saved.getId());
        return saved;
    }

    /**
     * 学生退课
     */
    @Transactional
    public void deleteEnrollment(String id) {
        logger.info("开始退课流程 - 选课记录ID: {}", id);

        Enrollment enrollment = enrollmentRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Enrollment not found with id: " + id));

        String courseId = enrollment.getCourseId();

        // 删除选课记录
        enrollmentRepository.deleteById(id);
        logger.info("选课记录已删除: {}", id);

        // 使用Feign Client更新课程选课人数
        decrementCourseEnrolledCount(courseId);

        logger.info("退课成功 - 课程: {}", courseId);
    }

    /**
     * 从catalog-service获取课程信息
     * 使用OpenFeign声明式调用，通过Spring Cloud LoadBalancer实现负载均衡
     */
    private CourseDTO getCourseFromCatalogService(String courseId) {
        logger.debug("调用catalog-service获取课程信息: {}", courseId);
        
        try {
            ApiResponseWrapper<CourseDTO> response = catalogClient.getCourseById(courseId);
            
            // 检查服务是否可用
            if (response.getCode() == 503) {
                logger.error("Catalog服务不可用: {}", response.getMessage());
                throw new CatalogServiceUnavailableException(response.getMessage());
            }
            
            // 检查课程是否存在
            if (response.getCode() == 404 || response.getData() == null) {
                logger.warn("课程不存在: {}", courseId);
                throw new CourseNotFoundException(courseId);
            }
            
            // 检查响应是否成功
            if (!response.isSuccess()) {
                logger.error("获取课程信息失败: {}", response.getMessage());
                throw new RuntimeException("Failed to get course from catalog service: " + response.getMessage());
            }
            
            logger.debug("成功从catalog-service获取课程: {}", response.getData());
            return response.getData();
            
        } catch (CourseNotFoundException | CatalogServiceUnavailableException e) {
            throw e;
        } catch (Exception e) {
            logger.error("调用catalog-service异常: {}", e.getMessage(), e);
            throw new CatalogServiceUnavailableException("调用课程服务失败: " + e.getMessage(), e);
        }
    }

    /**
     * 增加课程选课人数
     */
    private void incrementCourseEnrolledCount(String courseId) {
        logger.debug("调用catalog-service增加选课人数: {}", courseId);
        try {
            ApiResponseWrapper<Void> response = catalogClient.incrementEnrolled(courseId);
            if (response.isSuccess()) {
                logger.info("成功更新课程选课人数(+1): {}", courseId);
            } else {
                logger.warn("更新课程选课人数失败: {} - {}", courseId, response.getMessage());
            }
        } catch (Exception e) {
            // 记录日志但不影响主流程（选课记录已创建）
            logger.error("更新课程选课人数异常: {} - {}", courseId, e.getMessage());
        }
    }

    /**
     * 减少课程选课人数
     */
    private void decrementCourseEnrolledCount(String courseId) {
        logger.debug("调用catalog-service减少选课人数: {}", courseId);
        try {
            ApiResponseWrapper<Void> response = catalogClient.decrementEnrolled(courseId);
            if (response.isSuccess()) {
                logger.info("成功更新课程选课人数(-1): {}", courseId);
            } else {
                logger.warn("更新课程选课人数失败: {} - {}", courseId, response.getMessage());
            }
        } catch (Exception e) {
            // 记录日志但不影响主流程（退课记录已删除）
            logger.error("更新课程选课人数异常: {} - {}", courseId, e.getMessage());
        }
    }
}
