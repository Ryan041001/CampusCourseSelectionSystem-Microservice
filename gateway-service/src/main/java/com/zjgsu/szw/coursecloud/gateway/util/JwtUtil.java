package com.zjgsu.szw.coursecloud.gateway.util;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import jakarta.annotation.PostConstruct;
import java.security.Key;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

/**
 * JWT工具类
 * 用于生成、解析和验证JWT令牌
 */
@Component
public class JwtUtil {

    @Value("${jwt.secret}")
    private String secret;

    @Value("${jwt.expiration}")
    private Long expiration;

    private Key key;

    @PostConstruct
    public void init() {
        this.key = Keys.hmacShaKeyFor(secret.getBytes());
    }

    /**
     * 生成JWT令牌
     *
     * @param userId   用户ID
     * @param username 用户名
     * @param role     用户角色
     * @return JWT令牌
     */
    public String generateToken(String userId, String username, String role) {
        Date now = new Date();
        Date expiryDate = new Date(now.getTime() + expiration);

        return Jwts.builder()
                .setSubject(userId)
                .claim("username", username)
                .claim("role", role)
                .setIssuedAt(now)
                .setExpiration(expiryDate)
                .signWith(key, SignatureAlgorithm.HS512)
                .compact();
    }

    /**
     * 解析JWT令牌
     *
     * @param token JWT令牌
     * @return Claims对象，包含令牌中的所有声明
     */
    public Claims parseToken(String token) {
        return Jwts.parserBuilder()
                .setSigningKey(key)
                .build()
                .parseClaimsJws(token)
                .getBody();
    }

    /**
     * 验证JWT令牌是否有效
     *
     * @param token JWT令牌
     * @return true表示有效，false表示无效
     */
    public boolean validateToken(String token) {
        try {
            Jwts.parserBuilder()
                    .setSigningKey(key)
                    .build()
                    .parseClaimsJws(token);
            return true;
        } catch (JwtException | IllegalArgumentException e) {
            return false;
        }
    }

    /**
     * 从令牌中获取用户ID
     *
     * @param token JWT令牌
     * @return 用户ID
     */
    public String getUserIdFromToken(String token) {
        Claims claims = parseToken(token);
        return claims.getSubject();
    }

    /**
     * 从令牌中获取用户名
     *
     * @param token JWT令牌
     * @return 用户名
     */
    public String getUsernameFromToken(String token) {
        Claims claims = parseToken(token);
        return claims.get("username", String.class);
    }

    /**
     * 从令牌中获取用户角色
     *
     * @param token JWT令牌
     * @return 用户角色
     */
    public String getRoleFromToken(String token) {
        Claims claims = parseToken(token);
        return claims.get("role", String.class);
    }

    /**
     * 检查令牌是否过期
     *
     * @param token JWT令牌
     * @return true表示已过期，false表示未过期
     */
    public boolean isTokenExpired(String token) {
        try {
            Claims claims = parseToken(token);
            return claims.getExpiration().before(new Date());
        } catch (ExpiredJwtException e) {
            return true;
        }
    }

    /**
     * 获取令牌的所有声明信息
     *
     * @param token JWT令牌
     * @return 包含所有声明的Map
     */
    public Map<String, Object> getAllClaimsFromToken(String token) {
        Claims claims = parseToken(token);
        Map<String, Object> result = new HashMap<>();
        result.put("userId", claims.getSubject());
        result.put("username", claims.get("username"));
        result.put("role", claims.get("role"));
        result.put("issuedAt", claims.getIssuedAt());
        result.put("expiration", claims.getExpiration());
        return result;
    }
}
