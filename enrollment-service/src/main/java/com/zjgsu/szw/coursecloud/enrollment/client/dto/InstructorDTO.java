package com.zjgsu.szw.coursecloud.enrollment.client.dto;

/**
 * 教师DTO - 用于接收catalog-service的响应
 */
public class InstructorDTO {
    private String instructorId;
    private String name;
    private String email;
    private String phone;

    public InstructorDTO() {
    }

    // Getters and Setters
    public String getInstructorId() {
        return instructorId;
    }

    public void setInstructorId(String instructorId) {
        this.instructorId = instructorId;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getPhone() {
        return phone;
    }

    public void setPhone(String phone) {
        this.phone = phone;
    }
}
