package com.zjgsu.szw.coursecloud.enrollment.exception;

/**
 * Catalog服务不可用异常
 * 当调用catalog-service失败时抛出此异常
 */
public class CatalogServiceUnavailableException extends RuntimeException {

    public CatalogServiceUnavailableException() {
        super("Catalog服务不可用");
    }

    public CatalogServiceUnavailableException(String message) {
        super(message);
    }

    public CatalogServiceUnavailableException(String message, Throwable cause) {
        super(message, cause);
    }
}
