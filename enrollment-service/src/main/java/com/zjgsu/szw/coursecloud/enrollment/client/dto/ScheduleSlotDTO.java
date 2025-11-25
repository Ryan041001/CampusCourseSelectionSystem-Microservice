package com.zjgsu.szw.coursecloud.enrollment.client.dto;

/**
 * 课程时间段DTO - 用于接收catalog-service的响应
 */
public class ScheduleSlotDTO {
    private String dayOfWeek;
    private String startTime;
    private String endTime;
    private String classroom;

    public ScheduleSlotDTO() {
    }

    // Getters and Setters
    public String getDayOfWeek() {
        return dayOfWeek;
    }

    public void setDayOfWeek(String dayOfWeek) {
        this.dayOfWeek = dayOfWeek;
    }

    public String getStartTime() {
        return startTime;
    }

    public void setStartTime(String startTime) {
        this.startTime = startTime;
    }

    public String getEndTime() {
        return endTime;
    }

    public void setEndTime(String endTime) {
        this.endTime = endTime;
    }

    public String getClassroom() {
        return classroom;
    }

    public void setClassroom(String classroom) {
        this.classroom = classroom;
    }
}
