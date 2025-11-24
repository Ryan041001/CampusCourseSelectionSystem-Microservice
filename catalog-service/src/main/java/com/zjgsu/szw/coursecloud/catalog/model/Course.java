package com.zjgsu.szw.coursecloud.catalog.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * 课程实体类
 */
@Entity
@Table(name = "courses", indexes = {
        @Index(name = "idx_code", columnList = "code"),
        @Index(name = "idx_instructor_id", columnList = "instructor_id")
})
public class Course {
    @Id
    @Column(length = 36)
    private String id;

    @Column(nullable = false, unique = true, length = 50)
    private String code;

    @Column(nullable = false, length = 200)
    private String title;

    @Embedded
    private Instructor instructor;

    @Embedded
    private ScheduleSlot schedule;

    @Column(name = "expected_attendance")
    private int expectedAttendance;

    @Column(nullable = false)
    private int capacity;

    @Column(nullable = false)
    private int enrolled;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    public Course() {
        this.enrolled = 0;
        this.createdAt = LocalDateTime.now();
    }

    public Course(String id, String code, String title, Instructor instructor,
            ScheduleSlot schedule, int expectedAttendance, int capacity) {
        this.id = id;
        this.code = code;
        this.title = title;
        this.instructor = instructor;
        this.schedule = schedule;
        this.expectedAttendance = expectedAttendance;
        this.capacity = capacity;
        this.enrolled = 0;
        this.createdAt = LocalDateTime.now();
    }

    @PrePersist
    protected void onCreate() {
        if (createdAt == null) {
            createdAt = LocalDateTime.now();
        }
        if (enrolled == 0) {
            enrolled = 0;
        }
    }

    // Getters and Setters
    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getCode() {
        return code;
    }

    public void setCode(String code) {
        this.code = code;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public Instructor getInstructor() {
        return instructor;
    }

    public void setInstructor(Instructor instructor) {
        this.instructor = instructor;
    }

    public ScheduleSlot getSchedule() {
        return schedule;
    }

    public void setSchedule(ScheduleSlot schedule) {
        this.schedule = schedule;
    }

    public int getExpectedAttendance() {
        return expectedAttendance;
    }

    public void setExpectedAttendance(int expectedAttendance) {
        this.expectedAttendance = expectedAttendance;
    }

    public int getCapacity() {
        return capacity;
    }

    public void setCapacity(int capacity) {
        this.capacity = capacity;
    }

    public int getEnrolled() {
        return enrolled;
    }

    public void setEnrolled(int enrolled) {
        this.enrolled = enrolled;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }
}
