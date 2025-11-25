package com.zjgsu.szw.coursecloud.enrollment.client.dto;

import java.time.LocalDateTime;

/**
 * 课程DTO - 用于接收catalog-service的响应
 */
public class CourseDTO {
    private String id;
    private String code;
    private String title;
    private InstructorDTO instructor;
    private ScheduleSlotDTO schedule;
    private int expectedAttendance;
    private int capacity;
    private int enrolled;
    private LocalDateTime createdAt;

    public CourseDTO() {
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

    public InstructorDTO getInstructor() {
        return instructor;
    }

    public void setInstructor(InstructorDTO instructor) {
        this.instructor = instructor;
    }

    public ScheduleSlotDTO getSchedule() {
        return schedule;
    }

    public void setSchedule(ScheduleSlotDTO schedule) {
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

    /**
     * 检查课程是否可选（有剩余容量）
     */
    public boolean isAvailable() {
        return enrolled < capacity;
    }

    @Override
    public String toString() {
        return "CourseDTO{" +
                "id='" + id + '\'' +
                ", code='" + code + '\'' +
                ", title='" + title + '\'' +
                ", capacity=" + capacity +
                ", enrolled=" + enrolled +
                '}';
    }
}
