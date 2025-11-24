package com.zjgsu.szw.enrollment.config;

import org.springframework.cloud.client.loadbalancer.LoadBalanced;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

/**
 * RestTemplate配置类
 * 配置支持负载均衡的RestTemplate Bean
 */
@Configuration
public class RestTemplateConfig {

    /**
     * 创建支持负载均衡的RestTemplate
     * @LoadBalanced注解使RestTemplate能够通过服务名进行调用
     */
    @Bean
    @LoadBalanced
    public RestTemplate restTemplate() {
        return new RestTemplate();
    }
}
