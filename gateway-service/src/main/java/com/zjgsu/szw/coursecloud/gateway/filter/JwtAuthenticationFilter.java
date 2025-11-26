package com.zjgsu.szw.coursecloud.gateway.filter;

import com.zjgsu.szw.coursecloud.gateway.config.AuthProperties;
import com.zjgsu.szw.coursecloud.gateway.util.JwtUtil;
import io.jsonwebtoken.Claims;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.core.Ordered;
import org.springframework.core.io.buffer.DataBuffer;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.http.server.reactive.ServerHttpResponse;
import org.springframework.stereotype.Component;
import org.springframework.util.AntPathMatcher;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

import java.nio.charset.StandardCharsets;
import java.util.List;

/**
 * JWT认证全局过滤器
 * 拦截所有请求，验证JWT令牌
 */
@Component
public class JwtAuthenticationFilter implements GlobalFilter, Ordered {

    private final JwtUtil jwtUtil;
    private final AuthProperties authProperties;
    private final AntPathMatcher pathMatcher = new AntPathMatcher();

    public JwtAuthenticationFilter(JwtUtil jwtUtil, AuthProperties authProperties) {
        this.jwtUtil = jwtUtil;
        this.authProperties = authProperties;
    }

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        ServerHttpRequest request = exchange.getRequest();
        String path = request.getURI().getPath();

        // 1. 检查是否在白名单中
        if (isWhitelisted(path)) {
            return chain.filter(exchange);
        }

        // 2. 获取Authorization请求头
        String authHeader = request.getHeaders().getFirst(HttpHeaders.AUTHORIZATION);

        // 3. 检查Authorization头是否存在且格式正确
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return unauthorizedResponse(exchange, "缺少有效的Authorization头");
        }

        // 4. 提取JWT令牌
        String token = authHeader.substring(7);

        // 5. 验证JWT令牌
        if (!jwtUtil.validateToken(token)) {
            return unauthorizedResponse(exchange, "无效或过期的JWT令牌");
        }

        // 6. 解析令牌获取用户信息
        try {
            Claims claims = jwtUtil.parseToken(token);
            String userId = claims.getSubject();
            String username = claims.get("username", String.class);
            String role = claims.get("role", String.class);

            // 7. 将用户信息添加到请求头中，传递给下游服务
            ServerHttpRequest modifiedRequest = request.mutate()
                    .header("X-User-Id", userId)
                    .header("X-Username", username)
                    .header("X-User-Role", role)
                    .build();

            // 8. 使用修改后的请求继续处理
            return chain.filter(exchange.mutate().request(modifiedRequest).build());
        } catch (Exception e) {
            return unauthorizedResponse(exchange, "JWT令牌解析失败: " + e.getMessage());
        }
    }

    /**
     * 检查请求路径是否在白名单中
     */
    private boolean isWhitelisted(String path) {
        List<String> whitelist = authProperties.getWhitelist();
        return whitelist.stream()
                .anyMatch(pattern -> pathMatcher.match(pattern, path));
    }

    /**
     * 返回未授权响应
     */
    private Mono<Void> unauthorizedResponse(ServerWebExchange exchange, String message) {
        ServerHttpResponse response = exchange.getResponse();
        response.setStatusCode(HttpStatus.UNAUTHORIZED);
        response.getHeaders().setContentType(MediaType.APPLICATION_JSON);

        String body = String.format(
                "{\"success\":false,\"code\":401,\"message\":\"%s\",\"data\":null}",
                message
        );

        DataBuffer buffer = response.bufferFactory()
                .wrap(body.getBytes(StandardCharsets.UTF_8));

        return response.writeWith(Mono.just(buffer));
    }

    @Override
    public int getOrder() {
        // 优先级设置为较高，确保在其他过滤器之前执行
        return -100;
    }
}
