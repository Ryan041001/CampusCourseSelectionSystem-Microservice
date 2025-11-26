package com.zjgsu.szw.coursecloud.gateway.dto;

/**
 * 登录响应DTO
 */
public class LoginResponse {

    private String token;
    private String tokenType = "Bearer";
    private Long expiresIn;
    private UserInfo user;

    public LoginResponse() {
    }

    public LoginResponse(String token, UserInfo user) {
        this.token = token;
        this.user = user;
    }

    public LoginResponse(String token, Long expiresIn, UserInfo user) {
        this.token = token;
        this.expiresIn = expiresIn;
        this.user = user;
    }

    public String getToken() {
        return token;
    }

    public void setToken(String token) {
        this.token = token;
    }

    public String getTokenType() {
        return tokenType;
    }

    public void setTokenType(String tokenType) {
        this.tokenType = tokenType;
    }

    public Long getExpiresIn() {
        return expiresIn;
    }

    public void setExpiresIn(Long expiresIn) {
        this.expiresIn = expiresIn;
    }

    public UserInfo getUser() {
        return user;
    }

    public void setUser(UserInfo user) {
        this.user = user;
    }

    /**
     * 用户信息内部类
     */
    public static class UserInfo {
        private String id;
        private String username;
        private String role;

        public UserInfo() {
        }

        public UserInfo(String id, String username, String role) {
            this.id = id;
            this.username = username;
            this.role = role;
        }

        public String getId() {
            return id;
        }

        public void setId(String id) {
            this.id = id;
        }

        public String getUsername() {
            return username;
        }

        public void setUsername(String username) {
            this.username = username;
        }

        public String getRole() {
            return role;
        }

        public void setRole(String role) {
            this.role = role;
        }
    }
}
