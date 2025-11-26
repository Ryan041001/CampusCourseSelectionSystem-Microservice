package com.zjgsu.szw.coursecloud.gateway.controller;

import com.zjgsu.szw.coursecloud.gateway.common.ApiResponse;
import com.zjgsu.szw.coursecloud.gateway.dto.LoginRequest;
import com.zjgsu.szw.coursecloud.gateway.dto.LoginResponse;
import com.zjgsu.szw.coursecloud.gateway.util.JwtUtil;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * 认证控制器
 * 提供登录、令牌验证等认证相关接口
 */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final JwtUtil jwtUtil;

    @Value("${jwt.expiration}")
    private Long expiration;

    // 模拟用户数据库（实际项目中应该从User Service获取）
    private static final Map<String, MockUser> MOCK_USERS = new HashMap<>();

    static {
        // 初始化模拟用户数据
        MOCK_USERS.put("admin", new MockUser(UUID.randomUUID().toString(), "admin", "admin123", "ADMIN"));
        MOCK_USERS.put("teacher", new MockUser(UUID.randomUUID().toString(), "teacher", "teacher123", "TEACHER"));
        MOCK_USERS.put("student", new MockUser(UUID.randomUUID().toString(), "student", "student123", "STUDENT"));
        MOCK_USERS.put("student1", new MockUser("stu001", "student1", "123456", "STUDENT"));
        MOCK_USERS.put("student2", new MockUser("stu002", "student2", "123456", "STUDENT"));
    }

    public AuthController(JwtUtil jwtUtil) {
        this.jwtUtil = jwtUtil;
    }

    /**
     * 用户登录
     * POST /api/auth/login
     */
    @PostMapping("/login")
    public ResponseEntity<ApiResponse<LoginResponse>> login(@RequestBody LoginRequest request) {
        // 参数校验
        if (request.getUsername() == null || request.getUsername().isEmpty()) {
            return ResponseEntity.badRequest()
                    .body(ApiResponse.badRequest("用户名不能为空"));
        }
        if (request.getPassword() == null || request.getPassword().isEmpty()) {
            return ResponseEntity.badRequest()
                    .body(ApiResponse.badRequest("密码不能为空"));
        }

        // 查找用户
        MockUser user = MOCK_USERS.get(request.getUsername());

        // 验证用户名和密码
        if (user == null || !user.getPassword().equals(request.getPassword())) {
            return ResponseEntity.status(401)
                    .body(ApiResponse.unauthorized("用户名或密码错误"));
        }

        // 生成JWT令牌
        String token = jwtUtil.generateToken(user.getId(), user.getUsername(), user.getRole());

        // 构建用户信息
        LoginResponse.UserInfo userInfo = new LoginResponse.UserInfo(
                user.getId(),
                user.getUsername(),
                user.getRole()
        );

        // 构建响应
        LoginResponse response = new LoginResponse(token, expiration / 1000, userInfo);

        return ResponseEntity.ok(ApiResponse.success("登录成功", response));
    }

    /**
     * 验证令牌
     * GET /api/auth/validate
     */
    @GetMapping("/validate")
    public ResponseEntity<ApiResponse<Map<String, Object>>> validateToken(
            @RequestHeader(value = "Authorization", required = false) String authHeader) {

        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return ResponseEntity.status(401)
                    .body(ApiResponse.unauthorized("缺少有效的Authorization头"));
        }

        String token = authHeader.substring(7);

        if (!jwtUtil.validateToken(token)) {
            return ResponseEntity.status(401)
                    .body(ApiResponse.unauthorized("无效或过期的JWT令牌"));
        }

        Map<String, Object> claims = jwtUtil.getAllClaimsFromToken(token);
        return ResponseEntity.ok(ApiResponse.success("令牌有效", claims));
    }

    /**
     * 获取当前用户信息
     * GET /api/auth/me
     * 直接从 Authorization header 解析 JWT 获取用户信息
     */
    @GetMapping("/me")
    public ResponseEntity<ApiResponse<LoginResponse.UserInfo>> getCurrentUser(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Id", required = false) String userId,
            @RequestHeader(value = "X-Username", required = false) String username,
            @RequestHeader(value = "X-User-Role", required = false) String role) {

        // 优先从 X-User-* 请求头获取（通过 Gateway 过滤器设置）
        if (userId != null && username != null) {
            LoginResponse.UserInfo userInfo = new LoginResponse.UserInfo(userId, username, role);
            return ResponseEntity.ok(ApiResponse.success(userInfo));
        }

        // 如果没有 X-User-* 请求头，尝试从 Authorization header 解析
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            if (jwtUtil.validateToken(token)) {
                String tokenUserId = jwtUtil.getUserIdFromToken(token);
                String tokenUsername = jwtUtil.getUsernameFromToken(token);
                String tokenRole = jwtUtil.getRoleFromToken(token);
                LoginResponse.UserInfo userInfo = new LoginResponse.UserInfo(tokenUserId, tokenUsername, tokenRole);
                return ResponseEntity.ok(ApiResponse.success(userInfo));
            }
        }

        return ResponseEntity.status(401)
                .body(ApiResponse.unauthorized("未认证的请求"));
    }

    /**
     * 模拟用户数据类
     */
    private static class MockUser {
        private final String id;
        private final String username;
        private final String password;
        private final String role;

        public MockUser(String id, String username, String password, String role) {
            this.id = id;
            this.username = username;
            this.password = password;
            this.role = role;
        }

        public String getId() {
            return id;
        }

        public String getUsername() {
            return username;
        }

        public String getPassword() {
            return password;
        }

        public String getRole() {
            return role;
        }
    }
}
