package com.zjgsu.szw.coursecloud.enrollment.client;

import com.zjgsu.szw.coursecloud.enrollment.client.dto.ApiResponseWrapper;
import com.zjgsu.szw.coursecloud.enrollment.client.dto.UserDTO;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;

import java.util.List;
import java.util.Map;

@FeignClient(name = "user-service", fallbackFactory = UserClientFallbackFactory.class)
public interface UserClient {

    @GetMapping("/api/users/student/{studentId}")
    ApiResponseWrapper<UserDTO> getUserByStudentId(@PathVariable("studentId") String studentId);

    @GetMapping("/api/users/{idOrStudentId}")
    ApiResponseWrapper<UserDTO> getUserByIdOrStudentId(@PathVariable("idOrStudentId") String idOrStudentId);

    @GetMapping("/api/users")
    ApiResponseWrapper<List<UserDTO>> getAllUsers();

    @GetMapping("/api/users/port")
    ApiResponseWrapper<Map<String, String>> getServicePort();
}

