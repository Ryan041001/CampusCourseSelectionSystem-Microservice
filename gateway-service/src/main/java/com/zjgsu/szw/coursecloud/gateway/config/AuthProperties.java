package com.zjgsu.szw.coursecloud.gateway.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

import java.util.ArrayList;
import java.util.List;

/**
 * 认证配置类
 * 用于读取白名单等认证相关配置
 */
@Configuration
@ConfigurationProperties(prefix = "auth")
public class AuthProperties {

    private List<String> whitelist = new ArrayList<>();

    public List<String> getWhitelist() {
        return whitelist;
    }

    public void setWhitelist(List<String> whitelist) {
        this.whitelist = whitelist;
    }
}
