package com.zjgsu.szw.coursecloud.enrollment.exception;

/**
 * 课程未找到异常
 * 当调用catalog-service获取课程信息时，课程不存在抛出此异常
 */
public class CourseNotFoundException extends RuntimeException {

    private final String courseId;

    public CourseNotFoundException(String courseId) {
        super("课程不存在: " + courseId);
        this.courseId = courseId;
    }

    public CourseNotFoundException(String message, String courseId) {
        super(message);
        this.courseId = courseId;
    }

    public String getCourseId() {
        return courseId;
    }
}
