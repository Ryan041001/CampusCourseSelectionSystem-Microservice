package com.zjgsu.szw.coursecloud.enrollment.exception;

/**
 * 课程不可选异常
 * 当课程已满或不可选时抛出此异常
 */
public class CourseNotAvailableException extends RuntimeException {

    private final String courseId;
    private final int capacity;
    private final int enrolled;

    public CourseNotAvailableException(String courseId) {
        super("课程已满或不可选: " + courseId);
        this.courseId = courseId;
        this.capacity = 0;
        this.enrolled = 0;
    }

    public CourseNotAvailableException(String courseId, int capacity, int enrolled) {
        super(String.format("课程已满或不可选: %s (容量: %d, 已选: %d)", courseId, capacity, enrolled));
        this.courseId = courseId;
        this.capacity = capacity;
        this.enrolled = enrolled;
    }

    public CourseNotAvailableException(String message, String courseId, int capacity, int enrolled) {
        super(message);
        this.courseId = courseId;
        this.capacity = capacity;
        this.enrolled = enrolled;
    }

    public String getCourseId() {
        return courseId;
    }

    public int getCapacity() {
        return capacity;
    }

    public int getEnrolled() {
        return enrolled;
    }
}
