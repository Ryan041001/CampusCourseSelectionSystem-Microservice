package com.zjgsu.szw.coursecloud.catalog.model;

import jakarta.persistence.Embeddable;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import java.time.DayOfWeek;

/**
 * 课程时间安排实体类（嵌入式对象）
 */
@Embeddable
public class ScheduleSlot {
    @Enumerated(EnumType.STRING)
    private DayOfWeek dayOfWeek;

    private String startTime;
    private String endTime;

    public ScheduleSlot() {
    }

    public ScheduleSlot(DayOfWeek dayOfWeek, String startTime, String endTime) {
        this.dayOfWeek = dayOfWeek;
        this.startTime = startTime;
        this.endTime = endTime;
    }

    // Getters and Setters
    public DayOfWeek getDayOfWeek() {
        return dayOfWeek;
    }

    public void setDayOfWeek(DayOfWeek dayOfWeek) {
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
}
