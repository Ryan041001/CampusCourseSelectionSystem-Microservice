package com.zjgsu.szw.coursecloud.enrollment.client;

import com.zjgsu.szw.coursecloud.enrollment.client.dto.ApiResponseWrapper;
import com.zjgsu.szw.coursecloud.enrollment.client.dto.CourseDTO;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cloud.openfeign.FallbackFactory;
import org.springframework.stereotype.Component;

import java.util.Collections;
import java.util.List;
import java.util.Map;

/**
 * CatalogClient降级工厂
 * 当catalog-service不可用时提供降级处理
 */
@Component
public class CatalogClientFallbackFactory implements FallbackFactory<CatalogClient> {

    private static final Logger logger = LoggerFactory.getLogger(CatalogClientFallbackFactory.class);

    @Override
    public CatalogClient create(Throwable cause) {
        logger.error("Catalog service fallback triggered, cause: {}", cause.getMessage());
        
        return new CatalogClient() {
            @Override
            public ApiResponseWrapper<CourseDTO> getCourseById(String courseId) {
                logger.error("Fallback: getCourseById for courseId: {}", courseId);
                ApiResponseWrapper<CourseDTO> response = new ApiResponseWrapper<>();
                response.setCode(503);
                response.setMessage("Catalog service is unavailable: " + cause.getMessage());
                response.setData(null);
                return response;
            }

            @Override
            public ApiResponseWrapper<List<CourseDTO>> getAllCourses() {
                logger.error("Fallback: getAllCourses");
                ApiResponseWrapper<List<CourseDTO>> response = new ApiResponseWrapper<>();
                response.setCode(503);
                response.setMessage("Catalog service is unavailable: " + cause.getMessage());
                response.setData(Collections.emptyList());
                return response;
            }

            @Override
            public ApiResponseWrapper<CourseDTO> getCourseByCode(String code) {
                logger.error("Fallback: getCourseByCode for code: {}", code);
                ApiResponseWrapper<CourseDTO> response = new ApiResponseWrapper<>();
                response.setCode(503);
                response.setMessage("Catalog service is unavailable: " + cause.getMessage());
                response.setData(null);
                return response;
            }

            @Override
            public ApiResponseWrapper<Void> incrementEnrolled(String courseId) {
                logger.error("Fallback: incrementEnrolled for courseId: {}", courseId);
                ApiResponseWrapper<Void> response = new ApiResponseWrapper<>();
                response.setCode(503);
                response.setMessage("Catalog service is unavailable: " + cause.getMessage());
                return response;
            }

            @Override
            public ApiResponseWrapper<Void> decrementEnrolled(String courseId) {
                logger.error("Fallback: decrementEnrolled for courseId: {}", courseId);
                ApiResponseWrapper<Void> response = new ApiResponseWrapper<>();
                response.setCode(503);
                response.setMessage("Catalog service is unavailable: " + cause.getMessage());
                return response;
            }

            @Override
            public ApiResponseWrapper<Map<String, String>> getServicePort() {
                logger.error("Fallback: getServicePort");
                ApiResponseWrapper<Map<String, String>> response = new ApiResponseWrapper<>();
                response.setCode(503);
                response.setMessage("Catalog service is unavailable: " + cause.getMessage());
                response.setData(Collections.emptyMap());
                return response;
            }
        };
    }
}
