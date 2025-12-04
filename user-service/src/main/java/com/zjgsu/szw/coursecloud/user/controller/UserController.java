package com.zjgsu.szw.coursecloud.user.controller;

import com.zjgsu.szw.coursecloud.user.common.ApiResponse;
import com.zjgsu.szw.coursecloud.user.model.User;
import com.zjgsu.szw.coursecloud.user.service.UserService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/users")
public class UserController {

    private final UserService userService;

    @Value("${server.port}")
    private String serverPort;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @GetMapping
    public ResponseEntity<ApiResponse<List<User>>> getAllUsers() {
        return ResponseEntity.ok(ApiResponse.success(userService.findAll()));
    }

    @GetMapping("/{idOrStudentId}")
    public ResponseEntity<ApiResponse<User>> getUser(@PathVariable String idOrStudentId) {
        return userService.findByIdOrStudentId(idOrStudentId)
                .map(user -> ResponseEntity.ok(ApiResponse.success(user)))
                .orElse(ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(ApiResponse.notFound("User not found with id: " + idOrStudentId)));
    }

    @GetMapping("/student/{studentId}")
    public ResponseEntity<ApiResponse<User>> getUserByStudentId(@PathVariable String studentId) {
        return userService.findByStudentId(studentId)
                .map(user -> ResponseEntity.ok(ApiResponse.success(user)))
                .orElse(ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(ApiResponse.notFound("User not found with studentId: " + studentId)));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<User>> createUser(@RequestBody User user) {
        User created = userService.createUser(user);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(created));
    }

    @PutMapping("/{idOrStudentId}")
    public ResponseEntity<ApiResponse<User>> updateUser(@PathVariable String idOrStudentId,
                                                        @RequestBody User user) {
        User updated = userService.updateUser(idOrStudentId, user);
        return ResponseEntity.ok(ApiResponse.success(updated));
    }

    @DeleteMapping("/{idOrStudentId}")
    public ResponseEntity<ApiResponse<Void>> deleteUser(@PathVariable String idOrStudentId) {
        userService.deleteUser(idOrStudentId);
        return ResponseEntity.ok(ApiResponse.success("User deleted successfully"));
    }

    @GetMapping("/port")
    public ResponseEntity<ApiResponse<Map<String, String>>> getPort() {
        Map<String, String> payload = new HashMap<>();
        payload.put("service", "user-service");
        payload.put("port", serverPort);
        return ResponseEntity.ok(ApiResponse.success(payload));
    }
}

