package com.zjgsu.szw.coursecloud.enrollment.client.dto;

import java.time.LocalDateTime;

/**
 * API响应包装器 - 用于解析catalog-service的统一响应格式
 */
public class ApiResponseWrapper<T> {
    private int code;
    private String message;
    private T data;
    private LocalDateTime timestamp;

    public ApiResponseWrapper() {
    }

    // Getters and Setters
    public int getCode() {
        return code;
    }

    public void setCode(int code) {
        this.code = code;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public T getData() {
        return data;
    }

    public void setData(T data) {
        this.data = data;
    }

    public LocalDateTime getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(LocalDateTime timestamp) {
        this.timestamp = timestamp;
    }

    public boolean isSuccess() {
        return code == 200 || code == 201;
    }
}
