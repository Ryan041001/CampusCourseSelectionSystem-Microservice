package com.zjgsu.szw.coursecloud.catalog.service;

import com.zjgsu.szw.coursecloud.catalog.exception.ResourceNotFoundException;
import com.zjgsu.szw.coursecloud.catalog.model.Course;
import com.zjgsu.szw.coursecloud.catalog.repository.CourseRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.regex.Pattern;

/**
 * 课程业务逻辑层
 */
@Service
public class CourseService {
    private final CourseRepository courseRepository;
    private static final Pattern EMAIL_PATTERN = Pattern.compile("^[A-Za-z0-9+_.-]+@(.+)$");

    public CourseService(CourseRepository courseRepository) {
        this.courseRepository = courseRepository;
    }

    /**
     * 查询所有课程
     */
    public List<Course> findAll() {
        return courseRepository.findAll();
    }

    /**
     * 根据ID查询课程
     */
    public Optional<Course> findById(String id) {
        return courseRepository.findById(id);
    }

    /**
     * 根据课程代码查询课程
     */
    public Optional<Course> findByCode(String code) {
        return courseRepository.findByCode(code);
    }

    /**
     * 创建课程
     */
    public Course createCourse(Course course) {
        validateCourse(course, null);

        // 生成UUID作为课程ID
        course.setId(UUID.randomUUID().toString());
        course.setEnrolled(0);
        if (course.getExpectedAttendance() <= 0) {
            course.setExpectedAttendance(course.getCapacity()); // 如果未提供，则默认为课程容量
        }
        return courseRepository.save(course);
    }

    /**
     * 更新课程
     */
    public Course updateCourse(String id, Course course) {
        Course existing = courseRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Course not found with id: " + id));

        validateCourse(course, id);

        course.setId(id);
        course.setEnrolled(existing.getEnrolled());
        if (course.getExpectedAttendance() <= 0) {
            course.setExpectedAttendance(course.getCapacity());
        }
        course.setCreatedAt(existing.getCreatedAt());
        return courseRepository.save(course);
    }

    /**
     * 删除课程
     */
    public void deleteCourse(String id) {
        if (!courseRepository.existsById(id)) {
            throw new ResourceNotFoundException("Course not found with id: " + id);
        }
        courseRepository.deleteById(id);
    }

    /**
     * 检查课程是否存在
     */
    public boolean existsById(String id) {
        return courseRepository.existsById(id);
    }

    /**
     * 增加课程选课人数
     */
    public void incrementEnrolled(String courseId) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResourceNotFoundException("Course not found with id: " + courseId));
        course.setEnrolled(course.getEnrolled() + 1);
        courseRepository.save(course);
    }

    /**
     * 减少课程选课人数
     */
    public void decrementEnrolled(String courseId) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResourceNotFoundException("Course not found with id: " + courseId));
        course.setEnrolled(course.getEnrolled() - 1);
        courseRepository.save(course);
    }

    /**
     * 验证课程必填字段和业务规则
     */
    private void validateCourse(Course course, String updatingCourseId) {
        if (course.getCode() == null || course.getCode().trim().isEmpty()) {
            throw new IllegalArgumentException("Course code is required");
        }
        if (course.getTitle() == null || course.getTitle().trim().isEmpty()) {
            throw new IllegalArgumentException("Course title is required");
        }
        if (course.getInstructor() == null) {
            throw new IllegalArgumentException("Instructor information is required");
        }
        if (course.getInstructor().getId() == null || course.getInstructor().getId().trim().isEmpty()) {
            throw new IllegalArgumentException("Instructor id is required");
        }
        if (course.getInstructor().getName() == null || course.getInstructor().getName().trim().isEmpty()) {
            throw new IllegalArgumentException("Instructor name is required");
        }
        if (course.getInstructor().getEmail() == null || course.getInstructor().getEmail().trim().isEmpty()) {
            throw new IllegalArgumentException("Instructor email is required");
        }
        if (!EMAIL_PATTERN.matcher(course.getInstructor().getEmail()).matches()) {
            throw new IllegalArgumentException("Invalid instructor email format: " + course.getInstructor().getEmail());
        }
        if (course.getSchedule() == null) {
            throw new IllegalArgumentException("Schedule information is required");
        }
        if (course.getSchedule().getDayOfWeek() == null) {
            throw new IllegalArgumentException("Schedule dayOfWeek is required");
        }
        if (course.getSchedule().getStartTime() == null || course.getSchedule().getEndTime() == null) {
            throw new IllegalArgumentException("Schedule startTime and endTime are required");
        }
        if (course.getCapacity() <= 0) {
            throw new IllegalArgumentException("Course capacity must be greater than 0");
        }
        if (course.getExpectedAttendance() < 0) {
            throw new IllegalArgumentException("Expected attendance cannot be negative");
        }

        courseRepository.findByCode(course.getCode()).ifPresent(existing -> {
            if (updatingCourseId == null || !existing.getId().equals(updatingCourseId)) {
                throw new IllegalArgumentException("Course code already exists: " + course.getCode());
            }
        });
    }
}
