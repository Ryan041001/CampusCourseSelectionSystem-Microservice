package com.zjgsu.szw.enrollment.service;

import com.zjgsu.szw.enrollment.exception.ResourceNotFoundException;
import com.zjgsu.szw.enrollment.model.Enrollment;
import com.zjgsu.szw.enrollment.model.EnrollmentStatus;
import com.zjgsu.szw.enrollment.model.Student;
import com.zjgsu.szw.enrollment.repository.EnrollmentRepository;
import com.zjgsu.szw.enrollment.repository.StudentRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * 选课业务逻辑层
 */
@Service
public class EnrollmentService {
    private final EnrollmentRepository enrollmentRepository;
    private final StudentRepository studentRepository;
    private final RestTemplate restTemplate;

    // Use service name instead of hardcoded URL for Nacos service discovery
    private final String catalogServiceUrl = "http://catalog-service";

    public EnrollmentService(EnrollmentRepository enrollmentRepository,
                             StudentRepository studentRepository,
                             RestTemplate restTemplate) {
        this.enrollmentRepository = enrollmentRepository;
        this.studentRepository = studentRepository;
        this.restTemplate = restTemplate;
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
     */
    @Transactional
    public Enrollment createEnrollment(Enrollment enrollment) {
        String courseId = enrollment.getCourseId();
        String studentId = enrollment.getStudentId();

        // 1. 验证学生是否存在
        if (!studentRepository.existsByStudentId(studentId)) {
            throw new ResourceNotFoundException("Student not found with studentId: " + studentId);
        }

        // 2. 调用课程目录服务验证课程是否存在
        String url = catalogServiceUrl + "/api/courses/" + courseId;
        Map<String, Object> courseResponse;
        try {
            courseResponse = restTemplate.getForObject(url, Map.class);
        } catch (HttpClientErrorException.NotFound e) {
            throw new ResourceNotFoundException("Course", courseId);
        }

        // 3. 从响应中提取课程信息
        if (courseResponse == null || !courseResponse.containsKey("data")) {
             throw new RuntimeException("Invalid response from catalog service");
        }
        Map<String, Object> courseData = (Map<String, Object>) courseResponse.get("data");
        Integer capacity = (Integer) courseData.get("capacity");
        Integer enrolled = (Integer) courseData.get("enrolled");

        // 4. 检查课程容量
        if (enrolled >= capacity) {
            throw new IllegalArgumentException("Course is full");
        }

        // 5. 检查重复选课
        if (enrollmentRepository.existsByCourseIdAndStudentId(courseId, studentId)) {
            throw new IllegalArgumentException("Already enrolled in this course");
        }

        // 6. 创建选课记录
        enrollment.setId(UUID.randomUUID().toString());
        enrollment.setStatus(EnrollmentStatus.ACTIVE);
        enrollment.setEnrolledAt(LocalDateTime.now());
        Enrollment saved = enrollmentRepository.save(enrollment);

        // 7. 更新课程的已选人数 (调用 catalog-service)
        updateCourseEnrolledCount(courseId, enrolled + 1);
        return saved;
    }

    /**
     * 学生退课
     */
    @Transactional
    public void deleteEnrollment(String id) {
        Enrollment enrollment = enrollmentRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Enrollment not found with id: " + id));

        // 删除选课记录
        enrollmentRepository.deleteById(id);

        // 获取当前课程信息以更新人数
        String url = catalogServiceUrl + "/api/courses/" + enrollment.getCourseId();
        try {
            Map<String, Object> courseResponse = restTemplate.getForObject(url, Map.class);
            if (courseResponse != null && courseResponse.containsKey("data")) {
                Map<String, Object> courseData = (Map<String, Object>) courseResponse.get("data");
                Integer enrolled = (Integer) courseData.get("enrolled");
                // 更新课程选课人数
                updateCourseEnrolledCount(enrollment.getCourseId(), enrolled - 1);
            }
        } catch (Exception e) {
             // 记录日志但不影响主流程
             System.err.println("Failed to update course enrolled count during deletion: " + e.getMessage());
        }
    }

    private void updateCourseEnrolledCount(String courseId, int newCount) {
        // Use dedicated increment/decrement endpoints to avoid validation issues in CourseService.updateCourse
        String incrementUrl = catalogServiceUrl + "/api/courses/" + courseId + "/increment";
        String decrementUrl = catalogServiceUrl + "/api/courses/" + courseId + "/decrement";
        
        try {
            // Fetch current enrolled count to decide which operation (increment/decrement) to call
            Map<String, Object> courseResponse = restTemplate.getForObject(catalogServiceUrl + "/api/courses/" + courseId, Map.class);
            if (courseResponse != null && courseResponse.containsKey("data")) {
                Map<String, Object> data = (Map<String, Object>) courseResponse.get("data");
                Integer enrolled = (Integer) data.get("enrolled");
                if (enrolled == null) enrolled = 0;
                if (newCount == enrolled + 1) {
                    restTemplate.postForEntity(incrementUrl, null, Void.class);
                } else if (newCount == enrolled - 1) {
                    restTemplate.postForEntity(decrementUrl, null, Void.class);
                } else {
                    // Fallback: if newCount differs by more than 1, attempt to set via update full course
                    data.put("enrolled", newCount);
                    restTemplate.put(catalogServiceUrl + "/api/courses/" + courseId, data);
                }
            }
        } catch (Exception e) {
            System.err.println("Failed to update course enrolled count: " + e.getMessage());
        }
    }
}
