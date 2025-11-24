package com.zjgsu.szw.coursecloud.enrollment.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * 选课记录实体类
 */
@Entity
@Table(name = "enrollments", indexes = {
        @Index(name = "idx_course_id", columnList = "course_id"),
        @Index(name = "idx_student_id", columnList = "student_id")
}, uniqueConstraints = {
        @UniqueConstraint(name = "uk_course_student", columnNames = { "course_id", "student_id" })
})
public class Enrollment {
    @Id
    @Column(length = 36)
    private String id; // 选课记录UUID

    @Column(name = "course_id", nullable = false, length = 36)
    private String courseId; // 课程UUID

    @Column(name = "student_id", nullable = false, length = 50)
    private String studentId; // 学生的学号(非UUID)，如 "S2024001"

    @Column(name = "enrolled_at", nullable = false, updatable = false)
    private LocalDateTime enrolledAt;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", length = 20, nullable = false)
    private EnrollmentStatus status = EnrollmentStatus.ACTIVE;

    public Enrollment() {
        this.enrolledAt = LocalDateTime.now();
        this.status = EnrollmentStatus.ACTIVE;
    }

    public Enrollment(String id, String courseId, String studentId) {
        this.id = id;
        this.courseId = courseId;
        this.studentId = studentId;
        this.enrolledAt = LocalDateTime.now();
        this.status = EnrollmentStatus.ACTIVE;
    }

    @PrePersist
    protected void onCreate() {
        if (enrolledAt == null) {
            enrolledAt = LocalDateTime.now();
        }
    }

    // Getters and Setters
    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getCourseId() {
        return courseId;
    }

    public void setCourseId(String courseId) {
        this.courseId = courseId;
    }

    public String getStudentId() {
        return studentId;
    }

    public void setStudentId(String studentId) {
        this.studentId = studentId;
    }

    public LocalDateTime getEnrolledAt() {
        return enrolledAt;
    }

    public void setEnrolledAt(LocalDateTime enrolledAt) {
        this.enrolledAt = enrolledAt;
    }

    public EnrollmentStatus getStatus() {
        return status;
    }

    public void setStatus(EnrollmentStatus status) {
        this.status = status;
    }
}
