package com.zjgsu.szw.coursecloud.enrollment.client;

import com.zjgsu.szw.coursecloud.enrollment.client.dto.ApiResponseWrapper;
import com.zjgsu.szw.coursecloud.enrollment.client.dto.UserDTO;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cloud.openfeign.FallbackFactory;
import org.springframework.stereotype.Component;

import java.util.Collections;
import java.util.List;
import java.util.Map;

@Component
public class UserClientFallbackFactory implements FallbackFactory<UserClient> {

    private static final Logger logger = LoggerFactory.getLogger(UserClientFallbackFactory.class);

    @Override
    public UserClient create(Throwable cause) {
        logger.error("User service fallback triggered, cause: {}", cause.getMessage());
        return new UserClient() {
            @Override
            public ApiResponseWrapper<UserDTO> getUserByStudentId(String studentId) {
                logger.error("Fallback: getUserByStudentId {}", studentId);
                ApiResponseWrapper<UserDTO> response = new ApiResponseWrapper<>();
                response.setCode(503);
                response.setMessage("User service is unavailable: " + cause.getMessage());
                response.setData(null);
                return response;
            }

            @Override
            public ApiResponseWrapper<UserDTO> getUserByIdOrStudentId(String idOrStudentId) {
                logger.error("Fallback: getUserByIdOrStudentId {}", idOrStudentId);
                ApiResponseWrapper<UserDTO> response = new ApiResponseWrapper<>();
                response.setCode(503);
                response.setMessage("User service is unavailable: " + cause.getMessage());
                response.setData(null);
                return response;
            }

            @Override
            public ApiResponseWrapper<List<UserDTO>> getAllUsers() {
                logger.error("Fallback: getAllUsers");
                ApiResponseWrapper<List<UserDTO>> response = new ApiResponseWrapper<>();
                response.setCode(503);
                response.setMessage("User service is unavailable: " + cause.getMessage());
                response.setData(Collections.emptyList());
                return response;
            }

            @Override
            public ApiResponseWrapper<Map<String, String>> getServicePort() {
                ApiResponseWrapper<Map<String, String>> response = new ApiResponseWrapper<>();
                response.setCode(503);
                response.setMessage("User service is unavailable: " + cause.getMessage());
                response.setData(Collections.emptyMap());
                return response;
            }
        };
    }
}

